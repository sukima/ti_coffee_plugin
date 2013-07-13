#!/usr/bin/env python
"""
Copyright 2011 William Dawson

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

---------------------------------------------------------------------------

ti_coffee_plugin/plugin.py

A simple Titanium project build plugin that will scan your Resources folder
for any .coffee files and invoke "coffee -c" on them, producing .js files with
the same base name.

See README.md for a longer description.
"""

import os, sys, subprocess, hashlib

try:
	import json
except:
	import simplejson as json

# The Titanium build scripts contain their own json library (Patrick Logan's),
# so we have to figure out which json functions to use.
json_read = None
json_write = None
if hasattr(json, 'loads'):
	json_read = json.loads
else:
	json_read = json.read
if hasattr(json, 'dumps'):
	json_write = json.dumps
else:
	json_write = json.write

HASHES_FILE = 'coffee_file_hashes.json'
ERROR_LOG_PREFIX = '[ERROR]'
INFO_LOG_PREFIX = '[INFO]'
DEBUG_LOG_PREIX = '[DEBUG]'

def log(prefix, msg, stream=None):
	if not stream is None:
		print >> stream, "%s %s" % (prefix, msg)
	else:
		print "%s %s" % (prefix, msg)

def err(msg, stream=None):
	# Matches the [ERROR]... messages of the Titanium builder.py, so the
	# message can be recognized as an error for console purposes
	log(ERROR_LOG_PREFIX, msg, stream)

def info(msg):
	# Matches the [INFO]... messages of the Titanium builder.py, so the
	# message can be recognized as an info msgs for console purposes
	log(INFO_LOG_PREFIX, msg)

def debug(msg):
	# Matches the [DEBUG]... messages of the Titanium builder.py, so the
	# message can be recognized as an debug msgs for console purposes
	log(DEBUG_LOG_PREIX, msg)

def read_file_hashes(path):
	hashes_file = os.path.join(path, HASHES_FILE)
	hashes = {}
	if os.path.exists(hashes_file):
		f = open(hashes_file, 'r')
		text = f.read()
		f.close()
		if len(text):
			hashes = json_read(text)
	return hashes

def write_file_hashes(path, hashes):
	hashes_file = os.path.join(path, HASHES_FILE)
	text = json_write(hashes)
	f = open(hashes_file, 'w')
	f.write(text)
	f.close()

def get_md5_digest(path):
	f = open(path, 'r')
	contents = f.read()
	f.close()
	return hashlib.md5(contents).hexdigest()

def build_coffee(path, out):
	debug('Compiling %s' % path)
	if not os.path.exists(out):
		os.makedirs(out)
	command_args = ['-b', '-c', '-o', out, path]
	process = subprocess.Popen(args=command_args, executable='coffee', stdout=subprocess.PIPE, stdin=subprocess.PIPE)
	result = process.wait()
	if result != 0:
		msg = process.stderr.read()
		if msg:
			err("%s (%s)" % (msg, path))
		else:
			err("CoffeeScript compiler call for %s failed but no error message was generated" % path)
		return False
	return True

def build_all_coffee(path, dest_root, file_hash_folder):
	info_msg_shown = False
	file_hashes = read_file_hashes(file_hash_folder)
	for root, dirs, files in os.walk(path):
		for name in files:
			if name.endswith('.coffee'):
				if not info_msg_shown:
					info("Compiling CoffeeScript files")
					info_msg_shown = True
				file_path = os.path.join(root, name)
				dest_path = os.path.join(dest_root, os.path.dirname(os.path.relpath(file_path, path)))
				dest_file = os.path.join(dest_path, "%s.js" % (os.path.splitext(name)[0]))
				digest = get_md5_digest(file_path)
				if (not file_path in file_hashes) or (file_hashes[file_path] != digest) or not os.path.isfile(dest_file):
					if build_coffee(file_path, dest_path):
						file_hashes[file_path] = digest
	write_file_hashes(file_hash_folder, file_hashes)


def compile(config, file_hash_folder=None):
	print config
	if file_hash_folder is None:
		file_hash_folder = os.path.abspath(os.path.join(config['build_dir'], '..'))
	build_all_coffee(os.path.join(config['project_dir'], 'src'), os.path.join(config['project_dir'], 'Resources'), file_hash_folder)

if __name__ == "__main__":
	proj_dir = None
	if len(sys.argv) < 2:
		proj_dir = os.getcwd()
	else:
		proj_dir = sys.argv[1]
	resource_dir = os.path.join(proj_dir, 'Resources')
	if not os.path.exists(resource_dir):
		err("%s does not look like Titanium project folder.  Resources/ folder not found." % proj_dir, sys.stderr)
	config = {'project_dir': proj_dir}
	if os.path.exists(os.path.join(proj_dir, 'build')):
		compile(config, os.path.join(proj_dir, 'build'))
	else:
		compile(config, proj_dir)

