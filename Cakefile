fs            = require "fs.extra"
child_process = require "child_process"
path          = require "path"
util          = require "util"
Q             = require "q"
config        = require "./package.json"

exec   = Q.denodeify child_process.exec
copy   = Q.denodeify fs.copy
link   = Q.denodeify fs.link
exists = fs.existsSync

ssh_server = "tritarget.org:tritarget.org/files/"

significant_version = config.version.replace /(\d+\.\d+)\.\d+/, "$1"
zipFile = "#{config.name}-#{significant_version}.zip"

task "clean",  "Removes the build directory",           -> clean().done()
task "test",   "Run specs",                             -> test().done()
task "dist",   "Build a zip file for distribution",     -> dist().done()
task "deploy", "Ship the zip to file storage (signed)", -> deploy().done()

zip = (file, dir) ->
  waitingForZip = exec "cd '#{dir}' && zip -r -b /tmp '#{file}' . && chmod 644 '#{file}'"
  waitingForZip.then -> util.log "Created #{dir}/#{file}"
  waitingForZip

gpgSign = (file) ->
  defer = Q.defer()
  waitingForWhich = exec "which gpg"
  waitingForWhich.fail ->
    defer.reject "GPG is not in your path."
  waitingForWhich.then ->
    waitingForGPG = exec "gpg -a --detach-sign '#{file}'"
    waitingForGPG.fail ->
      defer.reject "Problem signing #{file}. See output for errors."
    waitingForGPG.then ->
      defer.resolve "Signed #{file}"
    waitingForGPG.done()
  waitingForWhich.done()
  defer.promise

uploadFile = (file) ->
  waitingForSCP = exec("scp '#{file}' '#{ssh_server}#{path.basename(file)}'")
  waitingForSCP.then -> util.log "Uploaded #{file}"
  waitingForSCP

clean = ->
  promise1 = exec("rm -rf build").then ->
    util.log "build directory destroyed."
  promise2 = exec("rm -rf _site").then ->
    util.log "_site directory destroyed."
  waitingForClean = Q.all([promise1, promise1])
  waitingForClean.fail (reason) -> util.log "[ERROR] #{reason}"
  waitingForClean

test = ->
  spawn = Q.denodeify child_process.spawn
  waitingForTests = tryToLink("node_modules/q/q.js", "src/q.js")
    .then ->
      spawn "mocha", [ "--compilers", "coffee:coffee-script", "-R", "spec" ], stdio: "inherit"
    .fail (reason) ->
      util.log "[ERROR] #{reason}"
  waitingForTests

buildDeepPath = (path) ->
  for hook_path in path.split("/")
    deep_path = if deep_path? then "#{deep_path}/#{hook_path}" else hook_path
    fs.mkdirSync deep_path unless exists deep_path
  Q.resolve path

tryToLink = (src, dest) ->
  if exists dest
    Q.resolve dest
  else
    link src, dest

dist = ->
  build_dir = "build/#{config.name}/#{significant_version}"
  deep_path = null
  clean()
    .then(-> buildDeepPath "#{build_dir}/hooks")
    .then(-> tryToLink "plugin.py", "#{build_dir}/plugin.py")
    .then(-> tryToLink "src/README.md", "#{build_dir}/README.md")
    .then(-> exec "coffee --bare --output '#{build_dir}' --compile src")
    .then(-> copy "node_modules/q/q.js", "#{build_dir}/q.js")
    .then(-> zip zipFile, "build")
    .then(-> util.log "Build complete")

deploy = ->
  zip_path = path.join("build", zipFile)
  asc_path = "#{zip_path}.asc"
  dist().then(-> gpgSign zip_path).then ->
    Q.all uploadFile(zip_path), uploadFile(asc_path)
