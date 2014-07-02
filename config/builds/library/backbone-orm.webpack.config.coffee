fs = require 'fs'
path = require 'path'
_ = require 'underscore'

module.exports = _.extend  _.clone(require '../../webpack/base-config.coffee'), {
  entry: './src/index.coffee'
  output:
    path: '.'
    filename: 'backbone-orm.js'
    library: 'kb'
    libraryTarget: 'umd'

  externals: [
    {jquery: {root: 'jQuery', amd: 'jquery', commonjs: 'jquery', commonjs2: 'jquery'}}
    {underscore: {root: '_', amd: 'underscore', commonjs: 'underscore', commonjs2: 'underscore'}}
    {backbone: {root: 'Backbone', amd: 'backbone', commonjs: 'backbone', commonjs2: 'backbone'}}
    {moment: 'moment'}
    {stream: 'stream'}
  ]
}

module.exports.resolve.alias =
  querystring: path.resolve('./config/node-dependencies/querystring.js')
  url: path.resolve('./config/node-dependencies/url.js')
  util: path.resolve('./config/node-dependencies/util.js')