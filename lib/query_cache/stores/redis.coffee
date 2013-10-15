UrlUtils = require 'url'
redis = require 'redis'

module.exports = class RedisStore
  constructor: (options) ->
#    url = require('vidi-server/config/redis')[process.ENV.NODE_ENV or 'development']

    {url, port, host, password} = options
    if url
      parsed_url = UrlUtils.parse(url)
      port = parsed_url.port
      host = parsed_url.hostname
      password = parsed_url.auth.split(':')[1]

    @client = redis.createClient(port, host)
    @client.auth(password) if password

  set: (key, value, callback) =>
    @client.set(key, JSON.stringify(value), callback)

  get: (key, callback) =>
    @client.get key, (err, result) =>
      return callback(err) if err
      callback(null, JSON.parse(result))

  del: (key, callback) =>
    @client.del(key, callback)

  reset: (callback) -> callback()
