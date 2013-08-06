class exports.FS
  {writeFileSync,existsSync} = require "fs"
  {dirname,basename}         = require "path"
  {exec}                     = require "allsync"

  @BASE_PATH:      "tests"
  @getPath:        (path) => "#{@BASE_PATH}/#{path}"
  @cs_file:        @getPath "src/test_cs_dir/test_cs_file.coffee"
  @cs_output_file: @getPath "Resources/test_cs_dir/test_cs_file.js"
  @js_file:        @getPath "Resources/test_js_dir/test_js_file.js"

  @exists: existsSync

  @setup: =>
    exec "mkdir -p #{@getPath 'build'}"
    exec "mkdir -p #{@getPath 'src/test_cs_dir'}"
    exec "touch #{@cs_file}"

  @tearDown: =>
    exec "rm -rf #{@BASE_PATH}"

  @addFile: (file_path, data) =>
    exec "mkdir -p #{dirname(file_path)}"
    writeFileSync file_path, data
