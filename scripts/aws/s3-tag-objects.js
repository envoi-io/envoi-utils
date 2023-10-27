#!/usr/bin/env node
const isMainScript = !(module?.parent);
const fs = require('fs').promises;
const Path = require('path');
const http = require('https');

class Logger {
  logger;
  logLevelIndex = 3;
  logLevels = [ 'OFF', 'ERROR', 'WARN', 'INFO', 'DEBUG' ];

  constructor({ handler = console, logLevel = 'INFO' } = {}) {
    this.logger = handler

    this.debugLevelIndex = this.logLevels.indexOf(logLevel.toUpperCase())
    if (this.logLevelIndex === -1) {
      this.logLevelIndex = 3
      this.warn(`Unknown logging level specified "${logLevel}". Reverting to the default value of "INFO"`)
    }
  }

  debug(...args) { if (this.logLevelIndex >= 4) this.logger.debug(...args) }
  error(...args) { if (this?.logLevelIndex >= 1) this.logger.error(...args) }
  info(...args) { if (this.logLevelIndex >= 3) this.logger.info(...args) }
  log(...args) { this.info(...args) }
  warn(...args) { if (this.logLevelIndex >= 2) this.logger.warn(...args) }

}
const logLevel = process.env['LOG_LEVEL'] || 'INFO'
const logger = new Logger({ logLevel })



/**
 * Normally the code within this function would be in the top level. It is wrapped in a function to allow for the auto initialization to work all from within one file
 * @returns {{lambdaEventHandler: ((function(*): Promise<boolean|undefined>)|*), parseCliArgs: (function({argv?: *}): *), AppStorageHelper: AppStorageHelper, AwsHelper: AwsHelper, getAndTagS3Objects: ((function({bucketName: *, objectKeyPrefix: *, tags: *, clientPassThroughArgs?: {}, commandPassThroughArgs?: {}, [p: string]: *}): Promise<void>)|*)}}
 */
function localModule() {

  const {
    S3Client,
    GetObjectCommand,
    ListObjectsV2Command,
    PutObjectTaggingCommand
  } = require('@aws-sdk/client-s3');

  const {
    AssumeRoleCommand,
    GetCallerIdentityCommand,
    STSClient
  } = require('@aws-sdk/client-sts');

// Helper Classes

// const AppStorageHelper = require('lib/AppStorageHelper')
// AppStorageHelper.js
  class AppStorageHelper {

    static async fileDelete({ filePath }) {
      logger.debug(`[AppStorageHelper.fileRead] Reading '${filePath}`)
      let filePathAsUrl = filePath.includes('://') ? new URL(filePath) : undefined
      let response
      if (filePathAsUrl?.protocol === 's3:') {
        response = this.fileDeleteFromS3({ filePath })
      } else {
        response = this.fileDeleteFromLocalFileSystem({ filePath })
      }
      return response

    }

    static async fileDeleteFromLocalFileSystem({ filePath }) {
      return await fs.unlink(filePath) === undefined
    }

    static async fileDeleteFromS3({ filePath }) {
      logger.debug('Current directory: ' + process.cwd());
      let aws = new AwsHelper()

      let url = new URL(filePath)
      let bucketName = url.host
      let objectKey = url.pathname

      if (objectKey.startsWith('/')) { objectKey = objectKey.slice(1) }
      return aws.deleteObject({ bucketName, objectKey })
    }

    static async fileRead({ filePath, returnAsString = true }) {
      logger.debug(`[AppStorageHelper.fileRead] Reading '${filePath}`)
      let filePathAsUrl = filePath.includes('://') ? new URL(filePath) : undefined
      let contents
      if (filePathAsUrl?.protocol === 's3:') {
        contents = await this.fileReadFromS3({ filePath, returnAsString })
      } else if (filePathAsUrl && [ 'https:', 'http:' ].includes(filePathAsUrl.protocol)) {
        contents = await this.fileReadFromHttp({ filePath, returnAsString })
      } else {
        contents = await this.fileReadFromLocalFileSystem({ filePath, returnAsString })
      }
      return contents
    }

    static async fileReadFromHttp({ filePath, returnAsString = true }) {
      const response = await HttpClient.doRequest({ url: filePath })
      return (response.bodyParsed && !returnAsString) ? response.bodyParsed : response.body
    }

    static async fileReadFromLocalFileSystem({ filePath, returnAsString = true }) {
      logger.debug('[AppStorageHelper.fileReadFromLocalFileSystem] Current directory: ' + process.cwd());
      const contents = await fs.readFile(filePath)
      return returnAsString ? contents.toString() : contents
    }

    static async fileReadFromS3({ filePath, returnAsString = true }) {
      logger.debug(`[AppStorageHelper.readFileFromS3] Reading '${filePath}`)
      let aws = new AwsHelper()

      let url = new URL(filePath)
      let bucketName = url.host
      let objectKey = url.pathname

      if (objectKey.startsWith('/')) { objectKey = objectKey.slice(1) }

      let contents = await aws.readFromS3({ bucketName, objectKey, returnAsString: true })
      return returnAsString && contents ? contents.toString() : contents
    }

    static async fileReadJson({ filePath }) {
      try {
        let contents = await this.fileRead({ filePath })
        return contents === undefined ? contents : JSON.parse(contents)
      } catch (e) {
        logger.error('[AppStorageHelper.fileReadJson] Exception', e)
      }
    }

    static async fileWrite(filePath, content) {
      logger.debug(`[AppStorageHelper.fileWrite] Writing '${filePath}`)
      let response
      if (filePath.startsWith('s3://')) {
        response = await this.fileWriteToS3({ filePath, content })
      } else {
        let filePathInfo = Path.parse(filePath)
        await fs.mkdir(filePathInfo.dir, { recursive: true })
        response = await this.fileWriteToLocalFileSystem({ filePath, content })
      }
      return response
    }

    static async fileWriteToLocalFileSystem({ filePath, content }) {
      logger.debug('Current directory: ' + process.cwd());
      return fs.writeFile(filePath, content)
    }

    async fileWriteToS3({ filePath, content }) {
      return this.constructor.fileWriteToS3({ filePath, content })
    }

    static async fileWriteToS3({ filePath, content }) {
      logger.debug('Current directory: ' + process.cwd());
      let aws = new AwsHelper()

      let url = new URL(filePath)
      let bucketName = url.host
      let objectKey = url.pathname

      if (objectKey.startsWith('/')) { objectKey = objectKey.slice(1) }
      return await aws.writeToS3({ bucketName, objectKey, content })
    }

  }

// const AwsHelper = require('lib/AwsHelper')
// AwsHelper.js
  class AwsHelper {

    /**
     *
     * @param region
     * @returns {Promise<GetCallerIdentityCommandOutput>}
     */
    static async getCallerIdentity({ region = 'us-east-1' }) {
      const sts = new STSClient({ region })
      const command = new GetCallerIdentityCommand({})
      return sts.send(command)
    }

    /**
     *
     * @param sts
     * @param accountId
     * @param roleName
     * @param roleArn
     * @param [region='us-east-1'] This will alomost always be us-east-1
     * @param sessionName
     * @returns {Promise<AssumeRoleCommandOutput>}
     */
    static async getCrossAccountCredentials({ sts, accountId, roleName = 'envoi-dev', roleArn, region = 'us-east-1', sessionName }) {
      const params = {
        RoleArn: roleArn || `arn:aws:iam::${accountId}:role/${roleName}`,
        RoleSessionName: sessionName || `aws-helper-${(new Date()).getTime()}`
      };
      logger.debug('[AwsHelper.getCrossAccountCredentials] Assuming Role', params)

      if (!sts) sts = new STSClient({ region })
      return sts.send(new AssumeRoleCommand(params))
    }

    /**
     *
     * @param accountId
     * @param roleName
     * @param region
     * @returns {Promise<AssumeRoleCommandOutput>}
     */
    static async getCredentialsForAccount({ accountId, roleName = 'aws-helper', region = 'us-east-1' }) {
      const sts = new STSClient({ region })
      // @TODO Fix the assume role RoleArn to be consistent
      return sts.send(new AssumeRoleCommand({ RoleArn: `arn:aws:iam::${accountId}:role/${roleName}` }))
    }

    static async* paginate({ client, command, shouldYield = false, propertyToYield = 'Contents', forceTruncate = false }) {
      try {
        let isTruncated = true;
        let valuesOut = [];

        while (isTruncated) {
          const response = await client.send(command);
          logger.debug('paginate', { command, response })
          const { Contents, IsTruncated, NextContinuationToken } = response

          if (shouldYield) {
            const valueOut = propertyToYield ? response[propertyToYield] : response
            logger.debug({ propertyToYield, valueOut })
            yield valueOut
          }
          valuesOut.concat(Contents)

          isTruncated = forceTruncate || IsTruncated;
          command.input.ContinuationToken = NextContinuationToken;
        }

        return valuesOut
      } catch (err) {
        logger.error(err);
      }
    }

    async listObjects({ client, bucketName, objectKeyPrefix, pageSize = 1000, page = null, clientPassThroughArgs = {}, commandPassThroughArgs = {}, shouldYield = false }) {

      const clientArgs = clientPassThroughArgs
      if (!client) client = new S3Client(clientArgs)

      const commandArgs = commandPassThroughArgs || {}
      commandArgs['Bucket'] = bucketName
      if (objectKeyPrefix) commandArgs['Prefix'] = objectKeyPrefix

      const command = new ListObjectsV2Command(commandArgs)
      const pages = paginate(cient, command)
      try {

        let isTruncated = true;

        let objectsOut = []

        while (isTruncated) {
          const { Contents, IsTruncated, NextContinuationToken } = await client.send(command);
          objectsOut.concat(Contents)

          isTruncated = IsTruncated;
          command.input.ContinuationToken = NextContinuationToken;
        }
        logger.log(contents);
      } catch (err) {
        logger.error(err);
      }

    }

    async readFromS3({ bucketName, objectKey, region = undefined, credentials = undefined, returnAsString = true, ...args } = {}) {
      try {
        let s3Args = {}

        if (credentials) s3Args['credentials'] = credentials
        if (region) s3Args['region'] = region

        let s3 = new S3Client(s3Args)

        let getObjectArgs = {
          Bucket: bucketName,
          Key: objectKey
        }
        logger.debug('[AwsHelper.readFromS3]', { getObjectArgs })
        const command = new GetObjectCommand(getObjectArgs)
        const response = await s3.send(command)
        logger.debug('[AwsHelper.readFromS3]', { response })

        if (returnAsString) {
          return response.Body.transformToString()
        }

        return response
      } catch (e) {
        switch (e.code) {
          case 'NoSuchKey':
            logger.warn('[AwsHelper.readFromS3] ', e)
            return

          default:
            logger.error('[AwsHelper.readFromS3] Exception', e)
            throw e
        }
      }
    }
  }

// const HttpClient = require('lib/HttpClient')
// HttpClient.js
  class HttpClient {

    static async doRequest({ url = undefined, method, headers, options = undefined, body = undefined }) {
      logger.debug('[HttpClient.doRequest]', JSON.stringify({ arguments }, null, 2));

      if (method) options.method = method
      if (headers) options.headers = headers

      return new Promise((resolve, reject) => {
        let req = http.request(url, options);

        req.on('response', res => {
          const body = [];
          // on every content chunk, push it to the data array
          res.on('data', (chunk) => body.push(chunk));
          // we are done, resolve promise with those joined chunks

          res.on('end',
            () => {
              let response = { statusCode: res.statusCode, headers: res.headers, body: body.join('') };

              if (res.headers['content-type']?.startsWith('application/json')) {
                response.bodyParsed = JSON.parse(response.body);
              }
              resolve(response);
            });
        });

        req.on('error', err => {
          reject(err);
        });

        req.on('timeout', () => {
          req.destroy();
          reject(new Error('timed out'));
        });

        if (body) req.write(body);

        req.end();
      });
    }

  }

  async function tagS3Object({ client, bucketName, object, tags, tagSet = [] }) {
    const objectKey = decodeURIComponent((object.Key || object.key || '').replaceAll('+', '%20'))
    logger.info(`Setting tags on object "s3://${bucketName}/${objectKey}"`)
    if (tags) tagSet = tagSet.concat(Object.entries(tags).map(([k,v]) => {
      return { "Key": k, "Value": v }
    }))

    const commandArgs = {
      'Bucket': bucketName,
      'Key': objectKey,
      'VersionId': object.VersionId,
      'Tagging': {
        'TagSet': tagSet
      }
    }
    const command = new PutObjectTaggingCommand(commandArgs)
    return client.send(command)
  }

  async function getAndTagS3Objects({ bucketName, objectKeyPrefix, tags, clientPassThroughArgs = {}, commandPassThroughArgs = {}, ...args }) {

    const s3Client = new S3Client(clientPassThroughArgs)

    const commandArgs = commandPassThroughArgs || {}
    commandArgs['Bucket'] = bucketName
    if (objectKeyPrefix) commandArgs['Prefix'] = objectKeyPrefix

    const command = new ListObjectsV2Command(commandArgs)
    try {
      const pages = AwsHelper.paginate({ client: s3Client, command, shouldYield: true })
      logger.debug({ pages })
      while(true) {
        const page = await pages.next()
        logger.debug({ page, value: page.value })
        if (page.done || !page.value) break

        for (const object of page.value) {
          logger.debug({ object })
          if (!object.Key.endsWith('/')) {
            await tagS3Object({ client: s3Client, bucketName, object, tags })
          }
        }
      }
    } catch (err) {
      logger.error(err);
    }

  }

  function getTagsFromTagMap({ bucketName, objectKey, objectKeyPrefix, tagMap }) {
    const bucketPrefixes = tagMap[bucketName]
    if (!bucketPrefixes) {
      logger.warn(`[getTagsFromTagMap] No map found for bucket "${bucketName}"`)
      return false
    }

    const objectKeyPrefixes = Object.keys(bucketPrefixes)
    if (!objectKeyPrefix) {
      if (!objectKey) {
        logger.warn('[getTagsFromTagMap] No object key or object key prefix specified.')
        return false
      }

      objectKeyPrefix = objectKeyPrefixes.find(prefix => objectKey.startsWith(prefix) )
      if (!objectKeyPrefix) {
        logger.warn(`[getTagsFromTagMap] No map found for object key "${objectKey} in list ${objectKeyPrefixes}`)
        return false
      }
    }

    // logger.debug({ bucketPrefixes })
    const objectTags = bucketPrefixes[objectKeyPrefix]
    if (!objectTags) {
      logger.warn(`[getTagsFromTagMap] No map found for prefix "${objectKeyPrefix}" in list ${objectKeyPrefixes}`)
      return false
    }

    return objectTags
  }

  async function getTagsFromTagMapFile({ tagMapFilePath, bucketName, objectKey, objectKeyPrefix }) {
    const tagMapFromFile = await AppStorageHelper.fileReadJson({ filePath: tagMapFilePath })
    logger.debug({ tagMapFromFile })

    return getTagsFromTagMap({ bucketName, objectKey, objectKeyPrefix, tagMap: tagMapFromFile })
  }

  async function s3RecordHandler(record) {
    logger.info('[s3RecordHandler] Processing Record.')
    logger.debug('[s3RecordHandler]', { record })
    const tagMapFilePath = process.env['TAG_MAP_FILE_PATH']
    if (!tagMapFilePath) {
      logger.error('[s3RecordHandler] No value set for "TAG_MAP_FILE_PATH". Exiting.')
      return
    }

    const region = record['awsRegion']
    const s3Data = record.s3
    const bucket = s3Data.bucket
    const object = s3Data.object

    const bucketName = bucket.name
    const objectKey = object.key
    const tags = await getTagsFromTagMapFile({ tagMapFilePath, bucketName, objectKey })

    if (tags) {
      // await getAndTagS3Objects({ bucketName, objectKeyPrefix: objectKey, tags})
      const s3Client = new S3Client({ region })
      await tagS3Object({ client: s3Client, bucketName, object, tags })
    } else {
      logger.info(`[s3RecordHandler] No tags found in tag map for "${bucketName}/${objectKey}`)
    }

    return true
  }

  async function processEventRecords(records) {
    for (const record of records) {
      logger.debug('[processEventRecords]', { record })
      const eventSource = record['eventSource']
      switch(eventSource) {
        case 'aws:s3':
          await s3RecordHandler(record);
          break;

        default:
          logger.warn(`[processEventRecords] Unknown event source "${eventSource}"`)
      }
    }
  }

  async function lambdaEventHandler(event) {
    const eventAsString = JSON.stringify(event, null, 2)
    logger.debug('event', eventAsString)
    if (event.hasOwnProperty('Records')) {
      const records = event['Records']
      await processEventRecords(records)
    } else {
      throw "Unknown event format."
    }
  }

  function loadMinimist() {
    // minimist/index.js
    function hasKey(obj, keys) {
      var o = obj;
      keys.slice(0, -1).forEach(function(key) {
        o = o[key] || {};
      });

      var key = keys[keys.length - 1];
      return key in o;
    }

    function isNumber(x) {
      if (typeof x === 'number') { return true; }
      if ((/^0x[0-9a-f]+$/i).test(x)) { return true; }
      return (/^[-+]?(?:\d+(?:\.\d*)?|\.\d+)(e[-+]?\d+)?$/).test(x);
    }

    function isConstructorOrProto(obj, key) {
      return (key === 'constructor' && typeof obj[key] === 'function') || key === '__proto__';
    }

    const minimist = function(args = process.argv, opts = {}) {
      var flags = {
        bools: {},
        strings: {},
        unknownFn: null,
      };

      if (typeof opts.unknown === 'function') {
        flags.unknownFn = opts.unknown;
      }

      if (typeof opts.boolean === 'boolean' && opts.boolean) {
        flags.allBools = true;
      } else {
        [].concat(opts.boolean).filter(Boolean).forEach(function(key) {
          flags.bools[key] = true;
        });
      }

      var aliases = {};

      function isBooleanKey(key) {
        if (flags.bools[key]) {
          return true;
        }
        if (!aliases[key]) {
          return false;
        }
        return aliases[key].some(function(x) {
          return flags.bools[x];
        });
      }

      Object.keys(opts.alias || {}).forEach(function(key) {
        aliases[key] = [].concat(opts.alias[key]);
        aliases[key].forEach(function(x) {
          aliases[x] = [ key ].concat(aliases[key].filter(function(y) {
            return x !== y;
          }));
        });
      });

      [].concat(opts.string).filter(Boolean).forEach(function(key) {
        flags.strings[key] = true;
        if (aliases[key]) {
          [].concat(aliases[key]).forEach(function(k) {
            flags.strings[k] = true;
          });
        }
      });

      var defaults = opts.default || {};

      var argv = { _: [] };

      function argDefined(key, arg) {
        return (flags.allBools && (/^--[^=]+$/).test(arg))
          || flags.strings[key]
          || flags.bools[key]
          || aliases[key];
      }

      function setKey(obj, keys, value) {
        var o = obj;
        for (var i = 0; i < keys.length - 1; i++) {
          var key = keys[i];
          if (isConstructorOrProto(o, key)) { return; }
          if (o[key] === undefined) { o[key] = {}; }
          if (
            o[key] === Object.prototype
            || o[key] === Number.prototype
            || o[key] === String.prototype
          ) {
            o[key] = {};
          }
          if (o[key] === Array.prototype) { o[key] = []; }
          o = o[key];
        }

        var lastKey = keys[keys.length - 1];
        if (isConstructorOrProto(o, lastKey)) { return; }
        if (
          o === Object.prototype
          || o === Number.prototype
          || o === String.prototype
        ) {
          o = {};
        }
        if (o === Array.prototype) { o = []; }
        if (o[lastKey] === undefined || isBooleanKey(lastKey) || typeof o[lastKey] === 'boolean') {
          o[lastKey] = value;
        } else if (Array.isArray(o[lastKey])) {
          o[lastKey].push(value);
        } else {
          o[lastKey] = [ o[lastKey], value ];
        }
      }

      function setArg(key, val, arg) {
        if (arg && flags.unknownFn && !argDefined(key, arg)) {
          if (flags.unknownFn(arg) === false) { return; }
        }

        var value = !flags.strings[key] && isNumber(val)
          ? Number(val)
          : val;
        setKey(argv, key.split('.'), value);

        (aliases[key] || []).forEach(function(x) {
          setKey(argv, x.split('.'), value);
        });
      }

      // Set booleans to false by default.
      Object.keys(flags.bools).forEach(function(key) {
        setArg(key, false);
      });
      // Set booleans to user defined default if supplied.
      Object.keys(defaults).filter(isBooleanKey).forEach(function(key) {
        setArg(key, defaults[key]);
      });
      var notFlags = [];

      if (args.indexOf('--') !== -1) {
        notFlags = args.slice(args.indexOf('--') + 1);
        args = args.slice(0, args.indexOf('--'));
      }

      for (var i = 0; i < args.length; i++) {
        var arg = args[i];
        var key;
        var next;

        if ((/^--.+=/).test(arg)) {
          // Using [\s\S] instead of . because js doesn't support the
          // 'dotall' regex modifier. See:
          // http://stackoverflow.com/a/1068308/13216
          var m = arg.match(/^--([^=]+)=([\s\S]*)$/);
          key = m[1];
          var value = m[2];
          if (isBooleanKey(key)) {
            value = value !== 'false';
          }
          setArg(key, value, arg);
        } else if ((/^--no-.+/).test(arg)) {
          key = arg.match(/^--no-(.+)/)[1];
          setArg(key, false, arg);
        } else if ((/^--.+/).test(arg)) {
          key = arg.match(/^--(.+)/)[1];
          next = args[i + 1];
          if (
            next !== undefined
            && !(/^(-|--)[^-]/).test(next)
            && !isBooleanKey(key)
            && !flags.allBools
          ) {
            setArg(key, next, arg);
            i += 1;
          } else if ((/^(true|false)$/).test(next)) {
            setArg(key, next === 'true', arg);
            i += 1;
          } else {
            setArg(key, flags.strings[key] ? '' : true, arg);
          }
        } else if ((/^-[^-]+/).test(arg)) {
          var letters = arg.slice(1, -1).split('');

          var broken = false;
          for (var j = 0; j < letters.length; j++) {
            next = arg.slice(j + 2);

            if (next === '-') {
              setArg(letters[j], next, arg);
              continue;
            }

            if ((/[A-Za-z]/).test(letters[j]) && next[0] === '=') {
              setArg(letters[j], next.slice(1), arg);
              broken = true;
              break;
            }

            if (
              (/[A-Za-z]/).test(letters[j])
              && (/-?\d+(\.\d*)?(e-?\d+)?$/).test(next)
            ) {
              setArg(letters[j], next, arg);
              broken = true;
              break;
            }

            if (letters[j + 1] && letters[j + 1].match(/\W/)) {
              setArg(letters[j], arg.slice(j + 2), arg);
              broken = true;
              break;
            } else {
              setArg(letters[j], flags.strings[letters[j]] ? '' : true, arg);
            }
          }

          key = arg.slice(-1)[0];
          if (!broken && key !== '-') {
            if (
              args[i + 1]
              && !(/^(-|--)[^-]/).test(args[i + 1])
              && !isBooleanKey(key)
            ) {
              setArg(key, args[i + 1], arg);
              i += 1;
            } else if (args[i + 1] && (/^(true|false)$/).test(args[i + 1])) {
              setArg(key, args[i + 1] === 'true', arg);
              i += 1;
            } else {
              setArg(key, flags.strings[key] ? '' : true, arg);
            }
          }
        } else {
          if (!flags.unknownFn || flags.unknownFn(arg) !== false) {
            argv._.push(flags.strings._ || !isNumber(arg) ? arg : Number(arg));
          }
          if (opts.stopEarly) {
            argv._.push.apply(argv._, args.slice(i + 1));
            break;
          }
        }
      }

      Object.keys(defaults).forEach(function(k) {
        if (!hasKey(argv, k.split('.'))) {
          setKey(argv, k.split('.'), defaults[k]);

          (aliases[k] || []).forEach(function(x) {
            setKey(argv, x.split('.'), defaults[k]);
          });
        }
      });

      if (opts['--']) {
        argv['--'] = notFlags.slice();
      } else {
        notFlags.forEach(function(k) {
          argv._.push(k);
        });
      }

      return argv;
    }

    return minimist
  }

  function parseCliArgsUsingMinimist({ argv }) {
    const minimist = loadMinimist()
    const argvParsed = minimist(argv)

    const {
      'bucket': bucketName,
      'iam-role-arn': iamRoleArn,
      'prefix': objectKeyPrefix,
      'tag-map-file': tagMapFilePath
    } = argvParsed

    return {
      bucketName,
      iamRoleArn,
      objectKeyPrefix,
      tagMapFilePath
    }
  }

  function parseCliArgsUsingYargs({ argv }) {
    const yargs = require('yargs/yargs')
  }

  function parseCliArgs({ argv = process.argv}) {
    let parserProc
    // try {
    //   require('yargs/yargs')
    //   parserProc = parseCliArgsUsingYargs
    // } catch(e) {
    //   parserProc = parseCliArgsUsingMinimist
    // }

    parserProc = parseCliArgsUsingMinimist
    return parserProc({ argv })
  }

  return {
    parseCliArgs,
    AwsHelper,
    getAndTagS3Objects,
    getTagsFromTagMapFile,
    lambdaEventHandler,
    handler: lambdaEventHandler
  }

}

// s3-tag-objects.js



async function cliHandler() {
  await cliInit()
  const {
    AwsHelper,
    getAndTagS3Objects,
    getTagsFromTagMapFile,
    parseCliArgs
  } = localModule()

  // Read Arguments
  const args = parseCliArgs({ argv: process.argv })
  logger.debug({ args })

  const {
    bucketName,
    iamRoleArn,
    objectKeyPrefix,
    tags,
    tagMapFilePath,
  } = args

  let missingRequiredParameter = false
  if (!bucketName) {
    logger.error('Missing required parameter: bucket name')
    missingRequiredParameter = true
  }

  if (!objectKeyPrefix) {
    logger.error('Missing required parameter: object prefix')
    missingRequiredParameter = true
  }

  if (!tags && !tagMapFilePath) {
    logger.error('Missing required parameter: tag map or tag map filename')
    missingRequiredParameter = true
  }

  if (missingRequiredParameter) {
    logger.debug({ args });
    return false
  }

  const clientArgs = {}

  // Assume Role?
  if (iamRoleArn) {
    clientArgs['Credentials'] = AwsHelper.getCrossAccountCredentials({ roleArn: iamRoleArn })
  }

  let objectTags
  if (tags) {
    objectTags = tags
  } else if (tagMapFilePath) {
    logger.debug('Getting tags from tag map file.')
    objectTags = await getTagsFromTagMapFile({ tagMapFilePath, bucketName, objectKeyPrefix })
  }

  logger.debug({ objectTags })

  if (typeof objectTags !== 'object') {
    logger.error('Could not determine what tags to put on the object.')
    return false
  }

  await getAndTagS3Objects({ bucketName, objectKeyPrefix, tags: objectTags, clientArgsPassThrough: clientArgs })

  return true
}

/**
 * THis will check the CLI environment and make sure dependencies are available and if not then it will offer to install them.
 *
 * @returns {Promise<boolean>}
 */
async function cliInit() {
  let dependenciesMet = false
  try {
    require('@aws-sdk/core')
    dependenciesMet = true
  } catch(e) {
    logger.warn('Unable to load the module @aws-sdk')
  }

  if (dependenciesMet) return true
  const readline = require('readline');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const prompt = (query) => new Promise((resolve) => rl.question(query, resolve));
  const doInstall = await prompt('Automatically install dependencies? ')
  rl.close()

  const commands = [
    'npm init -y',
    'npm i @aws-sdk/client-s3 @aws-sdk/client-sts'
  ]

  if ([ 'y', 'yes' ].includes((doInstall || '').toLowerCase())) {
    logger.info('Installing dependencies...')
    const {execSync} = require('child_process')
    for (const command of commands)  {
      execSync(command)
    }
    logger.info('Installation complete.')
    logger.debug('CLI Initialized.')
  } else {
    logger.error(`Unable to load the module @aws-sdk - run "${commands.join('; ')}"`);
    process.exit(1)
  }

  return true;
}

if (isMainScript) {
  const result = cliHandler().catch(logger.error);
  if (!result) process.exit(1);
} else {
  module.exports = localModule();
}
