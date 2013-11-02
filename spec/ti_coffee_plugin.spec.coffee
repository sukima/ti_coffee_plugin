describe "TiCoffeePlugin", ->
  Q = require "q"
  TiCoffeePlugin = require "../src/hooks/plugin"

  TEST_HASH_DATA      = "test_file": "test_hash"
  TEST_HASH_FILE_DATA = JSON.stringify(TEST_HASH_DATA)

  class MockCoffeeFile
    constructor: ->
      @compile = createSpy "compile"
      @clean   = createSpy "clean"
    hash:      ""
    src_path:  "tests/file.coffee"
    dest_path: "tests/file.js"

  beforeEach ->
    FS.setup()
    @cli = createSpyObj "cli", [ "addHook" ]
    @cli.argv =
      "project-dir": FS.BASE_PATH

  afterEach -> FS.tearDown()

  describe "static methods", ->

    beforeEach ->
      spyOn TiCoffeePlugin::, "findCoffeeFiles"
      spyOn(TiCoffeePlugin::, "loadHashes")

    it "should define a cliVersion", ->
      expect( TiCoffeePlugin.cliVersion ).toEqual jasmine.any(String)

    describe "#init", ->

      beforeEach ->
        TiCoffeePlugin.init(new MockLogger, {}, @cli, {})

      it "should call addHook with build.pre.compile", ->
        expect( @cli.addHook ).toHaveBeenCalledWith "build.pre.compile",
          priority: jasmine.any(Number)
          post:     jasmine.any(Function)

      it "should call addHook with build.pre.compile", ->
        expect( @cli.addHook ).toHaveBeenCalledWith "clean.post", jasmine.any(Function)

  describe "#constructor", ->

    beforeEach ->
      spyOn TiCoffeePlugin::, "loadHashes"
      FS.addFile FS.getPath("build/#{TiCoffeePlugin.HASH_FILE}", TEST_HASH_FILE_DATA)

    it "should load stored hashes", ->
      spyOn TiCoffeePlugin::, "findCoffeeFiles"
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      expect( TiCoffeePlugin::loadHashes ).toHaveBeenCalled()

    it "should find all coffee files", ->
      flag = false
      runs =>
        @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
        @promise = @ti_coffee_plugin.waitingForReady
          .fin(-> flag = true)
      waitsFor (-> flag), "waitingForReady promise to resolve", ASYNC_TIMEOUT
      runs =>
        @promise.done()
        paths = @ti_coffee_plugin.coffee_files.map (x) -> x.src_path
        expect( paths ).toContain FS.cs_file
        expect( paths ).toContain alloy_file for alloy_file in FS.alloy_files

    it "should allow missing source directories", ->
      FS.tearDown() # inefficient I know, But I need a different fixture for this test
      FS.addFile FS.cs_file, "cs_file"
      flag = false
      runs =>
        @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
        @promise = @ti_coffee_plugin.waitingForReady
          .fin(-> flag = true)
      waitsFor (-> flag), "constructor", ASYNC_TIMEOUT
      runs =>
        @promise.done()
        paths = @ti_coffee_plugin.coffee_files.map (x) -> x.src_path
        expect( paths ).toContain FS.cs_file
        expect( paths ).not.toContain alloy_file for alloy_file in FS.alloy_files

    it "should still cycle onReady events when no CS files found", ->
      no_cs_files_cli = argv: { "project-dir": "__NO_CS_FILES_PROJECT_DIR_DOES_NOT_EXIST__" }
      flag = false
      runs =>
        @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, no_cs_files_cli, {})
        @promise = @ti_coffee_plugin.waitingForReady
          .fin(-> flag = true)
      waitsFor (-> flag), "constructor", ASYNC_TIMEOUT
      runs =>
        @promise.done()
        expect( @ti_coffee_plugin.coffee_files.length ).toBe 0

  describe "hooks", ->

    beforeEach ->
      mock_coffee_file = @coffee_file = new MockCoffeeFile
      spyOn(TiCoffeePlugin::, "findCoffeeFiles").andCallFake ->
        @coffee_files = [ mock_coffee_file ]
        Q(@coffee_files)
      spyOn(TiCoffeePlugin::, "loadHashes").andReturn {}
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      @callback_spy = createSpy "finish"

    describe "#compile", ->

      beforeEach ->
        spyOn @ti_coffee_plugin, "storeHashes"

      it "should return a promise", ->
        expect( @ti_coffee_plugin.compile("foobar", @callback_spy) ).toBeAPromise()

      it "should call CoffeeFile.compile()", ->
        ready = false
        runs ->
          @promise = @ti_coffee_plugin.compile({}, @callback_spy)
            .fin(-> ready = true)
        waitsFor (-> ready), "promise to be resolved", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( @coffee_file.compile ).toHaveBeenCalled()

      it "should call finish()", ->
        ready = false
        runs ->
          @promise = @ti_coffee_plugin.compile({}, @callback_spy)
            .fin(-> ready = true)
        waitsFor (-> ready), "promise to be resolved", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( @callback_spy ).toHaveBeenCalledWith()

      it "should save a hash file", ->
        ready = false
        runs ->
          @promise = @ti_coffee_plugin.compile({}, @callback_spy)
            .fin(-> ready = true)
        waitsFor (-> ready), "promise to be resolved", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( @ti_coffee_plugin.storeHashes ).toHaveBeenCalled()

      describe "(hash logic)", ->

        beforeEach ->
          @ti_coffee_plugin.hashes = {}
          @ti_coffee_plugin.hashes[FS.cs_file] = "XXX"
          @coffee_file.hash = "XXX"
          @coffee_file.src_path = FS.cs_file
          @coffee_file.dest_path = FS.cs_output_file
          @coffee_file.compile.reset()

        it "should not compile when hashes match", ->
          FS.addFile @coffee_file.dest_path
          ready = false
          runs ->
            @promise = @ti_coffee_plugin.compile({}, @callback_spy)
              .fin(-> ready = true)
          waitsFor (-> ready), "promise to be resolved", ASYNC_TIMEOUT
          runs ->
            @promise.done()
            expect( @coffee_file.compile ).not.toHaveBeenCalled()

        it "should compile when hashes match and JS file missing", ->
          ready = false
          runs ->
            @promise = @ti_coffee_plugin.compile({}, @callback_spy)
              .fin(-> ready = true)
          waitsFor (-> ready), "promise to be resolved", ASYNC_TIMEOUT
          runs ->
            @promise.done()
            expect( @coffee_file.compile ).toHaveBeenCalled()

    describe "#clean", ->

      it "should return a promise", ->
        expect( @ti_coffee_plugin.clean({}, @callback_spy) ).toBeAPromise()

      it "should call finish()", ->
        ready = false
        runs ->
          @promise = @ti_coffee_plugin.clean({}, @callback_spy)
            .fin(-> ready = true)
        waitsFor (-> ready), "promise to be resolved", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( @callback_spy ).toHaveBeenCalledWith()

      it "should call CoffeeFile.clean()", ->
        ready = false
        runs ->
          @promise = @ti_coffee_plugin.clean({}, @callback_spy)
            .fin(-> ready = true)
        waitsFor (-> ready), "promise to be resolved", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( @coffee_file.clean ).toHaveBeenCalled()

      it "should remove hash file", ->
        ready = false
        test_file = @ti_coffee_plugin.hash_file_path
        FS.addFile test_file, "{}"
        runs ->
          @promise = @ti_coffee_plugin.clean({}, @callback_spy)
            .fin(-> ready = true)
        waitsFor (-> ready), "promise to be resolved", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( FS.exists(test_file) ).toBeFalsy()

  describe "helper methods", ->

    beforeEach ->
      spyOn(TiCoffeePlugin::, "findCoffeeFiles").andReturn Q.resolve()
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})

    describe "#loadHashes", ->

      it "should load the hashes from a JSON file", ->
        ready = false
        runs ->
          @promise = @ti_coffee_plugin.waitingForReady
            .fin(-> ready = true)
          FS.addFile @ti_coffee_plugin.hash_file_path, TEST_HASH_FILE_DATA
        waitsFor (-> ready), "waitingForReady to resolve", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          @ti_coffee_plugin.loadHashes()
          expect( @ti_coffee_plugin.hashes ).toEqual TEST_HASH_DATA

    describe "#storeHashes", ->

      it "should return a promise", ->
        expect( @ti_coffee_plugin.storeHashes() ).toBeAPromise()

      it "should save the hashes to a JSON file", ->
        ready = false
        runs =>
          @ti_coffee_plugin.waitingForReady.fin =>
            @ti_coffee_plugin.hashes = TEST_HASH_DATA
            @ti_coffee_plugin.coffee_files = [ @coffee_file ]
            @promise = @ti_coffee_plugin.storeHashes()
              .fin(-> ready = true)
          @ti_coffee_plugin.waitingForReady.done()
          expect( FS.exists(@ti_coffee_plugin.hash_file_path) ).toBeFalsy()
        waitsFor (-> ready), "waitingForReady and storeHashes promises to resolve", ASYNC_TIMEOUT
        runs =>
          @promise.done()
          expect( FS.exists(@ti_coffee_plugin.hash_file_path) ).toBeTruthy()
