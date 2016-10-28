_              = require 'lodash'
chalk          = require 'chalk'
dashdash       = require 'dashdash'
Redis          = require 'ioredis'
RedisNS        = require '@octoblu/redis-ns'
Worker         = require './src/worker'
SigtermHandler = require 'sigterm-handler'

packageJSON    = require './package.json'

OPTIONS = [
  {
    names: ['redis-uri', 'r']
    type: 'string'
    env: 'REDIS_URI'
    help: 'Redis URI'
  },
  {
    names: ['redis-namespace', 'n']
    type: 'string'
    env: 'REDIS_NAMESPACE'
    help: 'Redis namespace for redis-ns'
  },
  {
    names: ['queue-pop', 'q']
    type: 'string'
    env: 'QUEUE_POP'
    help: 'Name of Redis work queue to rpoplpush from'
  },
  {
    names: ['queue-push', 'p']
    type: 'string'
    env: 'QUEUE_PUSH'
    help: 'Name of Redis work queue to rpoplpush into'
  },
  {
    names: ['help', 'h']
    type: 'bool'
    help: 'Print this help and exit.'
  },
  {
    names: ['version', 'v']
    type: 'bool'
    help: 'Print the version and exit.'
  }
]

class Command
  constructor: ->
    process.on 'uncaughtException', @die
    @parser = dashdash.createParser({options: OPTIONS})
    {@redis_uri, @redis_namespace, @queue_pop, @queue_push} = @parseOptions()

  printHelp: =>
    options = { includeEnv: true, includeDefaults:true }
    console.log "usage: second-man-worker [OPTIONS]\noptions:\n#{@parser.help(options)}"

  parseOptions: =>
    options = @parser.parse(process.argv)

    if options.help
      @printHelp()
      process.exit 0

    if options.version
      console.log packageJSON.version
      process.exit 0

    unless options.redis_uri? && options.redis_namespace? && options.queue_pop? && options.queue_push?
      @printHelp()
      console.error chalk.red 'Missing required parameter --redis-uri, -r, or env: REDIS_URI' unless options.redis_uri?
      console.error chalk.red 'Missing required parameter --redis-namespace, -n, or env: REDIS_NAMESPACE' unless options.redis_namespace?
      console.error chalk.red 'Missing required parameter --queue-push, -p, or env: QUEUE_PUSH' unless options.queue_push?
      console.error chalk.red 'Missing required parameter --queue-pop, -q, or env: QUEUE_POP' unless options.queue_pop?
      process.exit 1

    return options

  run: =>
    @getWorkerClient (error, client) =>
      return @die error if error?
      worker = new Worker { client, queuePop: @queue_pop, queuePush: @queue_push }
      worker.run @die

      sigtermHandler = new SigtermHandler { events: ['SIGINT', 'SIGTERM']}
      sigtermHandler.register worker.stop

  getWorkerClient: (callback) =>
    @getRedisClient @redis_uri, (error, client) =>
      return callback error if error?
      clientNS  = new RedisNS @redis_namespace, client
      callback null, clientNS

  getRedisClient: (redisUri, callback) =>
    callback = _.once callback
    client = new Redis redisUri, dropBufferSupport: true
    client.once 'ready', =>
      client.on 'error', @die
      callback null, client

    client.once 'error', callback

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

module.exports = Command
