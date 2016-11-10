Worker  = require '../src/worker'
Redis   = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
async = require 'async'

describe 'Worker', ->
  beforeEach (done) ->
    client = new Redis 'localhost', dropBufferSupport: true
    client.on 'ready', =>
      @client = new RedisNS 'test-worker', client
      done()

  beforeEach ->
    queuePop = 'work'
    queuePush = 'maybe-later'
    @sut = new Worker { @client, queuePop, queuePush }

  describe '->do', ->
    beforeEach (done) ->
      @client.time (error, time) =>
        @data = JSON.stringify {foo: 'bar', time}
        @client.lpush "work:#{time[0]/1+1}", @data, done
      return # stupid promises

    beforeEach (done) ->
      testResult = (callback) =>
        @client.rpop "maybe-later", (error, @result) =>
          return callback error, !@result?
      async.during testResult, @sut.do, done

    it 'should move some things around maybe', ->
      expect(@data).to.deep.equal @result
