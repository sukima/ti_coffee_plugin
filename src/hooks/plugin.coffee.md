Titanium CoffeeScript Compiler Plugin
=====================================

This is a plugin for the titanium CLI version 3.0.0 or greater.

    fs           = require "fs"
    path         = require "path"
    {exec}       = require "child_process"
    {createHash} = require "crypto"

    module.exports = class TiCoffeePlugin

## Configuration (static) ##

      @name:       "ti.coffee"
      @version:    "2.0.2"
      @cliVersion: ">=3.X" # What verion this plugin works with
      @HASH_FILE:  "coffee_file_hashes.json"

## Entry Point ##

The main entry point for the plugin. Construct a new `TiCoffeePlugin` and
attach it to the `build.pre.compile` hook.

      @init: (logger, config, cli, appc) =>
        ti_coffee_plugin = new TiCoffeePlugin(logger, config, cli, appc)
        cli.addHook "build.pre.compile", priority: 10, post: ti_coffee_plugin.compile
        cli.addHook "clean.post", ti_coffee_plugin.clean

## CoffeeFile ##

A class to describe a coffee file that needs compilations. It will store the
source path, dest path, MD5 hash.

The hashes are used to skip compilation of files that have not changed.

      @CoffeeFile: class

        constructor: (@src_path) ->
          @dest_path = destPathFromSrcPath(@src_path)
          @dest_dir  = path.dirname(@dest_path)
          @listeners = []
          @createHash()

### createHash ###

A helper function to load the hash of a CS file. Because this is asynchronous
we allow attaching callback via `onReady`.

        createHash: ->
          registerMD5Hash @src_path, (@hash) =>
            fn(@) for fn in @listeners if @listeners?
            @listeners = null

### onReady ###

Add callbacks to the stack to be executed when the hash is complete.

        onReady: (callback) ->
          return callback(@) unless @listeners?
          @listeners.push callback

### Compile individual CoffeeFile ###

        compile: (logger, cb) ->
          logger.info "[ti.coffee] Compiling: #{@src_path}"
          command = process.env["COFFEE_PATH"] || "coffee"
          command += " --bare --compile --output #{@dest_dir} #{@src_path}"
          exec command, cb

### Clean individual CoffeeFile ###

We want to remove the generated JS file as well as any directories in the tree
that become empty after the JS file is removed.

        clean: (logger, cb) ->
          logger.info "[ti.coffee] Removing generated file: #{@dest_path}"
          rmdir = (dir, cb) ->
            dir = path.dirname(dir)
            fs.rmdir dir, (err) -> unless err then rmdir(dir, cb) else cb?()
          fs.unlink @dest_path, => rmdir(@dest_path, cb)

## Constructor ##

Encapsulate the call back into an object for easier manipulation of the
environment.

This means storing a reference to `logger`, `config`, `cli`, etc. Allowing the
call back chain access at any level and controlled through binding.

      constructor: (@logger, @config, @cli, @appc) ->
        @project_dir    = @cli.argv['project-dir']
        @build_dir      = path.join @project_dir, "build"
        @src_dir        = path.join @project_dir, "src"
        @hash_file_path = path.join @build_dir, TiCoffeePlugin.HASH_FILE
        @loadHashes()
        @waitingForFindCoffeeFiles = true
        @findCoffeeFiles =>
          @waitingForFindCoffeeFiles = false
          @finishReady()

## Hooks ##

### compile ###

This is the main hook used to perform the compilation.

      compile: (build, finish) => @onReady =>
        for coffee_file in @coffee_files
          if not fs.existsSync(coffee_file.dest_path) or @hashes[coffee_file.src_path] isnt coffee_file.hash
            coffee_file.compile(@logger)
          else
            @logger.debug "[ti.coffee] Skipping (not changed): #{coffee_file.src_path}"
        @updateHashes()
        @storeHashes()
        finish()

### clean ###

Used to clean up generated JS files in `Resources` directory.

      clean: (build, finish, cb) => @onReady =>
        coffee_file.clean(@logger) for coffee_file in @coffee_files
        fs.unlink @hash_file_path, -> cb?()
        finish()

## Helper Functions ##

### onReady ###

Add callbacks to the stack to be executed when the hash is complete.

      onReady: (callback) ->
        return callback(@) unless @waitingForFindCoffeeFiles
        @listeners ?= []
        @listeners.push callback

### finishReady ###

Used as a callback to monitor when this object is ready.

      finishReady: ->
        return false if @waitingForFindCoffeeFiles
        cb(@) for cb in @listeners if @listeners?
        @listeners = null

## findCoffeeFiles ##

Search and find all CoffeeScript files

      findCoffeeFiles: (cb) ->
        @coffee_files = []
        count = 0
        lowerCountAndCallBack = -> cb?() unless --count > 0
        # TODO: Remove dependency on unix find tool.
        exec "find #{@src_dir}", (err, stdout) =>
          if err
            @logger.warn "[ti.coffee] Unable to find any CoffeeScript files in #{@src_dir}"
            return cb?()
          file_paths = stdout.split("\n")
          for file_path in file_paths
            continue unless file_path.match /\.(lit)?coffee(\.md)?$/
            count++
            coffee_file = new TiCoffeePlugin.CoffeeFile(file_path)
            coffee_file.onReady lowerCountAndCallBack
            @coffee_files.push(coffee_file)

## loadHashes ##

Read the hash file.

      loadHashes: ->
        return @hashes = {} unless fs.existsSync(@hash_file_path)
        @hashes = require(path.resolve(@hash_file_path))

## updateHashes ##

Update the `hashes` based on the loaded `coffee_files`.

      updateHashes: ->
        @hashes = {}
        for coffee_file in @coffee_files
          @hashes[coffee_file.src_path] = coffee_file.hash
        @hashes

## storeHahses ##

Build the hash file into `build/coffee_file_hashes.json`

      storeHashes: (cb) ->
        fs.writeFile @hash_file_path, JSON.stringify(@hashes), (err) ->
          throw err if err
          cb?()

### registerMD5Hash (private) ##

Create an MD5 hash from a file then pass it to a callback.

    registerMD5Hash = (file, callback) ->
      return callback("") unless fs.existsSync(file)
      md5sum = createHash("md5")
      f = fs.ReadStream(file)
      f.on "data", (data) -> md5sum.update(data)
      f.on "end", -> callback md5sum.digest("hex")

### destPathFromSrcPath (private) ###

Build the destination path based on the source path. Essentially convert
`src/some/path.coffee` to `Resources/some/path.js`.

    destPathFromSrcPath = (src_path) ->
      components = src_path.split "/"
      components = components.map (i) -> if i is "src" then "Resources" else i
      dest_path = components.join "/"
      dest_path.replace /\.(lit)?coffee(\.md)?/, ".js"
