#!/bin/bash
BUCKET="cv-23l-3004"
WEBROOT="/var/www/html"
LOG="/var/log/cv-sync.log"

TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
IID=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

export AWS_DEFAULT_REGION="ap-southeast-1"
if aws s3 sync "s3://${BUCKET}/site/" "$WEBROOT"; then
  sed -i "s|{{HOSTED_ON}}|EC2 ${IID}|g" "$WEBROOT/index.html"
  echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') sync OK instance=${IID}" >> "$LOG"
else
  echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') sync FAILED instance=${IID}" >> "$LOG"
fi
