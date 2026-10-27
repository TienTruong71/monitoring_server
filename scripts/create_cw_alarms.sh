#!/bin/bash
# Create the SNS topic and the 9 CloudWatch alarms (HighCPU / HighRAM / StatusCheck x 3 targets).
# Run in CloudShell (us-east-1):
#   ./scripts/create_cw_alarms.sh [email-to-subscribe]
# Targets are found by tag Monitoring=node, the same filter Prometheus ec2_sd_configs uses,
# so instance IDs never need to be edited after the stack is recreated.
set -euo pipefail

TOPIC_NAME=prom-monitoring-alerts
EMAIL=${1:-}

# create-topic is idempotent: it returns the existing ARN if the topic already exists
TOPIC=$(aws sns create-topic --name "$TOPIC_NAME" \
  --tags Key=Project,Value=prom-monitoring --query TopicArn --output text)
echo "SNS topic: $TOPIC"
if [ -n "$EMAIL" ]; then
  aws sns subscribe --topic-arn "$TOPIC" --protocol email --notification-endpoint "$EMAIL" >/dev/null
  echo "Subscription request sent to $EMAIL - open the mail and click Confirm subscription"
fi

TARGETS=$(aws ec2 describe-instances \
  --filters "Name=tag:Monitoring,Values=node" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,InstanceId]" --output text)
[ -n "$TARGETS" ] || { echo "No running instance tagged Monitoring=node"; exit 1; }

# name namespace metric statistic evaluation-periods threshold operator (mirrors prometheus/rules/node_exporter.yml)
ALARMS="HighCPU     AWS/EC2 CPUUtilization    Average 5 80 GreaterThanThreshold
HighRAM     CWAgent mem_used_percent  Average 5 90 GreaterThanThreshold
StatusCheck AWS/EC2 StatusCheckFailed Maximum 1 1  GreaterThanOrEqualToThreshold"

COUNT=0
while read -r NAME ID; do
  while read -r SUFFIX NS METRIC STAT EVAL THRESHOLD OP; do
    aws cloudwatch put-metric-alarm --alarm-name "$NAME-$SUFFIX" \
      --namespace "$NS" --metric-name "$METRIC" --dimensions "Name=InstanceId,Value=$ID" \
      --statistic "$STAT" --period 60 --evaluation-periods "$EVAL" --datapoints-to-alarm "$EVAL" \
      --threshold "$THRESHOLD" --comparison-operator "$OP" \
      --alarm-actions "$TOPIC" --ok-actions "$TOPIC" </dev/null
    echo "created $NAME-$SUFFIX ($ID)"
    COUNT=$((COUNT + 1))
  done <<<"$ALARMS"
done <<<"$TARGETS"

echo "$COUNT alarms created/updated"
