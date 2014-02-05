Q            = require "q"
path         = require "path"
{CoffeeFile} = require "../src/hooks/plugin"
{expect}     = require "chai"
sinon        = require "sinon"
FS           = require "./support/file_system_helper"
MockLogger   = require "./support/mock_logger"

describe "CoffeeFile", ->
  sandbox = sinon.sandbox.create()

  beforeEach ->
    FS.setup()

  afterEach ->
    FS.tearDown()
    sandbox.restore()

  describe "#constructor", ->

    describe "path converting", ->

      beforeEach ->
        sandbox.stub CoffeeFile::, "findHash"

      it "should convert CoffeeScript extention to JavaScript extention", ->
        expect( new CoffeeFile("src/test.coffee").dest_path ).to.match /\.js$/
        expect( new CoffeeFile("src/test.coffee.md").dest_path ).to.match /\.js$/
        expect( new CoffeeFile("src/test.litcoffee").dest_path ).to.match /\.js$/

      describe "for basic app", ->

        it "should assign a proper dest_path", ->
          expect( new CoffeeFile("src/test.coffee").dest_path ).to.equal "Resources/test.js"
          expect( new CoffeeFile("src/test/test.coffee").dest_path ).to.equal "Resources/test/test.js"
          expect( new CoffeeFile("prefix/src/test.coffee").dest_path ).to.equal "prefix/Resources/test.js"
          expect( new CoffeeFile("prefix/src/test/test.coffee").dest_path ).to.equal "prefix/Resources/test/test.js"
          expect( new CoffeeFile("prefix/test/test.coffee").dest_path ).to.equal "prefix/test/test.js"

        it "should assign a proper dest_dir", ->
          expect( new CoffeeFile("src/test.coffee").dest_dir ).to.equal "Resources"
          expect( new CoffeeFile("src/test/test.coffee").dest_dir ).to.equal "Resources/test"
          expect( new CoffeeFile("prefix/src/test.coffee").dest_dir ).to.equal "prefix/Resources"
          expect( new CoffeeFile("prefix/src/test/test.coffee").dest_dir ).to.equal "prefix/Resources/test"
          expect( new CoffeeFile("prefix/test/test.coffee").dest_dir ).to.equal "prefix/test"

      describe "for alloy", ->

        it "should assign a proper dest_path", ->
          expect( new CoffeeFile("src/alloy/test.coffee").dest_path ).to.equal "app/test.js"
          expect( new CoffeeFile("src/alloy/test/test.coffee").dest_path ).to.equal "app/test/test.js"
          expect( new CoffeeFile("prefix/src/alloy/test.coffee").dest_path ).to.equal "prefix/app/test.js"
          expect( new CoffeeFile("prefix/src/alloy/test/test.coffee").dest_path ).to.equal "prefix/app/test/test.js"
          expect( new CoffeeFile("prefix/app/test.coffee").dest_path ).to.equal "prefix/app/test.js"
          expect( new CoffeeFile("prefix/test/test.coffee").dest_path ).to.equal "prefix/test/test.js"

        it "should assign a proper dest_dir", ->
          expect( new CoffeeFile("src/alloy/test.coffee").dest_dir ).to.equal "app"
          expect( new CoffeeFile("src/alloy/test/test.coffee").dest_dir ).to.equal "app/test"
          expect( new CoffeeFile("prefix/src/alloy/test.coffee").dest_dir ).to.equal "prefix/app"
          expect( new CoffeeFile("prefix/src/alloy/test/test.coffee").dest_dir ).to.equal "prefix/app/test"
          expect( new CoffeeFile("prefix/app/test.coffee").dest_dir ).to.equal "prefix/app"
          expect( new CoffeeFile("prefix/test/test.coffee").dest_dir ).to.equal "prefix/test"

    it "should assign a hash", (done) ->
      @coffee_file = new CoffeeFile(FS.cs_file)
      @promise = @coffee_file.waitingForReady
      @promise.then =>
        expect( @coffee_file.hash ).to.be.a "string"
        expect( @coffee_file.hash.length ).to.not.equal 0
        done()
      .fail(done)

  describe "file system methods", ->

    beforeEach ->
      @coffee_file = new CoffeeFile(FS.cs_file)
      @temp_file = FS.getPath("__test_coffee_path__")

    describe "#compile", ->

      it "should create 'Resource' sub-trees", (done) ->
        @promise = Q @coffee_file.compile(new MockLogger)
        @promise.then =>
          expect( FS.exists(@coffee_file.dest_path) ).to.be.true
          done()
        .fail(done)

      it "should allow environmental override for coffee command", (done) ->
        process.env["COFFEE_PATH"] = "touch #{@temp_file} #"
        @promise = Q @coffee_file.compile(new MockLogger)
        @promise.then =>
          expect( FS.exists(@temp_file) ).to.be.true
          done()
        .fail(done)

    describe "#clean", ->

      beforeEach ->
        FS.addFile @coffee_file.dest_path

      it "should clean up generated js files", (done) ->
        @promise = Q @coffee_file.clean(new MockLogger)
        @promise.then =>
          expect( FS.exists(@coffee_file.dest_path) ).to.be.false
          done()
        .fail(done)

      it "should remove directory if empty", (done) ->
        @promise = Q @coffee_file.clean(new MockLogger)
        @promise.then =>
          expect( FS.exists(path.dirname(@coffee_file.dest_path)) ).to.be.false
          done()
        .fail(done)
