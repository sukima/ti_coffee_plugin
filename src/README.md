If you plan to use this in your project and *not* install it in your Titanium
SDK Install you have to move all the files in this directory one level up.

When Titanium looks for plugins in your project's `plugins` directory it
expects there to *not* be a version directory. When you install this into your
Titanium SDK folder it expects there to be a version directory.

#### Project level plugin example ####

    |- Resources/
    |- tiapp.xml
    \- plugins/
       \- ti.coffee
          |- plugin.py
          |- cli.js
          \- hooks
             \- plugin.js

#### System level plugin example ####

    ~/Libarary/Application Support/Titanium/
    \- plugins/
       \- ti.coffee
          \- 2.0
            |- plugin.py
            |- cli.js
            \- hooks
               \- plugin.js


#### tiapp.xml example ####

You have to register the plugin for you project. Do so by adding it to your `tiapp.xml`:

    <plugins>
      <plugin version="2.0">ti.coffee</plugin>
    </plugins>
