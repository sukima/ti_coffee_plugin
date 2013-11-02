describe "CoffeeFile", ->
  Q            = require "q"
  path         = require "path"
  {CoffeeFile} = require "../src/hooks/plugin"

  beforeEach -> FS.setup()

  afterEach -> FS.tearDown()

  describe "#constructor", ->

    describe "path converting", ->

      beforeEach ->
        spyOn CoffeeFile::, "findHash"

      it "should convert CoffeeScript extention to JavaScript extention", ->
        expect( new CoffeeFile("src/test.coffee").dest_path ).toMatch /\.js$/
        expect( new CoffeeFile("src/test.coffee.md").dest_path ).toMatch /\.js$/
        expect( new CoffeeFile("src/test.litcoffee").dest_path ).toMatch /\.js$/

      describe "for basic app", ->

        it "should assign a proper dest_path", ->
          expect( new CoffeeFile("src/test.coffee").dest_path ).toBe "Resources/test.js"
          expect( new CoffeeFile("src/test/test.coffee").dest_path ).toBe "Resources/test/test.js"
          expect( new CoffeeFile("prefix/src/test.coffee").dest_path ).toBe "prefix/Resources/test.js"
          expect( new CoffeeFile("prefix/src/test/test.coffee").dest_path ).toBe "prefix/Resources/test/test.js"
          expect( new CoffeeFile("prefix/test/test.coffee").dest_path ).toBe "prefix/test/test.js"

        it "should assign a proper dest_dir", ->
          expect( new CoffeeFile("src/test.coffee").dest_dir ).toBe "Resources"
          expect( new CoffeeFile("src/test/test.coffee").dest_dir ).toBe "Resources/test"
          expect( new CoffeeFile("prefix/src/test.coffee").dest_dir ).toBe "prefix/Resources"
          expect( new CoffeeFile("prefix/src/test/test.coffee").dest_dir ).toBe "prefix/Resources/test"
          expect( new CoffeeFile("prefix/test/test.coffee").dest_dir ).toBe "prefix/test"

      describe "for alloy", ->

        it "should assign a proper dest_path", ->
          expect( new CoffeeFile("src/alloy/test.coffee").dest_path ).toBe "app/test.js"
          expect( new CoffeeFile("src/alloy/test/test.coffee").dest_path ).toBe "app/test/test.js"
          expect( new CoffeeFile("prefix/src/alloy/test.coffee").dest_path ).toBe "prefix/app/test.js"
          expect( new CoffeeFile("prefix/src/alloy/test/test.coffee").dest_path ).toBe "prefix/app/test/test.js"
          expect( new CoffeeFile("prefix/app/test.coffee").dest_path ).toBe "prefix/app/test.js"
          expect( new CoffeeFile("prefix/test/test.coffee").dest_path ).toBe "prefix/test/test.js"

        it "should assign a proper dest_dir", ->
          expect( new CoffeeFile("src/alloy/test.coffee").dest_dir ).toBe "app"
          expect( new CoffeeFile("src/alloy/test/test.coffee").dest_dir ).toBe "app/test"
          expect( new CoffeeFile("prefix/src/alloy/test.coffee").dest_dir ).toBe "prefix/app"
          expect( new CoffeeFile("prefix/src/alloy/test/test.coffee").dest_dir ).toBe "prefix/app/test"
          expect( new CoffeeFile("prefix/app/test.coffee").dest_dir ).toBe "prefix/app"
          expect( new CoffeeFile("prefix/test/test.coffee").dest_dir ).toBe "prefix/test"

    it "should assign a hash", ->
      ready = false
      runs ->
        @coffee_file = new CoffeeFile(FS.cs_file)
        @promise = @coffee_file.waitingForReady
        @promise.fin(-> ready = true)
      waitsFor (-> ready), "waitingForReady promise to resolve", ASYNC_TIMEOUT
      runs ->
        @promise.done()
        expect( @coffee_file.hash ).toEqual jasmine.any(String)
        expect( @coffee_file.hash.length ).not.toBe 0

  describe "file system methods", ->

    beforeEach ->
      @coffee_file = new CoffeeFile(FS.cs_file)
      @temp_file = FS.getPath("__test_coffee_path__")

    describe "#compile", ->

      it "should return a promise", ->
        expect( @coffee_file.compile new MockLogger ).toBeAPromise()

      it "should create 'Resource' sub-trees", ->
        flag = false
        runs ->
          @promise = Q(@coffee_file.compile new MockLogger)
            .fin(-> flag = true)
        waitsFor (-> flag), "compile()", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( FS.exists(@coffee_file.dest_path) ).toBeTruthy()

      it "should allow environmental override for coffee command", ->
        flag = false
        process.env["COFFEE_PATH"] = "touch #{@temp_file} #"
        runs ->
          @promise = Q(@coffee_file.compile new MockLogger)
            .fin(-> flag = true)
        waitsFor (-> flag), "compile()", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( FS.exists(@temp_file) ).toBeTruthy()

    describe "#clean", ->

      beforeEach ->
        FS.addFile @coffee_file.dest_path

      it "should return a promise", ->
        expect( @coffee_file.clean new MockLogger ).toBeAPromise()

      it "should clean up generated js files", ->
        flag = false
        runs ->
          @promise = Q(@coffee_file.clean new MockLogger)
            .fin(-> flag = true)
        waitsFor (-> flag), "clean()", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( FS.exists(@coffee_file.dest_path) ).toBeFalsy()

      it "should remove directory if empty", ->
        flag = false
        runs ->
          @promise = Q(@coffee_file.clean new MockLogger)
            .fin(-> flag = true)
        waitsFor (-> flag), "clean()", ASYNC_TIMEOUT
        runs ->
          @promise.done()
          expect( FS.exists(path.dirname(@coffee_file.dest_path)) ).toBeFalsy()
