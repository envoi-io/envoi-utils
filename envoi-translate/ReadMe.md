# Envoi Transcription Client

## Overview

A utility that submits media files to an AWS Step Functions to process transcription jobs using AWS Transcription.

## Installation

You can install the utility by creating a symbolic link in the current user's bin directory using 
the following command:

```bash
ln -s src/envoi-transcribe-translate.py /usr/local/bin/envoi-transcribe-translate
```


# Install AWSCLI using Homebrew
brew install python
brew install awscli


## Usage

### Commands

#### `envoi-transcribe-translate create [args]`

Submit a files on AWS S3 to a AWS Step function.

./envoi-transcribe-translate.py create --log-level debug --media-file-uri "s3://[AWS_S3_BUCKET_NAME]/[AWS_S3_OBJECT_KEY]" --output-bucket-name [AWS_S3_BUCKET_NAME] --state-machine-arn arn:aws:states:[AWS_REGION]:[AWS_ACCOUNT_NUMBER]:stateMachine:tvplus-transcribe-stepfunction



### Options

#### `--log-level CLIENT`
#### `--media-file-uri CLIENT`
#### `--output-bucket-name`
#### `--state-machine-arn `

=