{expect}       = require "chai"
sinon          = require "sinon"
Q              = require "q"
FS             = require "./support/file_system_helper"
MockLogger     = require "./support/mock_logger"
TiCoffeePlugin = require "../src/hooks/plugin"

describe "TiCoffeePlugin", ->
  @timeout(300)
  sandbox = sinon.sandbox.create()

  TEST_HASH_DATA      = "test_file": "test_hash"
  TEST_HASH_FILE_DATA = JSON.stringify(TEST_HASH_DATA)

  class MockCoffeeFile
    constructor: ->
      @compile = sandbox.spy()
      @clean   = sandbox.spy()
    hash:      ""
    src_path:  "tests/file.coffee"
    dest_path: "tests/file.js"

  beforeEach ->
    FS.setup()
    @cli = sandbox.stub
      addHook: ->
      argv:
        "project-dir": FS.BASE_PATH

  afterEach ->
    FS.tearDown()
    sandbox.restore()

  describe "static methods", ->

    beforeEach ->
      sandbox.stub TiCoffeePlugin::, "findCoffeeFiles"
      sandbox.stub TiCoffeePlugin::, "loadHashes"

    it "defines a cliVersion", ->
      expect( TiCoffeePlugin.cliVersion ).to.be.a "string"

    describe "#init", ->

      beforeEach ->
        TiCoffeePlugin.init(new MockLogger, {}, @cli, {})

      it "should call addHook with build.pre.compile", ->
        sinon.assert.calledWith @cli.addHook, "build.pre.compile",
          priority: sinon.match.number
          post:     sinon.match.func

      it "should call addHook with clean.post", ->
        sinon.assert.calledWith @cli.addHook, "clean.post", sinon.match.func

  describe "#constructor", ->

    beforeEach ->
      sandbox.stub TiCoffeePlugin::, "loadHashes"
      FS.addFile FS.getPath("build/#{TiCoffeePlugin.HASH_FILE}", TEST_HASH_FILE_DATA)

    it "should load stored hashes", ->
      sandbox.stub TiCoffeePlugin::, "findCoffeeFiles"
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      sinon.assert.called TiCoffeePlugin::loadHashes

    it "should find all coffee files", (done) ->
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      @promise = @ti_coffee_plugin.waitingForReady
      @promise.then =>
        @ti_coffee_plugin.coffee_files.map (x) -> x.src_path
      .then (paths) =>
        expect( paths ).to.contain FS.cs_file
        expect( paths ).to.contain alloy_file for alloy_file in FS.alloy_files
        done()
      .fail(done)

    it "should allow missing source directories", (done) ->
      FS.tearDown() # inefficient I know, But I need a different fixture for this test
      FS.addFile FS.cs_file, "cs_file"
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      @promise = @ti_coffee_plugin.waitingForReady
      @promise.then =>
        @ti_coffee_plugin.coffee_files.map (x) -> x.src_path
      .then (paths) =>
        expect( paths ).to.contain FS.cs_file
        expect( paths ).not.to.contain alloy_file for alloy_file in FS.alloy_files
        done()
      .fail(done)

    it "should still cycle onReady events when no CS files found", (done) ->
      no_cs_files_cli = argv: { "project-dir": "__NO_CS_FILES_PROJECT_DIR_DOES_NOT_EXIST__" }
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, no_cs_files_cli, {})
      @promise = @ti_coffee_plugin.waitingForReady
      @promise.then =>
        expect( @ti_coffee_plugin.coffee_files.length ).to.equal 0
        done()
      .fail(done)

  describe "hooks", ->

    beforeEach ->
      mock_coffee_file = @coffee_file = new MockCoffeeFile
      sandbox.stub TiCoffeePlugin::, "findCoffeeFiles", ->
        @coffee_files = [ mock_coffee_file ]
        Q(@coffee_files)
      sandbox.stub(TiCoffeePlugin::, "loadHashes").returns {}
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      @callback_spy = sandbox.spy()

    describe "#compile", ->

      beforeEach ->
        sandbox.stub @ti_coffee_plugin, "storeHashes"
        @promise = @ti_coffee_plugin.compile({}, @callback_spy)

      it "should call CoffeeFile.compile()", (done) ->
        @promise.then =>
          sinon.assert.called @coffee_file.compile
          done()
        .fail(done)

      it "should call finish()", (done) ->
        @promise.then =>
          sinon.assert.calledWith @callback_spy
          done()
        .fail(done)

      it "should save a hash file", (done) ->
        @promise.then =>
          sinon.assert.called @ti_coffee_plugin.storeHashes
          done()
        .fail(done)

      describe "(hash logic)", ->

        beforeEach ->
          @ti_coffee_plugin.hashes             = {}
          @ti_coffee_plugin.hashes[FS.cs_file] = "XXX"
          @coffee_file.hash                    = "XXX"
          @coffee_file.src_path                = FS.cs_file
          @coffee_file.dest_path               = FS.cs_output_file

        it "should not compile when hashes match", (done) ->
          FS.addFile @coffee_file.dest_path
          @promise = @ti_coffee_plugin.compile({}, @callback_spy)
          @promise.then =>
            # TODO: Why is compile called once? Is this a bug?
            sinon.assert.calledOnce @coffee_file.compile
            done()
          .fail(done)

        it "should compile when hashes match and JS file missing", (done) ->
          @promise = @ti_coffee_plugin.compile({}, @callback_spy)
          @promise.then =>
            sinon.assert.called @coffee_file.compile
            done()
          .fail(done)

    describe "#clean", ->

      it "should call finish()", (done) ->
        @promise = @ti_coffee_plugin.clean({}, @callback_spy)
        @promise.then =>
          sinon.assert.called @callback_spy
          done()
        .fail(done)

      it "should call CoffeeFile.clean()", (done) ->
        @promise = @ti_coffee_plugin.clean({}, @callback_spy)
        @promise.then =>
          sinon.assert.called @coffee_file.clean
          done()
        .fail(done)

      it "should remove hash file", (done) ->
        test_file = @ti_coffee_plugin.hash_file_path
        FS.addFile test_file, "{}"
        @promise = @ti_coffee_plugin.clean({}, @callback_spy)

        @promise.then =>
          expect( FS.exists(test_file) ).to.be.false
          done()
        .fail(done)

  describe "helper methods", ->

    beforeEach ->
      sandbox.stub TiCoffeePlugin::, "findCoffeeFiles", -> Q.resolve()
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})

    describe "#loadHashes", ->

      it "should load the hashes from a JSON file", (done) ->
        FS.addFile @ti_coffee_plugin.hash_file_path, TEST_HASH_FILE_DATA
        @promise = @ti_coffee_plugin.waitingForReady
        @promise.then =>
          @ti_coffee_plugin.loadHashes()
        .then =>
          expect( @ti_coffee_plugin.hashes ).to.deep.equal TEST_HASH_DATA
          done()
        .fail(done)

    describe "#storeHashes", ->

      it "should save the hashes to a JSON file", (done) ->
        @promise = @ti_coffee_plugin.waitingForReady
        @promise.then =>
          expect( FS.exists(@ti_coffee_plugin.hash_file_path) ).to.be.false

          @ti_coffee_plugin.hashes = TEST_HASH_DATA
          @ti_coffee_plugin.coffee_files = [ @coffee_file ]

          @ti_coffee_plugin.storeHashes()
        .then =>
          expect( FS.exists(@ti_coffee_plugin.hash_file_path) ).to.be.true
          done()
        .fail(done)
