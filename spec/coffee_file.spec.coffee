describe "CoffeeFile", ->
  path         = require "path"
  {CoffeeFile} = require "../src/plugin"

  describe "#constructor", ->

    it "should assign a proper dest_path", ->
      spyOn CoffeeFile::, "createHash"
      expect( new CoffeeFile("src/test.coffee").dest_path ).toBe "Resources/test.js"
      expect( new CoffeeFile("src/test.coffee.md").dest_path ).toBe "Resources/test.js"
      expect( new CoffeeFile("src/test.litcoffee").dest_path ).toBe "Resources/test.js"
      expect( new CoffeeFile("tests/src/test.coffee").dest_path ).toBe "tests/Resources/test.js"
      expect( new CoffeeFile("tests/src/test/test.coffee").dest_path ).toBe "tests/Resources/test/test.js"

    it "should assign a proper dest_dir", ->
      spyOn CoffeeFile::, "createHash"
      expect( new CoffeeFile("src/test.coffee").dest_dir ).toBe "Resources"
      expect( new CoffeeFile("src/test.coffee.md").dest_dir ).toBe "Resources"
      expect( new CoffeeFile("src/test.litcoffee").dest_dir ).toBe "Resources"
      expect( new CoffeeFile("tests/src/test.coffee").dest_dir ).toBe "tests/Resources"
      expect( new CoffeeFile("tests/src/test/test.coffee").dest_dir ).toBe "tests/Resources/test"

    it "should assign a hash", ->
      flag = false
      coffee_file = new CoffeeFile("src/plugin.coffee.md")
      runs => coffee_file.onReady -> flag = true
      waitsFor (-> flag), "onReady", ASYNC_TIMEOUT
      runs =>
        expect( coffee_file.hash ).toEqual jasmine.any(String)
        expect( coffee_file.hash.length ).not.toBe 0

  describe "file system methods", ->

    beforeEach ->
      FS.setup()
      @coffee_file = new CoffeeFile(FS.cs_file)
      @temp_file = FS.getPath("__test_coffee_path__")

    afterEach ->
      FS.tearDown()
    
    describe "#compile", ->

      it "should create 'Resource' sub-trees", ->
        flag = false
        runs => @coffee_file.compile new MockLogger, -> flag = true
        waitsFor (-> flag), "compile()", ASYNC_TIMEOUT
        runs => expect( FS.exists(@coffee_file.dest_path) ).toBeTruthy()

      it "should allow environmental override for coffee command", ->
        flag = false
        process.env["COFFEE_PATH"] = "touch #{@temp_file} #"
        runs => @coffee_file.compile new MockLogger, -> flag = true
        waitsFor (-> flag), "compile()", ASYNC_TIMEOUT
        runs => expect( FS.exists(@temp_file) ).toBeTruthy()

    describe "#clean", ->

      beforeEach ->
        FS.addFile @coffee_file.dest_path

      it "should clean up generated js files", ->
        flag = false
        runs => @coffee_file.clean new MockLogger, -> flag = true
        waitsFor (-> flag), "clean()", ASYNC_TIMEOUT
        runs => expect( FS.exists(@coffee_file.dest_path) ).toBeFalsy()

      it "should remove directory if empty", ->
        flag = false
        runs => @coffee_file.clean new MockLogger, -> flag = true
        waitsFor (-> flag), "clean()", ASYNC_TIMEOUT
        runs => expect( FS.exists(path.dirname(@coffee_file.dest_path)) ).toBeFalsy()
