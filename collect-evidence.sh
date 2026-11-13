#!/bin/bash
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <bucket-name> <ec2-address> <lambda-address>"
  exit 1
fi

BUCKET="$1"
EC2_ADDR="$2"
LAMBDA_ADDR="$3"
OUT="evidence.txt"
ROLL="23l-3004"

: > "$OUT"

echo "== caller ==" >> "$OUT"
aws sts get-caller-identity >> "$OUT" 2>&1 || echo "[command failed: aws sts get-caller-identity]" >> "$OUT"

echo "== public-access ==" >> "$OUT"
aws s3api get-public-access-block --bucket "$BUCKET" >> "$OUT" 2>&1 || echo "[command failed: aws s3api get-public-access-block]" >> "$OUT"

echo "== versioning ==" >> "$OUT"
aws s3api get-bucket-versioning --bucket "$BUCKET" >> "$OUT" 2>&1 || echo "[command failed: aws s3api get-bucket-versioning]" >> "$OUT"

echo "== objects ==" >> "$OUT"
aws s3 ls "s3://${BUCKET}/site/" --recursive >> "$OUT" 2>&1 || echo "[command failed: aws s3 ls]" >> "$OUT"

echo "== ec2-policy ==" >> "$OUT"
for p in $(aws iam list-role-policies --role-name "cv-ec2-role-${ROLL}" --query 'PolicyNames[]' --output text 2>>"$OUT"); do
  aws iam get-role-policy --role-name "cv-ec2-role-${ROLL}" --policy-name "$p" >> "$OUT" 2>&1 || echo "[command failed: aws iam get-role-policy]" >> "$OUT"
done
aws iam list-attached-role-policies --role-name "cv-ec2-role-${ROLL}" >> "$OUT" 2>&1 || echo "[command failed: aws iam list-attached-role-policies]" >> "$OUT"

echo "== lambda-policy ==" >> "$OUT"
aws iam list-attached-role-policies --role-name "cv-lambda-role-${ROLL}" >> "$OUT" 2>&1 || echo "[command failed: aws iam list-attached-role-policies]" >> "$OUT"
for p in $(aws iam list-role-policies --role-name "cv-lambda-role-${ROLL}" --query 'PolicyNames[]' --output text 2>>"$OUT"); do
  aws iam get-role-policy --role-name "cv-lambda-role-${ROLL}" --policy-name "$p" >> "$OUT" 2>&1 || echo "[command failed: aws iam get-role-policy]" >> "$OUT"
done

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=cv-ec2-${ROLL}" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text)

echo "== security-group ==" >> "$OUT"
SG_IDS=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].SecurityGroups[].GroupId' --output text)
aws ec2 describe-security-groups --group-ids $SG_IDS >> "$OUT" 2>&1 || echo "[command failed: aws ec2 describe-security-groups]" >> "$OUT"

echo "== instance ==" >> "$OUT"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,Type:InstanceType,State:State.Name,PublicIp:PublicIpAddress,IMDS_HttpTokens:MetadataOptions.HttpTokens,InstanceProfile:IamInstanceProfile.Arn}' >> "$OUT" 2>&1 || echo "[command failed: aws ec2 describe-instances]" >> "$OUT"

echo "== endpoints ==" >> "$OUT"
curl -s -o /dev/null -w 'EC2 / -> %{http_code} %{content_type}\n' "${EC2_ADDR}/" >> "$OUT" 2>&1 || echo "[curl failed]" >> "$OUT"
curl -s -o /dev/null -w 'EC2 /style.css -> %{http_code} %{content_type}\n' "${EC2_ADDR}/style.css" >> "$OUT" 2>&1 || echo "[curl failed]" >> "$OUT"
curl -s -o /dev/null -w 'EC2 /cv.pdf -> %{http_code} %{content_type}\n' "${EC2_ADDR}/cv.pdf" >> "$OUT" 2>&1 || echo "[curl failed]" >> "$OUT"
curl -s -o /dev/null -w 'Lambda / -> %{http_code} %{content_type}\n' "${LAMBDA_ADDR}/" >> "$OUT" 2>&1 || echo "[curl failed]" >> "$OUT"
curl -s -o /dev/null -w 'Lambda /style.css -> %{http_code} %{content_type}\n' "${LAMBDA_ADDR}/style.css" >> "$OUT" 2>&1 || echo "[curl failed]" >> "$OUT"
curl -s -o /dev/null -w 'Lambda /cv.pdf -> %{http_code} %{content_type}\n' "${LAMBDA_ADDR}/cv.pdf" >> "$OUT" 2>&1 || echo "[curl failed]" >> "$OUT"
curl -s -o /dev/null -w 'Lambda /anything -> %{http_code} %{content_type}\n' "${LAMBDA_ADDR}/anything" >> "$OUT" 2>&1 || echo "[curl failed]" >> "$OUT"
curl -s -o /dev/null -w 'S3 /site/index.html -> %{http_code} %{content_type}\n' "https://${BUCKET}.s3.ap-southeast-1.amazonaws.com/site/index.html" >> "$OUT" 2>&1 || echo "[curl failed]" >> "$OUT"

echo "== lambda-logs ==" >> "$OUT"
aws logs tail "/aws/lambda/cv-func-${ROLL}" --since 1d >> "$OUT" 2>&1 || echo "[command failed: aws logs tail]" >> "$OUT"

echo "== log-retention ==" >> "$OUT"
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/cv-func-${ROLL}" >> "$OUT" 2>&1 || echo "[command failed: aws logs describe-log-groups]" >> "$OUT"

echo "DONE"
