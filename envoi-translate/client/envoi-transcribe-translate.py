#!/usr/bin/env python3

import argparse
import boto3
from botocore.exceptions import ClientError
from datetime import datetime
import json
from json import JSONEncoder
import logging
import os
import sys
from urllib.parse import urlparse
import uuid

logger = logging.Logger('envoi-transcribe-translate')


class CustomJsonEncoder(JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return JSONEncoder.default(self, obj)


class EnvoiTranscribeTranslateCreateCommand:

    def __init__(self, opts):
        self.opts = opts

    def run(self, opts=None):
        if opts is None:
            opts = self.opts

        run_input = build_run_input(opts)
        if opts.dry_run:
            print(json.dumps(run_input, indent=2))
        else:
            execution_arn = run_step_function(opts.state_machine_arn, run_input)
            print(execution_arn)

    @classmethod
    def init_parser(cls, subparsers=None, command_name="create"):
        if subparsers is None:
            parser = argparse.ArgumentParser()
        else:
            parser = subparsers.add_parser(
                command_name,
                help="Create a new state machine.",
            )
        parser.set_defaults(handler=cls)
        parser.add_argument('--media-file-uri', dest='media_file_uri',
                            required=True,
                            help='The S3 URI of the media file to transcribe.')
        parser.add_argument('--output-bucket-name', dest='output_bucket_name',
                            required=True,
                            help='The S3 URI of the output file.')
        parser.add_argument('--state-machine-arn', dest='state_machine_arn',
                            default='arn:aws:states:us-east-1:524540001196:stateMachine:envoi-transcribe',
                            help='The ARN of the state machine to run.')
        parser.add_argument('--source-language', dest='source_language',
                            default='en',
                            help='The language of the source file.')
        parser.add_argument('-l', '--translation-languages', dest='translation_languages',
                            nargs="+",
                            help='The languages to translate to.')
        parser.add_argument("--log-level", dest="log_level",
                            default="WARNING",
                            help="Set the logging level (options: DEBUG, INFO, WARNING, ERROR, CRITICAL)")
        parser.add_argument('--job-name', dest='transcription_job_name',
                            default=None,
                            help='The name of the job.')
        parser.add_argument('--dry-run', dest='dry_run',
                            action='store_true',
                            help='Do not run the state machine, just print the input.')
        return parser


class EnvoiTranscribeTranslateDescribeCommand:

    def __init__(self, opts=None):
        self.opts = opts

    def run(self, opts=None):
        if opts is None:
            opts = self.opts

        execution_arn = opts.execution_arn
        sme = StateMachineExecution(execution_arn=execution_arn)
        description = sme.describe()
        logger.debug(f"Description: {description}")

        input_as_string = description.get('input', None)
        output_as_string = description.get('output', None)

        if input_as_string is not None:
            input_as_json = json.loads(input_as_string)
            description['input'] = input_as_json
            # print(json.dumps(input_as_json, indent=2))

        output_as_json = None
        if output_as_string is not None:
            output_as_json = json.loads(output_as_string)
            description['output'] = output_as_json
            # print(json.dumps(output_as_json, indent=2))

        if opts.uris_only:
            transcription_job = output_as_json.get('TranscriptionJob', {})
            subtitles = transcription_job.get('Subtitles', {})
            sub_title_file_urls = subtitles.get('SubtitleFileUris', None)

            transcript = transcription_job.get('Transcript', None)
            transcript_uri = transcript.get('TranscriptFileUri', None)

            output = {
                "Transcription": {
                    "TranscriptFileUri": transcript_uri,
                    "SubtitleFileUris": sub_title_file_urls
                }
            }
            print(json.dumps(output, indent=2))

        else:
            print(json.dumps(json.loads(CustomJsonEncoder().encode(description)), indent=2))



    @classmethod
    def init_parser(cls, subparsers=None, command_name="describe"):
        if subparsers is None:
            parser = argparse.ArgumentParser()
        else:
            parser = subparsers.add_parser(
                command_name,
                help="Describe an execution.",
            )
        parser.set_defaults(handler=cls)
        parser.add_argument(
            "--execution-arn",
            action="store",
            dest="execution_arn",
            default=None,
            help="The ARN of the state machine execution to describe.",
        )
        parser.add_argument(
            "--uris-only",
            action="store_true",
            dest="uris_only",
            default=False,
            help="Only print the URIs of the output files."
        )

        return parser


class EnvoiTranscribeTranslateCommand:

    def __init__(self):
        pass

    @classmethod
    def init_parser(cls, subparsers=None, command_name="transcribe-translate"):
        if subparsers is None:
            parser = argparse.ArgumentParser()
        else:
            parser = subparsers.add_parser(
                command_name,
                help="Interact with Transcode-Translate jobs.",
            )

        sub_commands = {
            'create': EnvoiTranscribeTranslateCreateCommand,
            'describe': EnvoiTranscribeTranslateDescribeCommand
        }

        if sub_commands is not None:
            sub_command_parsers = {}
            sub_parsers = parser.add_subparsers(dest='transcribe_translate_command')

            for sub_command_name, sub_command_handler in sub_commands.items():
                sub_command_parser = sub_command_handler.init_parser(sub_parsers, command_name=sub_command_name)
                sub_command_parser.required = True
                sub_command_parsers[sub_command_name] = sub_command_parser

        return parser


class StateMachine:
    """Encapsulates Step Functions state machine actions."""

    def __init__(self, stepfunctions_client=None, state_machine_arn=None):
        """
        :param stepfunctions_client: A Boto3 Step Functions client.
        """
        if stepfunctions_client is None:
            stepfunctions_client = boto3.client('stepfunctions')

        self.stepfunctions_client = stepfunctions_client
        self.state_machine_arn = state_machine_arn

    def start(self, run_input, state_machine_arn=None):
        """
        Start a run of a state machine with a specified input. A run is also known
        as an "execution" in Step Functions.

        :param state_machine_arn: The ARN of the state machine to run.
        :param run_input: The input to the state machine, in JSON format.
        :return: The ARN of the run. This can be used to get information about the run,
                 including its current status and final output.
        """

        if state_machine_arn is None:
            state_machine_arn = self.state_machine_arn

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


class StateMachineExecution:

    def __init__(self, stepfunctions_client=None, execution_arn=None):
        if stepfunctions_client is None:
            stepfunctions_client = boto3.client('stepfunctions')

        self.stepfunctions_client = stepfunctions_client
        self.execution_arn = execution_arn

    def describe(self):
        try:
            response = self.stepfunctions_client.describe_execution(
                executionArn=self.execution_arn
            )
        except ClientError as err:
            logger.error(
                "Couldn't describe state machine execution %s. %s: %s",
                self.execution_arn,
                err.response["Error"]["Code"],
                err.response["Error"]["Message"],
            )
            raise
        else:
            return response


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

    transcription_job_name = opts.transcription_job_name or f"{file_name_without_extension}-{str(uuid.uuid4())[:8]}"

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
            "TranscriptionJobName": transcription_job_name
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
    return [language['LanguageCode'] for language in response['Languages']]


def parse_command_line(cli_args, env_vars, sub_commands=None):
    parser = argparse.ArgumentParser(
        description='Envoi Transcribe and Translate Command Line Utility',
    )

    parser.add_argument("--log-level", dest="log_level",
                        default="WARNING",
                        help="Set the logging level (options: DEBUG, INFO, WARNING, ERROR, CRITICAL)")

    if sub_commands is not None:
        sub_command_parsers = {}
        sub_parsers = parser.add_subparsers(dest='command')

        for sub_command_name, sub_command_handler in sub_commands.items():
            sub_command_parser = sub_command_handler.init_parser(sub_parsers, command_name=sub_command_name)
            sub_command_parser.required = True
            sub_command_parsers[sub_command_name] = sub_command_parser

    (opts, args) = parser.parse_known_args(cli_args)
    return opts, args, env_vars


def main():
    cli_args = sys.argv[1:]
    env_vars = os.environ.copy()

    sub_commands = {
        'create': EnvoiTranscribeTranslateCreateCommand,
        'describe': EnvoiTranscribeTranslateDescribeCommand,
        # 'transcribe-translate': EnvoiTranscribeTranslateCommand,
    }

    opts, args, env_vars = parse_command_line(cli_args, env_vars, sub_commands)

    # We create a new handler for the root logger, so that we can get
    # setLevel to set the desired log level.
    ch = logging.StreamHandler()
    ch.setLevel(opts.log_level.upper())
    logger.addHandler(ch)

    # If 'handler' is in args, run the correct handler
    if hasattr(opts, 'handler'):
        command_handler = opts.handler(opts)
        command_handler.run()

    return 0


if __name__ == '__main__':
    main()
