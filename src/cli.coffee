util           = require "util"
path           = require "path"
TiCoffeePlugin = require "#{__dirname}/hooks/plugin"

clean = false
project_dir = null

usage = ->
  util.log "Usage: cli.js [--clean] <project-dir>"

for arg in process.argv.slice(2)
  switch arg
    when "-c", "--clean"
      clean = true
    when "-h", "--help"
      usage()
      process.exit 0
    else
      project_dir = arg

unless project_dir?
  util.error "Wrong number of arguments."
  usage()
  process.exit -1

cli = argv:
  "project-dir": project_dir

logger =
  log:   util.log
  info:  util.log
  debug: util.log
  warn:  util.log
  error: util.error

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
