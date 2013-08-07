util           = require "util"
path           = require "path"
TiCoffeePlugin = require "#{__dirname}/hooks/plugin"

clean = false
project_dir = null

usage = ->
  util.log "Usage: cli.js [options] <project-dir>"
  util.log "  -h,--help     this cruft"
  util.log "  -v,--version  print the version of the plugin"
  util.log "  -l,--legacy   convert directory to legacy structure"
  util.log "  -c,--clean    remove any generated JS files"

convertToLegacy = ->
  fs = require "fs"
  src_path = path.resolve path.join(__dirname, "plugin.py")
  dest_path = path.resolve path.join(__dirname, "..", "plugin.py")
  fs.createReadStream(src_path).pipe(fs.createWriteStream(dest_path));
  util.log "Copied #{src_path} to #{dest_path}"

for arg in process.argv.slice(2)
  switch arg
    when "-h", "--help"
      usage()
      process.exit 0
    when "-v", "--version"
      util.log "Version: #{TiCoffeePlugin.version}"
      process.exit 0
    when "-l", "--legacy"
      convertToLegacy()
      process.exit 0
    when "-c", "--clean"
      clean = true
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
