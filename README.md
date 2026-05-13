# urlshort-aws-platform

> **Portfolio project.** This repo is a fork of [Kutt](https://github.com/thedevs-network/kutt). The application code is upstream. The portfolio contribution lives in `infra/`, `.github/`, and `scripts/`. See [PORTFOLIO.md](./PORTFOLIO.md) for scope details.

A production-style AWS platform for a containerized URL shortener — built to demonstrate DevOps engineering practices: infrastructure as code, container hardening, secrets management, keyless CI/CD, and database migration automation.

---

## Architecture

```
Internet → ALB (public subnets, 2 AZs)
             ↓
        ECS Fargate (private subnets)
             ↓              ↓
        RDS Postgres    ElastiCache Redis
             ↓
        Secrets Manager (credentials injected at task start)
             ↑
        GitHub Actions (OIDC — no long-lived keys)
```

- **Network**: VPC `10.0.0.0/16`, 2 AZs, public/private subnets, single NAT Gateway
- **Compute**: ECS Fargate, ALB, immutable ECR image tags by commit SHA
- **Data**: RDS Postgres 16 (`db.t4g.micro`), ElastiCache Redis 7 (`cache.t4g.micro`)
- **Secrets**: AWS Secrets Manager, JSON-formatted, injected via ECS `valueFrom`
- **CI/CD**: GitHub Actions + OIDC federation — no AWS access keys anywhere

---

## Repository structure

```
infra/
├── bootstrap/        # S3 state bucket + DynamoDB lock table
├── modules/
│   ├── network/      # VPC, subnets, NAT, security groups
│   ├── data/         # RDS, ElastiCache, Secrets Manager
│   └── compute/      # ECR, ECS, ALB, IAM roles
└── envs/
    ├── staging/      # Staging environment (auto-deploy on merge)
    ├── prod/         # Production environment (manual approval gate)
    └── shared/       # GitHub OIDC provider + deploy role

.github/workflows/
├── ci.yml            # Lint, validate, tflint, Trivy — runs on every PR
└── deploy.yml        # Build, scan, migrate, deploy — runs on merge to main

scripts/
├── deploy-ecs.sh     # Registers new task def revision, updates service
└── run-migration.sh  # One-shot ECS migration task with exit-code gating

loadtest/
└── script.js         # k6 load test
```

---

## CI/CD pipeline

**CI (every PR):**
- Node lint and test (`--if-present`)
- `terraform fmt`, `terraform validate` across all modules
- `tflint` with AWS ruleset
- Trivy config scan (CRITICAL severity, blocks merge)

**Deploy (merge to main → staging, manual approval → prod):**
1. Build image, tag with commit SHA, push to ECR
2. Trivy image scan — blocks on CRITICAL CVEs
3. `terraform apply` (infrastructure changes)
4. Run database migrations as one-shot ECS task — pipeline halts on non-zero exit
5. Register new task definition revision with new image, update ECS service
6. Wait for service stability
7. HTTP smoke test against ALB

---

## Design decisions and trade-offs

| Decision | Choice | Trade-off |
|---|---|---|
| NAT Gateway | Single (one AZ) | ~$33/mo vs ~$66 for HA; AZ-a outage breaks AZ-b egress |
| Container base | `node:20-bookworm-slim` | ~80MB larger than Alpine; avoids musl libc edge cases |
| Image tags | Immutable, SHA-based | Can't overwrite; rollback = point service at old revision |
| Secrets | AWS Secrets Manager JSON | $0.40/secret/month; ECS injects individual fields via JMESPath |
| OIDC auth | GitHub OIDC federation | No long-lived keys; trust policy scoped to repo + branch |
| Migrations | One-shot ECS task before service update | Failed migration halts deploy; running service unaffected |
| Deploy IAM | PowerUserAccess + scoped ECR/ECS/IAM policy | Production would use fully scoped policy (hours of enumeration) |
| Cookies | `Secure` flag disabled in staging | HTTP-only deployment; production requires HTTPS + ACM cert |

---

## Load test results

Tool: k6 — 10 VUs sustained over 2.5 minutes, 80% reads / 20% link creation.

| Metric | Value |
|---|---|
| p50 latency | 45ms |
| p95 latency | 99ms |
| max latency | 302ms |
| Throughput | 29 RPS |
| Error rate | 0.02% (1/4389 requests) |

Both thresholds passed (`p95 < 300ms`, `error rate < 1%`). Single ECS task (0.25 vCPU, 512MB) on `db.t4g.micro`. Next scaling levers: increase `desired_count`, upgrade instance class, add RDS read replica.

---

## What I'd change at scale

- **Fully scoped IAM policy** for the deploy role instead of PowerUserAccess
- **One NAT Gateway per AZ** for true HA egress
- **HTTPS termination** at the ALB with ACM-managed certificate
- **Customer-managed KMS keys** for Secrets Manager (currently AWS-managed)
- **ECS service autoscaling** on CPU and request count
- **WAF** in front of the ALB for basic abuse protection
- **RDS read replica** once read traffic justifies the cost
- **Centralized log aggregation** (Loki or OpenSearch) across environments

---

## Cost (staging, us-east-1)

| Resource | Monthly |
|---|---|
| NAT Gateway | ~$33 |
| RDS db.t4g.micro | ~$12 |
| ElastiCache cache.t4g.micro | ~$11 |
| ALB | ~$16 |
| ECS Fargate (1 task) | ~$8 |
| Secrets Manager (3 secrets) | ~$1.20 |
| **Total** | **~$81/month** |

Staging is destroyed when not in use. Infrastructure recreates from state in ~10 minutes via `terraform apply`.

---

## Key commands

```bash
# Recreate staging
cd infra/envs/staging && terraform apply

# Destroy staging
cd infra/envs/staging && terraform destroy

# Force ECS redeploy
aws ecs update-service --cluster urlshort-staging-cluster \
  --service urlshort-staging-svc --force-new-deployment

# Tail logs
aws logs tail /ecs/urlshort-staging/app --follow

# Run load test
k6 run --env BASE_URL=http://http://urlshort-staging-alb-2078532938.us-east-1.elb.amazonaws.com/ --env API_KEY=<key> loadtest/script.js
```

---

## Image size reduction

| Image | Size |
|---|---|
| Upstream Kutt (naive) | ~1.1 GB |
| This Dockerfile (multi-stage, slim base) | ~280 MB |
| Reduction | **~75%** |

Multi-stage build, `node:20-bookworm-slim`, non-root user, `tini` for signal handling, `.dockerignore` excluding dev artifacts.
