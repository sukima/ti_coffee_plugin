---
layout: default
title: Ti CS Plugin
description: A build-time CoffeeScript compiler plugin for Titanium build scripts - Reborn
---
### <a name="a-coffeescript---javascript-compiler-plugin-for-titanium" class="anchor" href="#a-coffeescript---javascript-compiler-plugin-for-titanium"><span class="octicon octicon-link"></span></a>A CoffeeScript -&gt; JavaScript compiler plugin for Titanium

This plugin has been tested with Titanium SDK 2.x and 3.x.

This project has been reborn from <a href="https://github.com/billdawson" class="user-mention">@billdawson</a>'s [version](https://github.com/billdawson/ti_coffee_plugin).

[Apperson Labs](http://appersonlabs.com/) has an excellent article on [Titanium plugins](http://appersonlabs.com/2013/04/12/titanium-build-plugins-in-sdk-3-x-x/#.UgGgyGT73Nt).

### <a name="how-to-use" class="anchor" href="#how-to-use"><span class="octicon octicon-link"></span></a>How to use

This plugin will compile CoffeeScript files into JavaScript files using the following conventions:

- Any CoffeeScript files in the `src/` directory will compile to JavaScript into the `Resources/` directory.
- Any CoffeeScript files in the `src/alloy/` directory will compile to JavaScript into the `alloy/` directory.
- Any CoffeeScript files in the `alloy/` directory will compile to JavaScript into the `alloy/` directory.<sup>\*</sup>

<sup>\*</sup> This was to allow alloy only projects to keep source files coupled with the XML and TSS assets.

### Installing

The plugin needs to be extracted to the correct location for the Titanium build system to find it. There are currently two places you can save this plugin: *System* or *Project*.

1. Download an unzip the archive.
2. Place the unzipped contents in one of the following location.
3. Add a `<plugins>` entry to your `tiapp.xml`.

#### System

To make the plugin available for *all* your Titanium projects place the folder into your Titanium system plugins directory. This will be inside the Titanium SDK.

On Mac OS X this seems to be:

    ~/Application Support/Titanium/plugins

#### Project

To make this plugin available for a specific project you will have to remove the version directory from the archive. Unzip the archive and move all files and directories in `ti.coffee/{{ site.short_version }}` to `ti.coffee` directory.

For example Titanium will look in your project root for the following directory structure to load this plugin:

    |- :page_facing_up: tiapp.xml
    |- :open_file_folder: Resources/
    \- :open_file_folder: plugins/
       \- :open_file_folder: ti.coffee/
          |- :page_facing_up: plugin.py
          |- :page_facing_up: cli.js
          \- :open_file_folder: hooks/
             \- :page_facing_up: plugin.js

If you don't do this Titanium will ignore the plugin and never compile your CoffeeScript files.
<nobr>( :no_entry_sign: :coffee: = :sob: )</nobr>

#### tiapp.xml

To activate the plugin add an entry for it in your `tiapp.xml` file:

{% highlight xml %}
<plugins>
  <plugin version="{{ site.short_version }}">ti.coffee</plugin>
</plugins>
{% endhighlight %}
