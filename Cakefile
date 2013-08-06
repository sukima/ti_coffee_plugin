fs           = require "fs"
{exec,spawn} = require "child_process"
util         = require "util"
config       = require "./package.json"

zip = (file, dir) ->
  exec "zip -r -b /tmp #{file} .", cwd: dir, (err) ->
    return util.log err if err
    util.log "Created #{dir}/#{file}"

task "clean", "Removes the build directory", ->
  exec "rm -rf build", (err) -> util.log err if err

task "test", "Run specs", ->
  tester = spawn "jasmine-node", [ "--coffee", "--color", "spec/" ], stdio: "inherit"

task "dist", "Build a zip file for distribution", ->
  build_dir = "build/#{config.name}/#{config.version}"
  deep_path = null
  for path in "#{build_dir}/hooks".split("/")
    deep_path = if deep_path? then "#{deep_path}/#{path}" else path
    fs.mkdirSync deep_path unless fs.existsSync deep_path
  unless fs.existsSync "#{build_dir}/plugin.py"
    fs.linkSync "plugin.py", "#{build_dir}/plugin.py"
  exec "coffee --bare --output '#{build_dir}/hooks' --compile 'src/plugin.coffee.md'", (err) ->
    return util.log err if err
    util.log "Compiled plugin."
    zip "#{config.name}-#{config.version}.zip", "build"
