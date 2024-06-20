#!/usr/bin/env python3
import os
import argparse
# import uuid

import boto3

# BUCKET_NAME = "kyliejenner-images-test-versioned"
# PREFIX = "envoidemo/"
# MANIFEST_NAME = "s3_batch_manifest.csv"
# ROLE_ARN = "arn:aws:iam::833740154547:role/S3BatchJobRole"
# PRIORITY = 10
# AWS_ACCOUNT_ID = 833740154547
# REPORT_BUCKET_NAME = "s3-bash-testing334"
# REPORT_PREFIX = "reports/"

# BUCKET_NAME = "kyliejenner-images-test-versioned"
# PREFIX = "envoidemo/"
# MANIFEST_NAME = "s3_batch_manifest.csv"
# ROLE_ARN = "arn:aws:iam::833740154547:role/S3BatchJobRole"
# PRIORITY = 10
# AWS_ACCOUNT_ID = 833740154547
# REPORT_BUCKET_NAME = ""
# REPORT_PREFIX = "reports/"

# Create a session using your AWS credentials
session = boto3.Session()

# Create an S3 client using the session
s3 = session.client('s3')


def create_manifest(bucket_name, prefix, manifest_name):
    # Create a paginator to paginate through all the objects
    paginator = s3.get_paginator('list_objects_v2')

    # Initialize an empty list to store the keys
    keys = []

    # Paginate through all the objects in the bucket
    with open(manifest_name, 'w') as f:
        for page in paginator.paginate(Bucket=bucket_name, Prefix=prefix):
            if 'Contents' in page:
                # Filter out directories and add the keys to the list
                for item in page['Contents']:
                    key = item['Key']
                    if not key.endswith('/'):
                        f.write(f'{bucket_name},{key}\n')

    # Write the keys to a manifest file
    #     for key in keys:
    #         f.write(f'{bucket_name},{key}\n')

    return manifest_name


aws_account_id_default = os.environ.get('AWS_ACCOUNT_ID') or session.client('sts').get_caller_identity().get('Account')
bucket_name_default = os.environ.get('BUCKET_NAME')
prefix_default = os.environ.get('PREFIX')
manifest_name_default = os.environ.get('MANIFEST_NAME')
manifest_bucket_name_default = os.environ.get('MANIFEST_BUCKET_NAME')
role_arn_default = os.environ.get('ROLE_ARN')
priority_default = os.environ.get('PRIORITY')
target_bucket_name = os.environ.get('TARGET_BUCKET_NAME')
target_storage_class_default = os.environ.get('TARGET_STORAGE_CLASS')
report_bucket_name_default = os.environ.get('REPORT_BUCKET_NAME')
report_prefix_default = os.environ.get('REPORT_PREFIX')

parser = argparse.ArgumentParser(description='Create an S3 Batch job')
parser.add_argument('--bucket-name', required=not bool(bucket_name_default), help='The name of the bucket')
parser.add_argument('--target-bucket-name', required=False, help='The name of the target bucket')
parser.add_argument('--prefix', required=False, help='The prefix of the objects in the bucket', default='')
parser.add_argument('--manifest-name', required=not bool(manifest_name_default), help='The name of the manifest file')
parser.add_argument('--manifest-bucket-name', required=False, help='The name of the bucket to store the manifest file')
parser.add_argument('--role-arn', required=not bool(role_arn_default), help='The ARN of the IAM role')
parser.add_argument('--priority', required=False, help='The priority of the job')
parser.add_argument('--aws-account-id', required=not bool(aws_account_id_default), help='The AWS account ID')
parser.add_argument('--target-storage-class', required=not bool(target_storage_class_default),
                    help='The target storage class of the objects')
parser.add_argument('--enable-report', required=False, help='Enable the job report', default=False, action='store_true')
parser.add_argument('--report-bucket-name', required=False, help='The bucket to store the job report')
parser.add_argument('--report-prefix', required=False, help='The prefix of the job report', default='reports/')
parser.add_argument('--report-errors-only', required=False, help='Enable the job report', default=False,
                    action='store_true')


def parse_args():
    args = parser.parse_args()
    return args


def main():
    args = parse_args()

    aws_account_id = args.aws_account_id or aws_account_id_default
    bucket_name = args.bucket_name or bucket_name_default
    enable_report = getattr(args, 'enable_report', False)
    manifest_name = args.manifest_name or manifest_name_default
    manifest_bucket_name = args.manifest_bucket_name or manifest_bucket_name_default or bucket_name
    prefix = args.prefix or prefix_default
    priority = args.priority or priority_default
    role_arn = args.role_arn or role_arn_default
    target_bucket_name = args.target_bucket_name or bucket_name
    target_storage_class = args.target_storage_class or target_storage_class_default

    # Create a manifest file
    create_manifest(bucket_name, prefix, manifest_name)

    # Upload the manifest file to S3
    s3.upload_file(manifest_name, bucket_name, manifest_name)

    # Get the ETag of the uploaded manifest file
    response = s3.head_object(Bucket=bucket_name, Key=manifest_name)
    manifest_etag = response['ETag']

    # Create an S3 Control client using the session
    s3control = session.client('s3control')

    # client_request_token = uuid.uuid4().hex

    if enable_report:
        report_bucket_name = args.report_bucket_name or report_bucket_name_default
        report_prefix = args.report_prefix
        report_scope = 'FailedTasksOnly' if args.report_errors_only else 'AllTasks'
        report = {
            'Enabled': enable_report,
            'Bucket': f'arn:aws:s3:::{report_bucket_name}',
            'Format': 'Report_CSV_20180820',
            'ReportScope': report_scope
        }
        if report_prefix:
            report['Prefix'] = report_prefix
    else:
        report = {'Enabled': enable_report}

    # Create a job with the manifest file
    create_job_response = s3control.create_job(
        AccountId="%s" % aws_account_id,
        Operation={
            'S3PutObjectCopy': {
                'TargetResource': f'arn:aws:s3:::{target_bucket_name}',
                'StorageClass': target_storage_class
            }
        },
        Manifest={
            'Spec': {
                'Format': 'S3BatchOperations_CSV_20180820',
                'Fields': ['Bucket', 'Key']
            },
            'Location': {
                'ObjectArn': f'arn:aws:s3:::{manifest_bucket_name}/{manifest_name}',
                'ETag': manifest_etag
            }
        },
        Report=report,
        Priority=int(priority),
        RoleArn=role_arn,
        ConfirmationRequired=True,
        # ClientRequestToken=client_request_token
    )
    print(create_job_response['JobId'] or create_job_response)


if __name__ == '__main__':
    main()
