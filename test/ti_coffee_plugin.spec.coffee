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

    it "should find all coffee files", (mochaDone) ->
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      @promise = @ti_coffee_plugin.waitingForReady
      @promise.done =>
        try
          paths = @ti_coffee_plugin.coffee_files.map (x) -> x.src_path
          expect( paths ).to.contain FS.cs_file
          expect( paths ).to.contain alloy_file for alloy_file in FS.alloy_files
          mochaDone()
        catch err
          mochaDone err

    it "should allow missing source directories", (mochaDone) ->
      FS.tearDown() # inefficient I know, But I need a different fixture for this test
      FS.addFile FS.cs_file, "cs_file"
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      @promise = @ti_coffee_plugin.waitingForReady
      @promise.done =>
        try
          paths = @ti_coffee_plugin.coffee_files.map (x) -> x.src_path
          expect( paths ).to.contain FS.cs_file
          expect( paths ).not.to.contain alloy_file for alloy_file in FS.alloy_files
          mochaDone()
        catch err
          mochaDone err

    it "should still cycle onReady events when no CS files found", (mochaDone) ->
      no_cs_files_cli = argv: { "project-dir": "__NO_CS_FILES_PROJECT_DIR_DOES_NOT_EXIST__" }
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, no_cs_files_cli, {})
      @promise = @ti_coffee_plugin.waitingForReady
      @promise.done =>
        try
          expect( @ti_coffee_plugin.coffee_files.length ).to.equal 0
          mochaDone()
        catch err
          mochaDone err

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

      it "should call CoffeeFile.compile()", (mochaDone) ->
        @promise.done =>
          try
            sinon.assert.called @coffee_file.compile
            mochaDone()
          catch err
            mochaDone err

      it "should call finish()", (mochaDone) ->
        @promise.done =>
          try
            sinon.assert.calledWith @callback_spy
            mochaDone()
          catch err
            mochaDone err

      it "should save a hash file", (mochaDone) ->
        @promise.done =>
          try
            sinon.assert.called @ti_coffee_plugin.storeHashes
            mochaDone()
          catch err
            mochaDone err

      describe "(hash logic)", ->

        beforeEach ->
          @ti_coffee_plugin.hashes             = {}
          @ti_coffee_plugin.hashes[FS.cs_file] = "XXX"
          @coffee_file.hash                    = "XXX"
          @coffee_file.src_path                = FS.cs_file
          @coffee_file.dest_path               = FS.cs_output_file

        it "should not compile when hashes match", (mochaDone) ->
          FS.addFile @coffee_file.dest_path
          @promise = @ti_coffee_plugin.compile({}, @callback_spy)
          @promise.done =>
            try
              # TODO: Why is compile called once? Is this a bug?
              sinon.assert.calledOnce @coffee_file.compile
              mochaDone()
            catch err
              mochaDone err

        it "should compile when hashes match and JS file missing", (mochaDone) ->
          @promise = @ti_coffee_plugin.compile({}, @callback_spy)
          @promise.done =>
            try
              sinon.assert.called @coffee_file.compile
              mochaDone()
            catch err
              mochaDone err

    describe "#clean", ->

      it "should call finish()", (mochaDone) ->
        @promise = @ti_coffee_plugin.clean({}, @callback_spy)
        @promise.done =>
          try
            sinon.assert.called @callback_spy
            mochaDone()
          catch err
            mochaDone err

      it "should call CoffeeFile.clean()", (mochaDone) ->
        @promise = @ti_coffee_plugin.clean({}, @callback_spy)
        @promise.done =>
          try
            sinon.assert.called @coffee_file.clean
            mochaDone()
          catch err
            mochaDone err

      it "should remove hash file", (mochaDone) ->
        test_file = @ti_coffee_plugin.hash_file_path
        FS.addFile test_file, "{}"
        @promise = @ti_coffee_plugin.clean({}, @callback_spy)

        @promise.done =>
          try
            expect( FS.exists(test_file) ).to.be.false
            mochaDone()
          catch err
            mochaDone err

  describe "helper methods", ->

    beforeEach ->
      sandbox.stub TiCoffeePlugin::, "findCoffeeFiles", -> Q.resolve()
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})

    describe "#loadHashes", ->

      it "should load the hashes from a JSON file", (mochaDone) ->
        FS.addFile @ti_coffee_plugin.hash_file_path, TEST_HASH_FILE_DATA
        @promise = @ti_coffee_plugin.waitingForReady
        @promise.then =>
          @ti_coffee_plugin.loadHashes()
        .then =>
          expect( @ti_coffee_plugin.hashes ).to.deep.equal TEST_HASH_DATA
          mochaDone()
        .fail(mochaDone)

    describe "#storeHashes", ->

      it "should save the hashes to a JSON file", (mochaDone) ->
        @promise = @ti_coffee_plugin.waitingForReady
        @promise.then =>
          expect( FS.exists(@ti_coffee_plugin.hash_file_path) ).to.be.false

          @ti_coffee_plugin.hashes = TEST_HASH_DATA
          @ti_coffee_plugin.coffee_files = [ @coffee_file ]

          @ti_coffee_plugin.storeHashes()
        .then =>
          expect( FS.exists(@ti_coffee_plugin.hash_file_path) ).to.be.true
          mochaDone()
        .fail(mochaDone)
