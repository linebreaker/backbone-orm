module.exports =

  license: """
    /*
      backbone-orm.js 0.0.1
      Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-orm
      License: MIT (http://www.opensource.org/licenses/mit-license.php)
      Dependencies: Backbone.js and Underscore.js.
    */
    """

  start: """
    (function() {
    """

  end: """
    if (typeof exports == 'object') {
      module.exports = require('backbone-orm/lib/index');
    } else if (typeof define == 'function' && define.amd) {
      define('backbone-orm', ['underscore', 'backbone', 'moment', 'inflection'], function(){ return require('backbone-orm/lib/index'); });
    } else {
      var Backbone = this.Backbone;
      if (!Backbone && (typeof require == 'function')) {
        try { Backbone = require('backbone'); } catch (_error) { Backbone = this.Backbone = {}; }
      }
      Backbone.ORM = require('backbone-orm/lib/index');
    }
    }).call(this);
    """