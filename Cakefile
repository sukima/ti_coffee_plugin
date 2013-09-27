fs         = require "fs.extra"
path       = require "path"
{run:exec} = require "execSync"
util       = require "util"
config     = require "./package.json"

ssh_server = "tritarget.org:tritarget.org/files/"

significant_version = config.version.replace /(\d+\.\d+)\.\d+/, "$1"
zipFile = "#{config.name}-#{significant_version}.zip"

zip = (file, dir) ->
  code = exec "cd '#{dir}' && zip -r -b /tmp '#{file}' . && chmod 644 '#{file}'"
  util.log "Created #{dir}/#{file}" unless code

gpgSign = (file, cb) ->
  code = exec "which gpg"
  if code
    util.log "GPG is not in your path. PACKAGE NOT SIGNED!"
    return cb?(true)
  code = exec "gpg -a --detach-sign '#{file}'"
  unless code
    util.log "Signed #{file}"
    return cb?(false)

uploadFile = (file) ->
  util.log "Uploading #{file}"
  exec "scp '#{file}' '#{ssh_server}#{path.basename(file)}'"

task "clean", "Removes the build directory", ->
  exec("rm -rf build")
  util.log "build directory destroyed."
  exec("rm -rf _site")
  util.log "_site directory destroyed."

task "test", "Run specs", ->
  {spawn} = require "child_process"
  spawn "jasmine-node", [ "--coffee", "--color", "spec/" ], stdio: "inherit"

task "dist", "Build a zip file for distribution", ->
  invoke "clean"
  build_dir = "build/#{config.name}/#{significant_version}"
  deep_path = null
  for hook_path in "#{build_dir}/hooks".split("/")
    deep_path = if deep_path? then "#{deep_path}/#{hook_path}" else hook_path
    fs.mkdirSync deep_path unless fs.existsSync deep_path
  unless fs.existsSync "#{build_dir}/plugin.py"
    fs.linkSync "plugin.py", "#{build_dir}/plugin.py"
  unless fs.existsSync "#{build_dir}/README.md"
    fs.linkSync "src/README.md", "#{build_dir}/README.md"
  code =  exec "coffee --bare --output '#{build_dir}' --compile src"
  unless code
    fs.copy "node_modules/q/q.js", "#{build_dir}/hooks/q.js", ->
      util.log "Compiled plugin."
      zip zipFile, "build"

task "deploy", "Ship the zip to file storage (signed)", ->
  invoke "dist"
  zip_path = path.join("build", zipFile)
  asc_path = "#{zip_path}.asc"
  gpgSign zip_path, (err) ->
    uploadFile zip_path
    uploadFile asc_path unless err
