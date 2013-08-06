describe "TiCoffeePlugin", ->
  TiCoffeePlugin = require "../src/hooks/plugin"

  TEST_HASH_DATA      = "test_file": "test_hash"
  TEST_HASH_FILE_DATA = JSON.stringify(TEST_HASH_DATA)

  class MockCoffeeFile
    hash:      ""
    src_path:  "test/file.coffee"
    dest_path: "test/file.js"
    compile:   createSpy "compile"
    clean:     createSpy "clean"

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
        @ti_coffee_plugin.onReady(-> flag = true)
      waitsFor (-> flag), "constructor", ASYNC_TIMEOUT
      runs =>
        paths = @ti_coffee_plugin.coffee_files.map (x) -> x.src_path
        expect( paths ).toContain FS.cs_file

    it "should still cycle onReady events when no CS files found", ->
      no_cs_files_cli = argv: { "project-dir": "__NO_CS_FILES_PROJECT_DIR_DOES_NOT_EXIST__" }
      flag = false
      runs =>
        @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, no_cs_files_cli, {})
        @ti_coffee_plugin.onReady(-> flag = true)
      waitsFor (-> flag), "constructor", ASYNC_TIMEOUT
      runs =>
        expect( @ti_coffee_plugin.coffee_files.length ).toBe 0

  describe "hooks", ->

    beforeEach ->
      spyOn TiCoffeePlugin::, "findCoffeeFiles"
      spyOn(TiCoffeePlugin::, "loadHashes")
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      @coffee_file = new MockCoffeeFile
      @callback_spy = createSpy "finish"
      @ti_coffee_plugin.coffee_files = [ @coffee_file ]
      @ti_coffee_plugin.waitingForFindCoffeeFiles = false


    describe "#compile", ->

      it "should call finish()", ->
        @ti_coffee_plugin.compile({}, @callback_spy)
        expect( @callback_spy ).toHaveBeenCalled()

      it "should call CoffeeFile.compile()", ->
        @ti_coffee_plugin.compile({}, @callback_spy)
        expect( @coffee_file.compile ).toHaveBeenCalled()

      it "should save a hash file", ->
        spyOn @ti_coffee_plugin, "storeHashes"
        @ti_coffee_plugin.compile({}, @callback_spy)
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
          @ti_coffee_plugin.compile({}, @callback_spy)
          expect( @coffee_file.compile ).not.toHaveBeenCalled()

        it "should compile when hashes match and JS file missing", ->
          @ti_coffee_plugin.compile({}, @callback_spy)
          expect( @coffee_file.compile ).toHaveBeenCalled()

    describe "#clean", ->

      it "should call finish()", ->
        @ti_coffee_plugin.clean({}, @callback_spy)
        expect( @callback_spy ).toHaveBeenCalled()

      it "should call CoffeeFile.clean()", ->
        @ti_coffee_plugin.coffee_files = [ @coffee_file ]
        @ti_coffee_plugin.clean({}, @callback_spy)
        expect( @coffee_file.clean ).toHaveBeenCalled()

      it "should remove hash file", ->
        flag = false
        test_file = @ti_coffee_plugin.hash_file_path
        FS.addFile test_file, "{}"
        runs => @ti_coffee_plugin.clean {}, @callback_spy, (-> flag = true)
        waitsFor (-> flag), "clean()", ASYNC_TIMEOUT
        runs => expect( FS.exists(test_file) ).toBeFalsy()

  describe "helper methods", ->

    describe "#loadHashes", ->

      it "should load the hashes from a JSON file", ->
        spyOn TiCoffeePlugin::, "findCoffeeFiles"
        @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
        FS.addFile @ti_coffee_plugin.hash_file_path, TEST_HASH_FILE_DATA
        @ti_coffee_plugin.loadHashes()
        expect( @ti_coffee_plugin.hashes ).toEqual TEST_HASH_DATA

    describe "#storeHashes", ->

      it "should save the hashes to a JSON file", ->
        spyOn TiCoffeePlugin::, "findCoffeeFiles"
        flag = false
        runs =>
          @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
          @ti_coffee_plugin.waitingForFindCoffeeFiles = false
          @ti_coffee_plugin.onReady =>
            @ti_coffee_plugin.hashes = TEST_HASH_DATA
            @ti_coffee_plugin.coffee_files = [ @coffee_file ]
            @ti_coffee_plugin.storeHashes(-> flag = true)
        waitsFor (-> flag), "storeHashes()", ASYNC_TIMEOUT
        runs => expect( FS.exists(@ti_coffee_plugin.hash_file_path) ).toBeTruthy()
