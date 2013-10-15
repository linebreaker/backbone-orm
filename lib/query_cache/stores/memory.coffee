_ = require 'underscore'

module.exports = class MemoryStore
  constructor: (options={}) ->
    @cache = {}

  set: (key, value, callback) =>
    @cache[key] = value
    callback(null, value)

  get: (key, callback) =>
    callback(null, @cache[key])

  reset: (callback) =>
    @cache = {}
    callback()

  del: (key, callback) =>
    delete @cache[key]
    callback()

  keys: => _.keys(@cache)
