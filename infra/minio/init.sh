#!/bin/sh
set -eu

mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

mc mb --ignore-existing "local/${S3_BUCKET}"

# Сервисный пользователь приложения с доступом только к бакету фотографий
cat > /tmp/policy.json <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"],
      "Resource": ["arn:aws:s3:::${S3_BUCKET}", "arn:aws:s3:::${S3_BUCKET}/*"]
    }
  ]
}
POLICY

mc admin user add local "$S3_ACCESS_KEY" "$S3_SECRET_KEY" 2>/dev/null || true
mc admin policy create local app-photos /tmp/policy.json 2>/dev/null || true
mc admin policy attach local app-photos --user "$S3_ACCESS_KEY" 2>/dev/null || true

echo "MinIO: bucket '${S3_BUCKET}' и пользователь '${S3_ACCESS_KEY}' готовы"
