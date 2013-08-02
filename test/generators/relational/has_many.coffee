util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'queue-async'

Fabricator = require '../../../fabricator'
Utils = require '../../../lib/utils'
JSONUtils = require '../../../lib/json_utils'

runTests = (options, cache, embed) ->
  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync
  BASE_COUNT = 1

  class Flat extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/flats"
    @schema: BASE_SCHEMA
    sync: SYNC(Flat, cache)

  class Reverse extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/reverses"
    @schema: _.defaults({
      owner: -> ['belongsTo', Owner]
      owner_as: -> ['belongsTo', Owner, as: 'reverses_as']
    }, BASE_SCHEMA)
    sync: SYNC(Reverse, cache)

  class Owner extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/owners"
    @schema: _.defaults({
      flats: -> ['hasMany', Flat]
      reverses: -> ['hasMany', Reverse]
      reverses_as: -> ['hasMany', Reverse, as: 'owner_as', ids_accessor: 'reverses_as_ids']
    }, BASE_SCHEMA)
    sync: SYNC(Owner, cache)

  describe "hasMany (cache: #{cache} embed: #{embed})", ->

    beforeEach (done) ->
      MODELS = {}

      queue = new Queue(1)

      # destroy all
      queue.defer (callback) ->
        destroy_queue = new Queue()

        destroy_queue.defer (callback) -> Flat.resetSchema(callback)
        destroy_queue.defer (callback) -> Reverse.resetSchema(callback)
        destroy_queue.defer (callback) -> Owner.resetSchema(callback)

        destroy_queue.await callback

      # create all
      queue.defer (callback) ->
        create_queue = new Queue()

        create_queue.defer (callback) -> Fabricator.create(Flat, 2*BASE_COUNT, {
          name: Fabricator.uniqueId('flat_')
          created_at: Fabricator.date
        }, (err, models) -> MODELS.flat = models; callback(err))
        create_queue.defer (callback) -> Fabricator.create(Reverse, 2*BASE_COUNT, {
          name: Fabricator.uniqueId('reverse_')
          created_at: Fabricator.date
        }, (err, models) -> MODELS.reverse = models; callback(err))
        create_queue.defer (callback) -> Fabricator.create(Owner, BASE_COUNT, {
          name: Fabricator.uniqueId('owner_')
          created_at: Fabricator.date
        }, (err, models) -> MODELS.owner = models; callback(err))

        create_queue.await callback

      # link and save all
      queue.defer (callback) ->
        save_queue = new Queue()

        for owner, index in MODELS.owner
          do (owner, index) ->
            owner.set({
              flats: [MODELS.flat.pop(), MODELS.flat.pop()]
              reverses: [MODELS.reverse[index], MODELS.reverse[index+1]]
              reverses_as: [MODELS.reverse[index+1], MODELS.reverse[index]]
            })
            save_queue.defer (callback) -> owner.save {}, Utils.bbCallback callback

        save_queue.await callback

      queue.await done

    it 'Handles a get query for a hasMany relation', (done) ->
      Owner.findOne (err, test_model) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(test_model, 'found model')

        test_model.get 'flats', (err, flats) ->
          assert.ok(!err, "No errors: #{err}")
          assert.equal(2, flats.length, "Expected: #{2}. Actual: #{flats.length}")
          if test_model.relationIsEmbedded('flats')
            assert.deepEqual(test_model.toJSON().flats[0], flats[0].toJSON(), "Serialized embedded. Expected: #{test_model.toJSON().flats[0]}. Actual: #{flats[0].toJSON()}")
          done()

    it 'Handles an async get query for ids', (done) ->
      Owner.findOne (err, test_model) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(test_model, 'found model')

        test_model.get 'flat_ids', (err, ids) ->
          assert.ok(!err, "No errors: #{err}")
          assert.equal(2, ids.length, "Expected count: #{2}. Actual: #{ids.length}")
          done()

    it 'Handles a synchronous get query for ids after the relations are loaded', (done) ->
      Owner.findOne (err, test_model) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(test_model, 'found model')

        test_model.get 'flats', (err, flats) ->
          assert.ok(!err, "No errors: #{err}")
          assert.equal(test_model.get('flat_ids').length, flats.length, "Expected count: #{test_model.get('flat_ids').length}. Actual: #{flats.length}")
          assert.deepEqual(test_model.get('flat_ids')[0], flats[0].id, "Serialized id only. Expected: #{test_model.get('flat_ids')[0]}. Actual: #{flats[0].id}")
          done()

    it 'Handles a get query for a hasMany and belongsTo two sided relation', (done) ->
      Owner.findOne (err, test_model) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(test_model, 'found model')

        test_model.get 'reverses', (err, reverses) ->
          assert.ok(!err, "No errors: #{err}")
          assert.ok(reverses, 'found models')
          assert.equal(2, reverses.length, "Expected: #{2}. Actual: #{reverses.length}")

          if test_model.relationIsEmbedded('reverses')
            assert.deepEqual(test_model.toJSON().reverses[0], reverses[0].toJSON(), 'Serialized embedded')
          assert.deepEqual(test_model.get('reverse_ids')[0], reverses[0].id, 'serialized id only')
          reverse = reverses[0]

          reverse.get 'owner', (err, owner) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(owner, 'found owner models')
            if reverse.relationIsEmbedded('owner')
              assert.deepEqual(reverse.toJSON().owner_id, owner.id, "Serialized embedded. Expected: #{util.inspect(reverse.toJSON().owner_id)}. Actual: #{util.inspect(owner.id)}")
            assert.deepEqual(reverse.get('owner_id'), owner.id, "Serialized id only. Expected: #{reverse.get('owner_id')}. Actual: #{owner.id}")

            if Owner.cache()
              assert.deepEqual(JSON.stringify(test_model.toJSON()), JSON.stringify(owner.toJSON()), "\nExpected: #{util.inspect(test_model.toJSON())}\nActual: #{util.inspect(test_model.toJSON())}")
            else
              assert.equal(test_model.id, owner.id, "\nExpected: #{test_model.id}\nActual: #{owner.id}")
            done()

    it 'Appends json for a related model', (done) ->
      Owner.findOne (err, test_model) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(test_model, 'found model')

        JSONUtils.renderRelated test_model, 'reverses', ['id', 'created_at'], (err, related_json) ->
          assert.ok(!err, "No errors: #{err}")
          assert.ok(related_json.length, "json has a list of reverses")
          assert.equal(2, related_json.length, "Expected: #{2}. Actual: #{related_json.length}")
          for reverse in related_json
            assert.ok(reverse.id, "reverse has an id")
            assert.ok(reverse.created_at, "reverse has a created_at")
            assert.ok(!reverse.updated_at, "reverse doesn't have updated_at")
          done()

    it 'Handles a get query for a hasMany and belongsTo two sided relation as "as" fields', (done) ->
      Owner.findOne (err, test_model) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(test_model, 'found model')

        test_model.get 'reverses_as', (err, reverses) ->
          assert.ok(!err, "No errors: #{err}")
          assert.ok(reverses, 'found models')
          assert.equal(2, reverses.length, "Expected: #{2}. Actual: #{reverses.length}")

          if test_model.relationIsEmbedded('reverses_as')
            assert.deepEqual(test_model.toJSON().reverses[0], reverses[0].toJSON(), 'Serialized embedded')
          assert.deepEqual(test_model.get('reverses_as_ids')[0], reverses[0].id, 'serialized id only')
          reverse = reverses[0]

          reverse.get 'owner_as', (err, owner) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(owner, 'found owner models')
            if reverse.relationIsEmbedded('owner')
              assert.deepEqual(reverse.toJSON().owner_as_id, owner.id, "Serialized embedded. Expected: #{util.inspect(reverse.toJSON().owner_as_id)}. Actual: #{util.inspect(owner.id)}")
            assert.deepEqual(reverse.get('owner_as_id'), owner.id, "Serialized id only. Expected: #{reverse.get('owner_as_id')}. Actual: #{owner.id}")

            if Owner.cache()
              assert.deepEqual(JSON.stringify(test_model.toJSON()), JSON.stringify(owner.toJSON()), "\nExpected: #{util.inspect(test_model.toJSON())}\nActual: #{util.inspect(test_model.toJSON())}")
            else
              assert.equal(test_model.id, owner.id, "\nExpected: #{test_model.id}\nActual: #{owner.id}")
            done()

    it 'Can include related (one-way hasMany) models', (done) ->
      Owner.cursor({$one: true}).include('flats').toJSON (err, test_model) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(test_model, 'found model')
        assert.ok(test_model.flats, 'Has related flats')
        assert.equal(test_model.flats.length, 2*BASE_COUNT, "Has the correct number of related flats \nExpected: #{2*BASE_COUNT}\nActual: #{test_model.flats.length}")
        done()

    it 'Can include multiple related (one-way hasMany) models', (done) ->
      Owner.cursor({$one: true}).include('flats', 'reverses').toJSON (err, test_model) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(test_model, 'found model')

        assert.ok(test_model.flats, 'Has related flats')
        assert.ok(test_model.reverses, 'Has related reverses')
        assert.equal(test_model.flats.length, 2*BASE_COUNT, "Has the correct number of related flats \nExpected: #{2*BASE_COUNT}\nActual: #{test_model.flats.length}")
        assert.equal(test_model.reverses.length, 2*BASE_COUNT, "Has the correct number of related reverses \nExpected: #{test_model.reverses.length}\nActual: #{test_model.reverses.length}")

        for flat in test_model.flats
          assert.equal(test_model.id, flat.owner_id, "\nExpected: #{test_model.id}\nActual: #{flat.owner_id}")
        for reverse in test_model.reverses
          assert.equal(test_model.id, reverse.owner_id, "\nExpected: #{test_model.id}\nActual: #{reverse.owner_id}")
        done()

    it 'Can query on related (one-way hasMany) models', (done) ->
      Reverse.findOne (err, reverse) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(reverse, 'found model')
        Owner.cursor({'reverses.name': reverse.get('name')}).toJSON (err, json) ->
          test_model = json[0]
          assert.ok(!err, "No errors: #{err}")
          assert.ok(test_model, 'found model')

          assert.equal(test_model.id, reverse.get('owner_id'), "\nExpected: #{test_model.id}\nActual: #{reverse.get('owner_id')}")
          done()

    it 'Can query on related (one-way hasMany) models with included relations', (done) ->
      Reverse.findOne (err, reverse) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(reverse, 'found model')

        Owner.cursor({'reverses.name': reverse.get('name')}).include('flats', 'reverses').toJSON (err, json) ->
          test_model = json[0]
          assert.ok(!err, "No errors: #{err}")
          assert.ok(test_model, 'found model')

          assert.ok(test_model.flats, 'Has related flats')
          assert.ok(test_model.reverses, 'Has related reverses')

          assert.equal(test_model.flats.length, 2*BASE_COUNT, "Has the correct number of related flats \nExpected: #{2*BASE_COUNT}\nActual: #{test_model.flats.length}")
          assert.equal(test_model.reverses.length, 2, "Has the correct number of related reverses \nExpected: #{2}\nActual: #{test_model.reverses.length}")

          for flat in test_model.flats
            assert.equal(test_model.id, flat.owner_id, "\nExpected: #{test_model.id}\nActual: #{flat.owner_id}")
          for reverse in test_model.reverses
            assert.equal(test_model.id, reverse.owner_id, "\nExpected: #{test_model.id}\nActual: #{reverse.owner_id}")
          done()

# TODO: explain required set up

# each model should have available attribute 'id', 'name', 'created_at', 'updated_at', etc....
# beforeEach should return the models_json for the current run
module.exports = (options) ->
  runTests(options, false, false)
  runTests(options, true, false)
  runTests(options, false, true) if options.embed
  runTests(options, true, true) if options.embed
