Titanium CoffeeScript Compiler Plugin
=====================================

This is a plugin for the titanium CLI version 3.0.0 or greater.

    Q            = require "q"
    fs           = require "fs"
    path         = require "path"
    {exec}       = require "child_process"
    {createHash} = require "crypto"

    module.exports = class TiCoffeePlugin

## Configuration (static) ##

      @name:       "ti.coffee"
      @version:    "2.2.0"
      @cliVersion: ">=3.X" # What verion this plugin works with
      @HASH_FILE:  "coffee_file_hashes.json"

## Entry Point ##

The main entry point for the plugin. Construct a new `TiCoffeePlugin` and
attach it to the `build.pre.compile` hook.

      @init: (logger, config, cli, appc) =>
        ti_coffee_plugin = new TiCoffeePlugin(logger, config, cli, appc)
        logger.info "[ti.coffee] Loaded plugin"
        cli.addHook "build.pre.compile", priority: 10, post: ti_coffee_plugin.compile
        logger.debug "[ti.coffee] Added build.pre.compile hook"
        cli.addHook "clean.post", ti_coffee_plugin.clean
        logger.debug "[ti.coffee] Added clean.post hook"
        return

## CoffeeFile ##

A class to describe a coffee file that needs compilations. It will store the
source path, dest path, MD5 hash.

The hashes are used to skip compilation of files that have not changed.

      @CoffeeFile: class

        constructor: (@src_path) ->
          @dest_path = destPathFromSrcPath(@src_path)
          @dest_dir  = path.dirname(@dest_path)
          @waitingForReady = @findHash()

### findHash ###

A helper function to load the hash of a CS file. Mostly used for stubbing in
tests.

        findHash: ->
          (findMD5FromSrc @src_path).then (@hash) =>

### Compile individual CoffeeFile ###

        compile: (logger) ->
          logger.info "[ti.coffee] Compiling: #{@src_path}"
          command = process.env["COFFEE_PATH"] || "coffee"
          command += " --bare --compile --output #{@dest_dir} #{@src_path}"
          logger.debug "[ti.coffee] Executing: #{command}"
          Q.nfcall(exec, command)

### Clean individual CoffeeFile ###

We want to remove the generated JS file as well as any directories in the tree
that become empty after the JS file is removed.

        clean: (logger) ->
          logger.info "[ti.coffee] Removing generated file: #{@dest_path}"
          defer = Q.defer()
          rmdir = (dir) ->
            dir = path.dirname(dir)
            fs.rmdir dir, (err) -> unless err then rmdir(dir) else defer.resolve()
          fs.unlink @dest_path, => rmdir(@dest_path)
          defer.promise

## Constructor ##

Encapsulate the call back into an object for easier manipulation of the
environment.

This means storing a reference to `logger`, `config`, `cli`, etc. Allowing the
call back chain access at any level and controlled through binding.

      constructor: (@logger, @config, @cli, @appc) ->
        @project_dir    = @cli.argv['project-dir']
        @build_dir      = path.join @project_dir, "build"
        @src_dir        = path.join @project_dir, "src"
        @alloy_dir      = path.join @project_dir, "app"
        @hash_file_path = path.join @build_dir, TiCoffeePlugin.HASH_FILE
        @loadHashes()
        @waitingForReady = @findCoffeeFiles()

## Hooks ##

### compile ###

This is the main hook used to perform the compilation.

      compile: (build, finish) =>
        @waitingForReady.then =>
          promises = []
          for coffee_file in @coffee_files
            if not fs.existsSync(coffee_file.dest_path) or @hashes[coffee_file.src_path] isnt coffee_file.hash
              promises.push coffee_file.compile(@logger)
            else
              @logger.debug "[ti.coffee] Skipping (not changed): #{coffee_file.src_path}"
          Q.allSettled(promises).fin(finish).then =>
            @updateHashes()
            @storeHashes()

### clean ###

Used to clean up generated JS files in `Resources` directory.

      clean: (build, finish) =>
        @waitingForReady.then =>
          promises = []
          promises.push coffee_file.clean(@logger) for coffee_file in @coffee_files
          promises.push Q.nfcall(fs.unlink, @hash_file_path)
          Q.allSettled(promises).fin finish

## Helper Functions ##

### findCoffeeFiles ###

Search and find all CoffeeScript files

      findCoffeeFiles: ->
        # TODO: Remove dependency on unix find tool.
        waitingForCoffeeFileInstances = Q.allSettled([
          Q.nfcall(exec, "find #{@src_dir}")
          Q.nfcall(exec, "find #{@alloy_dir}")
        ]).then (results) =>
          coffee_files = []
          for result in results
            if result.state is "rejected"
              @logger.debug "[ti.coffee] #{result.reason}"
            else
              # result.value => [ stdin, stderr ]
              file_paths = result.value[0].split("\n")
              for file_path in file_paths
                continue unless file_path.match /\.(lit)?coffee(\.md)?$/
                coffee_files.push new TiCoffeePlugin.CoffeeFile(file_path)
          coffee_files
        waitingForCoffeeFileInstances.then (@coffee_files) =>
          unless @coffee_files.length > 0
            @logger.warn "[ti.coffee] Unable to find any CoffeeScript files in #{@src_dir} or #{@alloy_dir}"
          @coffee_files

### loadHashes ###

Read the hash file.

      loadHashes: ->
        return @hashes = {} unless fs.existsSync(@hash_file_path)
        @hashes = require(path.resolve(@hash_file_path))

### updateHashes ###

Update the `hashes` based on the loaded `coffee_files`.

      updateHashes: ->
        @hashes = {}
        for coffee_file in @coffee_files
          @hashes[coffee_file.src_path] = coffee_file.hash
        @hashes

### storeHahses ###

Build the hash file into `build/coffee_file_hashes.json`

      storeHashes: ->
        writeFile = =>
          Q.nfcall(fs.writeFile, @hash_file_path, JSON.stringify(@hashes))
        if fs.existsSync path.dirname(@hash_file_path)
          waitingForWriteFile = writeFile()
        else
          waitingForWriteFile = Q.nfcall(fs.mkdir, path.dirname(@hash_file_path))
            .then(writeFile)
        waitingForWriteFile.fail (err) => @logger.error err

### findMD5FromSrc (private) ##

Create an MD5 hash from a file then pass it to a callback.

    findMD5FromSrc = (file) ->
      defer = Q.defer()
      unless fs.existsSync(file)
        defer.resolve("")
      else
        md5sum = createHash("md5")
        f = fs.ReadStream(file)
        f.on "data", (data) -> md5sum.update(data)
        f.on "end", -> defer.resolve md5sum.digest("hex")
      defer.promise

### destPathFromSrcPath (private) ###

Build the destination path based on the source path. Essentially convert
`src/some/path.coffee` to `Resources/some/path.js`.

    destPathFromSrcPath = (src_path) ->
      src_path.replace(/(^|\/)src\/alloy\//, "$1app/")
        .replace(/(^|\/)src\//, "$1Resources/")
        .replace(/\.(lit)?coffee(\.md)?/, ".js")
