#!/usr/bin/env python3

import boto3
from botocore.exceptions import ClientError
import logging
import optparse
import os
import sys
from urllib.parse import urlparse

logger = logging.Logger('envoi-transcribe-translate')
logger.setLevel(logging.WARN)


class StateMachine:
    """Encapsulates Step Functions state machine actions."""

    def __init__(self, stepfunctions_client):
        """
        :param stepfunctions_client: A Boto3 Step Functions client.
        """
        if stepfunctions_client is None:
            stepfunctions_client = boto3.client('stepfunctions')

        self.stepfunctions_client = stepfunctions_client

    def start(self, state_machine_arn, run_input):
        """
        Start a run of a state machine with a specified input. A run is also known
        as an "execution" in Step Functions.

        :param state_machine_arn: The ARN of the state machine to run.
        :param run_input: The input to the state machine, in JSON format.
        :return: The ARN of the run. This can be used to get information about the run,
                 including its current status and final output.
        """
        try:
            response = self.stepfunctions_client.start_execution(
                stateMachineArn=state_machine_arn, input=run_input
            )
        except ClientError as err:
            logger.error(
                "Couldn't start state machine %s. Here's why: %s: %s",
                state_machine_arn,
                err.response["Error"]["Code"],
                err.response["Error"]["Message"],
            )
            raise
        else:
            return response["executionArn"]


def build_run_input(opts):
    media_file_uri = opts.media_file_uri
    parsed_uri = urlparse(media_file_uri)
    file_name = os.path.basename(parsed_uri.path)

    sf_input = {
        "Transcribe": {
            "Media": {
                "MediaFileUri": media_file_uri
            },
            "TranscriptionJobName": file_name
        },
        "Translate": {}
    }
    return sf_input


def run_step_function(state_machine_arn, run_input):
    state_machine_arn = "arn:aws:states:us-east-1:1"
    run_input = {}
    execution_arn = StateMachine.start(state_machine_arn, run_input)
    return execution_arn


def parse_command_line(cli_args, env_vars):
    parser = optparse.OptionParser(
        description='Envoi Transcribe and Translate Command Line Utility',
    )

    parser.add_option('--media-file-uri', dest='media_file_uri',
                      help='The S3 URI of the media file to transcribe.')
    parser.add_option('--output-bucket-name', dest='output_bucket_name',
                      help='The S3 URI of the output file.')
    parser.add_option('--state-machine-arn', dest='state_machine_arn',
                      default='arn:aws:states:us-east-1:524540001196:stateMachine:envoi-transcribe',
                      help='The ARN of the state machine to run.')
    parser.add_option('-l', '--translation-language', dest='translation_languages',
                      action="append", type="string",
                      help='The languages to translate to.')

    (opt, args) = parser.parse_args(cli_args)
    return opt, args, env_vars


def main():
    cli_args = sys.argv[1:]
    env_vars = os.environ.copy()

    opt, args, env_vars = parse_command_line(cli_args, env_vars)
    run_input = build_run_input(opt)
    execution_arn = run_step_function(opt.state_machine_arn, run_input)
    print("Execution ARN: %s", execution_arn)
    return 0


if __name__ == '__main__':
    pass
