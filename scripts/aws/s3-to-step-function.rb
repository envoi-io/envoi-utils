#!/usr/bin/env ruby
require 'optparse'
require 'logger'

require 'aws-sdk-s3'
require 'aws-sdk-states'


options = {}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: submit-to-step-function.rb [options]'

  opts.on('-b', '--bucket BUCKET', 'The name of the S3 bucket.') do |bucket|
    options[:bucket_name] = bucket
  end

  opts.on('-p', '--prefix PREFIX', 'The object prefix.') do |prefix|
    options[:object_key_prefix] = prefix
  end

  opts.on('-s', '--state-machine-arn STATE_MACHINE_ARN', 'The ARN of the Step Function.') do |state_machine_arn|
    options[:state_machine_arn] = state_machine_arn
  end

  opts.on('-h', '--help', 'Display this help message.') do
    puts opts
    exit
  end
end

parser.parse!(ARGV)

if options[:bucket_name].nil? || options[:state_machine_arn].nil?
  puts 'Missing required options: --bucket, --state-machine-arn'
  puts parser.help
  exit
end

def list_s3_objects(bucket_name, object_key_prefix)
  s3 = Aws::S3::Client.new
  all_objects = []
  next_continuation_token = nil
  loop do
    logger.debug(%(Listing S3 Objects for bucket "#{bucket_name}" prefix "#{object_key_prefix}" next_token: #{next_continuation_token}))
    resp = s3.list_objects_v2(bucket: bucket_name, prefix: object_key_prefix, continuation_token: next_continuation_token)

    all_objects += resp[:contents]
    next_continuation_token = resp[:next_continuation_token]

    break if next_continuation_token.nil?
  end
  all_objects
end

def summarize_objects(objects)
  object_count = objects.length
  object_size = objects.reduce(0) { |sum, object| sum + object[:size] }
  singular_count = object_count == 1
  singular_bytes = object_size == 1

  digits_as_groups_of_three_regex = Regexp.new(/(\d{3})(?=\d)/)

  object_count_human_readable = object_count.to_s.reverse.gsub(digits_as_groups_of_three_regex, '\\1,').reverse
  bytes_human_readable = object_size.to_s.reverse.gsub(digits_as_groups_of_three_regex, '\\1,').reverse

  [object_count, object_size, singular_count, singular_bytes, object_count_human_readable, bytes_human_readable]
end

def prompt_for_confirmation(objects, state_machine_arn)
  _object_count, _object_size, singular_count, singular_bytes, object_count_human_readable, bytes_human_readable = summarize_objects(objects)

  puts "There #{singular_count ? 'is' : 'are'} #{object_count_human_readable} object#{singular_count ? '' : 's'} with a total size of #{bytes_human_readable} byte#{singular_bytes ? '' : 's'}."
  puts %(Are you sure you want to submit these objects to the step function "#{state_machine_arn}"? [y/N])

  require 'io/console'
  response = $stdin.getch

  response.downcase == 'y'
end

def submit_to_step_function(state_machine_arn, bucket_name, objects)
  step_functions = Aws::States::Client.new

  objects.each do |object|
    s3_url = "s3://#{bucket_name}/#{object.key}"

    payload = {
      url: s3_url,
      object: {
        key: object.key,
        size: object.size,
        last_modified: object.last_modified,
        storage_class: object.storage_class,
        etag: object.etag
      }
    }

    step_functions.start_execution(state_machine_arn: state_machine_arn, input: payload.to_json)
  end
end

@logger = Logger.new($stdout)
def logger
  @logger
end

bucket_name = options[:bucket_name]
object_key_prefix = options[:object_key_prefix]
state_machine_arn = options[:state_machine_arn]

objects = list_s3_objects(bucket_name, object_key_prefix)

if prompt_for_confirmation(objects, state_machine_arn)
  submit_to_step_function(state_machine_arn, bucket_name, objects)
else
  puts 'Aborting...'
end
