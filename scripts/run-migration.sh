#!/usr/bin/env bash
set -euo pipefail

ENV=$1
IMAGE_URI=$2

CLUSTER="urlshort-${ENV}-cluster"
SERVICE="urlshort-${ENV}-svc"
TASK_FAMILY="urlshort-${ENV}-app"

echo "==> Fetching service network configuration"
NETWORK_CONFIG=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].networkConfiguration' \
  --output json)

echo "==> Fetching current task definition"
TASK_DEF=$(aws ecs describe-task-definition \
  --task-definition "$TASK_FAMILY" \
  --query 'taskDefinition' \
  --output json)

# Build a migration task def that uses the new image and overrides the command
echo "==> Registering migration task definition"
MIG_TASK_DEF=$(echo "$TASK_DEF" | jq \
  --arg IMAGE "$IMAGE_URI" \
  --arg FAMILY "${TASK_FAMILY}-migration" \
  '
    .containerDefinitions[0].image = $IMAGE
    | .containerDefinitions[0].command = ["npm", "run", "migrate"]
    | del(.containerDefinitions[0].healthCheck)
    | .family = $FAMILY
    | del(
        .taskDefinitionArn,
        .revision,
        .status,
        .requiresAttributes,
        .compatibilities,
        .registeredAt,
        .registeredBy
      )
  ')


echo "$MIG_TASK_DEF" > /tmp/migration-task-def.json
MIG_TD_ARN=$(aws ecs register-task-definition \
  --cli-input-json file:///tmp/migration-task-def.json \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Migration task def: $MIG_TD_ARN"

echo "==> Running migration task"
TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER" \
  --task-definition "$MIG_TD_ARN" \
  --launch-type FARGATE \
  --network-configuration "$NETWORK_CONFIG" \
  --query 'tasks[0].taskArn' \
  --output text)

echo "Task ARN: $TASK_ARN"

echo "==> Waiting for migration task to complete"
aws ecs wait tasks-stopped \
  --cluster "$CLUSTER" \
  --tasks "$TASK_ARN"

echo "==> Checking exit code"
EXIT_CODE=$(aws ecs describe-tasks \
  --cluster "$CLUSTER" \
  --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[0].exitCode' \
  --output text)

STOP_REASON=$(aws ecs describe-tasks \
  --cluster "$CLUSTER" \
  --tasks "$TASK_ARN" \
  --query 'tasks[0].stoppedReason' \
  --output text)

echo "Exit code: $EXIT_CODE"
echo "Stop reason: $STOP_REASON"

# Pull the last 50 lines of migration logs for visibility
TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')
LOG_STREAM="ecs/app/${TASK_ID}"

echo "==> Migration logs (last 50 lines):"
aws logs get-log-events \
  --log-group-name "/ecs/urlshort-${ENV}/app" \
  --log-stream-name "$LOG_STREAM" \
  --limit 50 \
  --query 'events[*].message' \
  --output text || echo "(unable to fetch logs)"

if [[ "$EXIT_CODE" != "0" ]]; then
  echo "Migration failed."
  exit 1
fi

echo "Migration succeeded."
