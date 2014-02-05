{writeFileSync,existsSync} = require "fs"
{dirname,basename}         = require "path"
{run:exec}                 = require "execSync"

class FileSystemHelper

  @BASE_PATH:      "tests"
  @getPath:        (path) => "#{@BASE_PATH}/#{path}"
  @cs_file:        @getPath "src/test_cs_dir/test_cs_file.coffee"
  @cs_output_file: @getPath "Resources/test_cs_dir/test_cs_file.js"
  @js_file:        @getPath "Resources/test_js_dir/test_js_file.js"
  @alloy_files: [
    @getPath "src/alloy/test_alloy_dir/test_alloy_file.coffee"
    @getPath "app/test_alloy_dir2/test_alloy_file2.coffee"
  ]
  @alloy_output_files: [
    @getPath "app/test_alloy_dir/test_alloy_file.js"
    @getPath "app/test_alloy_dir2/test_alloy_file2.js"
  ]

  @exists: existsSync

  @addFile: (file_path, data) =>
    exec "mkdir -p #{dirname(file_path)}"
    writeFileSync file_path, data

  @setup: =>
    @addFile @cs_file, "cs_file"
    @addFile alloy_file, "cs_file" for alloy_file in @alloy_files

  @tearDown: =>
    exec "rm -rf #{@BASE_PATH}"

module.exports = FileSystemHelper
