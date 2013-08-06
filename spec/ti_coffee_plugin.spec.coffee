describe "TiCoffeePlugin", ->
  TiCoffeePlugin = require "../src/plugin"

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

    it "should define a cliVersion", ->
      expect( TiCoffeePlugin.cliVersion ).toEqual jasmine.any(String)

    describe "#init", ->

      beforeEach ->
        spyOn TiCoffeePlugin::, "findCoffeeFiles"
        spyOn TiCoffeePlugin::, "loadHashes"
        TiCoffeePlugin.init(new MockLogger, {}, @cli, {})

      it "should call addHook with build.pre.compile", ->
        expect( @cli.addHook ).toHaveBeenCalledWith "build.pre.compile",
          priority: jasmine.any(Number)
          post:     jasmine.any(Function)

      it "should call addHook with build.pre.compile", ->
        expect( @cli.addHook ).toHaveBeenCalledWith "clean.post", jasmine.any(Function)

      xit "should save a hash file", ->
        expect( FS.exists(FS.getPath("build/#{TiCoffeePlugin.HASH_FILE}")) ).toBeTruthy()

  xdescribe "#constructor", ->

    beforeEach ->
      @addMatchers toIncludeHashEntry: (expected) ->
        nottext = if @isNot then " not" else ""
        @message = ->
          "Expected hash object #{@actual.toString()} to#{nottext} include '#{expected}'"
        @actual[expected]?
      FS.addFile FS.getPath("build/#{TiCoffeePlugin.HASH_FILE}", """{"test_file":"test_hash"}""")

    it "should load coffee files", ->
      spyOn TiCoffeePlugin::, "loadHashes"
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      paths = @ti_coffee_plugin.coffee_files.map (x) -> x.src_path
      expect( paths ).toContain FS.cs_file

    it "should load stored hashes", ->
      spyOn TiCoffeePlugin::, "findCoffeeFiles"
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      expect( @ti_coffee_plugin.hashes ).toIncludeHashEntry "test_file"

  describe "hooks", ->

    beforeEach ->
      @ti_coffee_plugin = new TiCoffeePlugin(new MockLogger, {}, @cli, {})
      @coffee_file = new MockCoffeeFile
      @callback_spy = createSpy "finish"
      @ti_coffee_plugin.coffee_files = [ @coffee_file ]

    describe "#compile", ->

      it "should call finish()", ->
        @ti_coffee_plugin.compile({}, @callback_spy)
        expect( @callback_spy ).toHaveBeenCalled()

      it "should call CoffeeFile.compile()", ->
        @ti_coffee_plugin.compile({}, @callback_spy)
        expect( @coffee_file.compile ).toHaveBeenCalled()

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
        runs => @ti_coffee_plugin.clean {}, @callback_spy, -> flag = true
        waitsFor (-> flag), "clean()", ASYNC_TIMEOUT
        runs => expect( FS.exists(test_file) ).toBeFalsy()

  describe "#loadHashes", ->

    it "should load the hashes from a JSON file", ->

  describe "#storeHashes", ->

    it "should save the hashes to a JSON file", ->
