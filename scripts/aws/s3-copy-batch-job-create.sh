#!/bin/bash

BUCKET_NAME="kyliejenner-images-test-versioned"
PREFIX="envoidemo/"
MANIFEST_NAME="s3_batch_manifest.csv"
REPORT_BUCKET="s3-bash-testing334"
ROLE_ARN="arn:aws:iam::833740154547:role/S3BatchJobRole"
PRIORITY=10
AWS_ACCOUNT_ID=833740154547
TARGET_BUCKET_NAME=${TARGET_BUCKET_NAME:-$BUCKET_NAME}
MANIFIEST_BUCKET_NAME=${MANFIEST_BUCKET_NAME:-$BUCKET_NAME

# 1. Generate Manifest (Within Temporary Directory)
#tmpdir=$(mktemp -d); pushd "$tmpdir"
aws s3api list-objects-v2 \
    --bucket "$BUCKET_NAME" \
    --prefix "$PREFIX" \
    --query 'Contents[].Key' \
    --output text | tr '\t' '\n' | grep -v '/$' | sed 's/^/'$BUCKET_NAME',/' > "$MANIFEST_NAME"

# 2. Upload Manifest to S3
aws s3 cp "$MANIFEST_NAME" "s3://$BUCKET_NAME/$MANIFEST_NAME"
manifest_etag=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "$MANIFEST_NAME" --query 'ETag' --output text)

# 3. Create S3 Batch Operations Job
aws s3control create-job \
    --account-id $AWS_ACCOUNT_ID \
    --confirmation-required \
    --operation '{
        "S3PutObjectCopy": {
            "TargetResource": "arn:aws:s3:::'$TARGET_BUCKET_NAME'",
            "StorageClass": "STANDARD_IA"
        }
    }' \
    --manifest '{
        "Spec": {
            "Format": "S3BatchOperations_CSV_20180820",
            "Fields": ["Bucket","Key"]
        },
        "Location": {
            "ObjectArn": "arn:aws:s3:::'$MANIFIEST_BUCKET_NAME'/'$MANIFEST_NAME'",
            "ETag": '$manifest_etag'
        }
    }' \
    --report '{
        "Enabled": false
    }' \
    --priority $PRIORITY \
    --role-arn $ROLE_ARN
#popd

# 4. Cleanup Temporary Manifest if exists
if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
    rm -rf "$tmpdir"
fi



# aws s3control update-job-status --account-id $AWS_ACCOUNT_ID --requested-job-status Ready --job-id YOUR_JOB_ID \
#    --requested-job-status Ready
