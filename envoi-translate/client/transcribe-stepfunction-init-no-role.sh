#!/bin/bash

export STEP_FUNCTION_NAME=${STEP_FUNCTION_NAME:-"envoi-transcribe-translate"}
export ROLE_NAME=${ROLE_NAME:-$STEP_FUNCTION_NAME}
export POLICY_NAME=${POLICY_NAME:-$ROLE_NAME}

ASSUME_ROLE_POLICY_JSON=$(cat <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)

POLICY_JSON=$(cat <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "envoiTranscribe",
      "Effect": "Allow",
      "Action": [
        "transcribe:GetTranscriptionJob",
        "transcribe:StartTranscriptionJob",
        "transcribe:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "envoiTranscribeS3",
      "Effect": "Allow",
      "Action": [
        "s3:ListTagsForResource",
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObjectTagging"
      ],
      "Resource": "*"
    },
    {
      "Sid": "envoiTranslate",
      "Effect": "Allow",
      "Action": [
        "translate:CreateParallelData",
        "translate:DescribeTextTranslationJob",
        "translate:GetParallelData",
        "translate:ListTagsForResource",
        "translate:TagResource",
        "translate:TranslateText",
        "translate:UntagResource",
        "translate:UpdateParallelData"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

STEP_FUNCTION_JSON=$(cat <<-EOF
{
  "Comment": "A state machine that transcribes documents.",
  "StartAt": "StartTranscriptionJob",
  "States": {
    "StartTranscriptionJob": {
      "Type": "Task",
      "Parameters": {
        "Media.$": "$.Transcribe.Media",
        "IdentifyLanguage": "true",
        "OutputBucketName.$": "$.Transcribe.OutputBucketName",
        "TranscriptionJobName.$": "$.Transcribe.TranscriptionJobName",
        "Subtitles": {
          "Formats": [
            "srt",
            "vtt"
          ],
          "OutputStartIndex": 1
        }
      },
      "Resource": "arn:aws:states:::aws-sdk:transcribe:startTranscriptionJob",
      "Next": "GetTranscriptionJob"
    },
    "GetTranscriptionJob": {
      "Type": "Task",
      "Parameters": {
        "TranscriptionJobName.$": "$.TranscriptionJob.TranscriptionJobName"
      },
      "Resource": "arn:aws:states:::aws-sdk:transcribe:getTranscriptionJob",
      "Next": "Is Running?"
    },
    "Is Running?": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.TranscriptionJob.TranscriptionJobStatus",
          "StringEquals": "IN_PROGRESS",
          "Next": "Wait for Transcription to Complete"
        }
      ],
      "Default": "Success"
    },
    "Success": {
      "Type": "Succeed"
    },
    "Wait for Transcription to Complete": {
      "Type": "Wait",
      "Seconds": 5,
      "Next": "GetTranscriptionJob"
    }
  }
}
EOF
)

# Creates the role
# ROLE_RESPONSE=$(aws iam create-role --role-name "$ROLE_NAME" --path /service-role/ --assume-role-policy-document "$ASSUME_ROLE_POLICY_JSON" --max-session-duration 3600 --output json)
# if [ $? -ne 0 ]; then
#     echo "Error: Failed to create the role $ROLE_NAME" >&2
#     echo "$ROLE_RESPONSE"
#     exit 1
# fi


# # Gets the ARN of the role using jq
# ROLE_ARN=$(echo $ROLE_RESPONSE | jq -r '.Role.Arn')
# echo "Role ARN: $ROLE_ARN"

# Creates the policy and captures the output into an environment variable
POLICY_RESPONSE=$(aws iam create-policy --policy-name "$POLICY_NAME" --policy-document "$POLICY_JSON" --output json)
if [ $? -ne 0 ]; then
    echo "Error: Failed to create the policy $ROLE_NAME" >&2
    echo "$POLICY_RESPONSE"
    exit 1
fi

# Extract the policy ARN from the response
POLICY_ARN=$(echo $POLICY_RESPONSE | jq -r '.Policy.Arn')
echo "Policy ARN: $POLICY_ARN"

# Attaches the policy to the role using the extracted policy ARN
# ATTACH_ROLE_POLICY_RESPONSE=$(aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn $POLICY_ARN)
# if [ $? -ne 0 ]; then
#     echo "Error: Failed to attach the policy $POLICY_ARN to the role $ROLE_NAME" >&2
#     echo "$ATTACH_ROLE_POLICY_RESPONSE"
#     exit 1
# fi

# Creates the step function
aws stepfunctions create-state-machine \
  --name "${STEP_FUNCTION_NAME}" \
  --definition "$STEP_FUNCTION_JSON" \
  --role-arn "${ROLE_ARN}" \
  --no-paginate
