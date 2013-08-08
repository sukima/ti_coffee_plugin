util           = require "util"
path           = require "path"
TiCoffeePlugin = require "#{__dirname}/hooks/plugin"

clean = false
project_dir = "."

usage = ->
  util.log "Usage: cli.js [options] <project-dir>"
  util.log "  Default <project-dir> is '.'"
  util.log "  -h,--help     this cruft"
  util.log "  -v,--version  print the version of the plugin"
  util.log "  -c,--clean    remove any generated JS files"

for arg in process.argv.slice(2)
  switch arg
    when "-h", "--help"
      usage()
      process.exit 0
    when "-v", "--version"
      util.log "Version: #{TiCoffeePlugin.version}"
      process.exit 0
    when "-c", "--clean"
      clean = true
    else
      project_dir = arg

cli = argv:
  "project-dir": project_dir

logger =
  log:   util.log
  info:  (msg) -> util.log "[INFO] #{msg}"
  debug: (msg) -> util.log "[DEBUG] #{msg}"
  warn:  (msg) -> util.log "[WARN] #{msg}"
  error: (msg) -> util.log "[ERROR] #{msg}"

finished = -> process.exit 0

try
  ti_coffee_plugin = new TiCoffeePlugin(logger, {}, cli, {})
  ti_coffee_plugin.onReady ->
    if clean
      ti_coffee_plugin.clean {}, (->), finished
    else
      ti_coffee_plugin.compile {}, finished
catch err
  util.error err
  process.exit 1
