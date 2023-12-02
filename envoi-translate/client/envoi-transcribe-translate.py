#!/usr/bin/env python3

import boto3
from botocore.exceptions import ClientError
import json
import logging
import optparse
import os
import sys
from urllib.parse import urlparse

logger = logging.Logger('envoi-transcribe-translate')
logger.setLevel(logging.DEBUG)


class StateMachine:
    """Encapsulates Step Functions state machine actions."""

    def __init__(self, stepfunctions_client=None):
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
    """
    Build the input to the state machine.

    @see https://docs.aws.amazon.com/transcribe/latest/APIReference/API_StartTranscriptionJob.html

    :param opts: The command line options.
    :return: The input to the state machine, in JSON format.
    """

    media_file_uri = opts.media_file_uri
    parsed_uri = urlparse(media_file_uri)
    file_name = os.path.basename(parsed_uri.path)
    file_name_without_extension, file_name_ext = os.path.splitext(file_name)

    translation_languages = process_translation_languages(
        opts.translation_languages,
        opts.output_bucket_name,
        file_name_without_extension
    )

    sf_input = {
        "Transcribe": {
            "Media": {
                "MediaFileUri": media_file_uri
            },
            "OutputBucketName": opts.output_bucket_name,
            "TranscriptionJobName": file_name
        },
        "Translate": {
            "Languages": translation_languages
        }
    }
    return sf_input


def run_step_function(state_machine_arn, run_input):
    logger.debug(f"Running state machine: {state_machine_arn} {run_input}")
    run_input_json: str = json.dumps(run_input)
    execution_arn = StateMachine().start(state_machine_arn, run_input_json)
    return execution_arn


def process_translation_languages(translation_languages, output_bucket_name, file_name_without_extension):
    logger.debug("Processing translation languages: %s", translation_languages)
    if not translation_languages:
        return []

    if len(translation_languages) == 1 and translation_languages[0] == 'all':
        translation_languages = get_translation_languages()

    return [process_transcription_language(language, output_bucket_name, file_name_without_extension)
            for language in translation_languages]


def process_transcription_language(language_code, output_bucket_name, file_name_without_extension):
    return {
        "LanguageCode": language_code,
        "OutputBucketName": output_bucket_name
    }


def get_translation_languages():
    client = boto3.client('translate')
    response = client.list_languages(MaxResults=500)
    return response['Languages'].map(lambda language: language['LanguageCode'])


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
    parser.add_option('--source-language', dest='source_language',
                      default='en',
                      help='The language of the source file.')
    parser.add_option('-l', '--translation-language', dest='translation_languages',
                      action="append", type="string",
                      help='The languages to translate to.')
    parser.add_option("--log-level", dest="log_level",
                      default="WARNING",
                      help="Set the logging level (options: DEBUG, INFO, WARNING, ERROR, CRITICAL)")

    (opts, args) = parser.parse_args(cli_args)
    return opts, args, env_vars


def main():
    cli_args = sys.argv[1:]
    env_vars = os.environ.copy()

    opts, args, env_vars = parse_command_line(cli_args, env_vars)

    # We create a new handler for the root logger, so that we can get
    # setLevel to set the desired log level.
    ch = logging.StreamHandler()
    ch.setLevel(opts.log_level.upper())
    logger.addHandler(ch)

    run_input = build_run_input(opts)

    execution_arn = run_step_function(opts.state_machine_arn, run_input)
    print(f"Execution ARN: {execution_arn}")
    return 0


if __name__ == '__main__':
    main()
