#!/usr/bin/env bash
set -euo pipefail

ENV=$1
IMAGE_URI=$2

CLUSTER="urlshort-${ENV}-cluster"
SERVICE="urlshort-${ENV}-svc"
TASK_FAMILY="urlshort-${ENV}-app"

# Get current task definition
TASK_DEF=$(aws ecs describe-task-definition \
  --task-definition $TASK_FAMILY \
  --query 'taskDefinition' \
  --output json)

# Update the image in the container definition
NEW_TASK_DEF=$(echo "$TASK_DEF" | jq --arg IMAGE "$IMAGE_URI" \
  '.containerDefinitions[0].image = $IMAGE
   | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')

# Register new revision
echo "$NEW_TASK_DEF" > /tmp/new-task-def.json
NEW_TD_ARN=$(aws ecs register-task-definition \
  --cli-input-json file:///tmp/new-task-def.json \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Registered new task definition: $NEW_TD_ARN"

# Update service
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition $NEW_TD_ARN \
  --force-new-deployment \
  > /dev/null

echo "Service updated. Waiting for stability..."
