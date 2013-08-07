---
layout: default
title: Ti CS Plugin
description: A build-time CoffeeScript compiler plugin for Titanium build scripts - Reborn
---
### <a name="a-coffeescript---javascript-compiler-plugin-for-titanium" class="anchor" href="#a-coffeescript---javascript-compiler-plugin-for-titanium"><span class="octicon octicon-link"></span></a>A CoffeeScript -&gt; JavaScript compiler plugin for Titanium

**Version: 2.0.3**

This plugin has been tested with Titanium SDK 2.x and 3.x.

This project has been reborn from <a href="https://github.com/billdawson" class="user-mention">@billdawson</a>'s [version](https://github.com/billdawson/ti_coffee_plugin).

[Apperson Labs](http://appersonlabs.com/) has an excellent article on [Titanium plugins](http://appersonlabs.com/2013/04/12/titanium-build-plugins-in-sdk-3-x-x/#.UgGgyGT73Nt).

### <a name="how-to-use" class="anchor" href="#how-to-use"><span class="octicon octicon-link"></span></a>How to use

The plugin needs to be extracted to the correct location for the Titanium build system to find it. There are currently two places you can save this plugin: *System* or *Project*.

1. Download an unzip the archive.
2. Place the unzipped contents in on of the following location.
3. Add a `<plugins>` entry to your `tiapp.xml`.

#### System

To make the plugin available for *all* your Titanium projects place the folder into your Titanium system plugins directory. This will be inside the Titanium SDK.

On Mac OS X this seems to be:

    ~/Application Support/Titanium/plugins

#### Project

To make this plugin available for a specific project place the contents of the zip archive into a `plugins` folder in the project root.

#### tiapp.xml

To activate the plugin add an entry for it in your `tiapp.xml` file:

{% highlight xml %}
<plugins>
  <plugin version="2.0">ti.coffee</plugin>
</plugins>
{% endhighlight %}

### <a name="android" class="anchor" href="#android"><span class="octicon octicon-link"></span></a>Android and Titanium SDK &lt; 3.X (legacy)

As of Titanium SDK 3.1.1.GA Android build still use the legacy 2.X build system based on python. In the 2.X build system project based plugins used a different directory structure the what is packaged in the zip file. If you plan on including this in your *project* which is built on the 2.X build system or to build Android you will have to convert the directory tree.

**You do not need to do this if the plugin is installed system wide (see above)**

The easy way if you have node installed is to run the conversion utility:

    $ node /path/to/project/plugins/ti.coffee/2.0/cli.js --legacy

Or to do so manually just copy the `plugin.py` file to the root of the plugin:

    $ cp /path/to/project/plugins/ti.coffee/2.0/plugin.py /path/to/project/plugins/ti.coffee/plugin.py

(Notice we just moved the `plugin.py` file above the version directory).

