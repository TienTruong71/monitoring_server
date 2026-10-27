#!/bin/bash
# Install and configure the CloudWatch Agent (mem_used_percent, disk_used_percent) on a target host.
# Copy to web-1 / web-2 / db-1 and run:
#   scp -i labsuser.pem scripts/install_cw_agent.sh ubuntu@<target-ip>:~ && ssh -i labsuser.pem ubuntu@<target-ip> sudo ./install_cw_agent.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }

CTL=/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl
CONFIG=/opt/aws/amazon-cloudwatch-agent/bin/config.json

# Without an instance profile the agent still reports "running" but logs "no EC2 IMDS role found" and sends nothing
TOKEN=$(curl -s -m 5 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
if ! curl -sf -m 5 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/info >/dev/null; then
  ID=$(curl -s -m 5 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
  echo "No IAM role on $ID. Attach it first (CloudShell):"
  echo "  aws ec2 associate-iam-instance-profile --instance-id $ID --iam-instance-profile Name=LabInstanceProfile"
  exit 1
fi

if [ ! -x "$CTL" ]; then
  cd /tmp
  wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  dpkg -i amazon-cloudwatch-agent.deb
  rm -f amazon-cloudwatch-agent.deb
fi

cat > "$CONFIG" <<'EOF'
{
  "agent": { "metrics_collection_interval": 60, "run_as_user": "root" },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": { "InstanceId": "${aws:InstanceId}" },
    "metrics_collected": {
      "mem":  { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["used_percent"], "resources": ["/"], "ignore_file_system_types": ["tmpfs", "overlay", "squashfs"] },
      "cpu":  { "measurement": ["cpu_usage_idle"], "totalcpu": true }
    }
  }
}
EOF

# Kept on one line: a pasted multi-line version splits at "\" and fails with "-a: command not found"
"$CTL" -a fetch-config -m ec2 -s -c "file:$CONFIG"
"$CTL" -a status
