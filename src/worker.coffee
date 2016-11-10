async    = require 'async'
overview = require('debug')('now-man-worker:worker:overview')

class Worker
  constructor: (options={})->
    { @client, @queuePop, @queuePush } = options
    throw new Error('Worker: requires client') unless @client?
    throw new Error('Worker: requires queuePop') unless @queuePop?
    throw new Error('Worker: requires queuePush') unless @queuePush?
    @shouldStop = false
    @lastTimestamp = null
    @isStopped = false

  doWithNextTick: (callback) =>
    # give some time for garbage collection
    process.nextTick =>
      @do (error) =>
        process.nextTick =>
          callback error

  do: (callback) =>
    @client.time (error, result) =>
      return callback error if error?
      [timestamp] = result
      overview "i am still processing (#{timestamp})" if timestamp != @lastTimestamp and parseInt(timestamp) % 10 == 0
      @lastTimestamp = timestamp
      @client.rpoplpush "#{@queuePop}:#{timestamp}", @queuePush, callback

    return # avoid returning promise

  run: (callback) =>
    async.doUntil @doWithNextTick, (=> @shouldStop), =>
      @isStopped = true
      callback null

  stop: (callback) =>
    @shouldStop = true

    timeout = setTimeout =>
      clearInterval interval
      callback new Error 'Stop Timeout Expired'
    , 5000

    interval = setInterval =>
      return unless @isStopped
      clearInterval interval
      clearTimeout timeout
      callback()
    , 250

module.exports = Worker
