# Introduction

Koha's Plugin System (available in Koha 3.12+) allows for you to add
additional tools and reports to [Koha](http://koha-community.org) that
are specific to your library. Plugins are installed by uploading KPZ (
Koha Plugin Zip ) packages. A KPZ file is just a zip file containing
the perl files, template files, and any other files necessary to make
the plugin work. Learn more about the Koha Plugin System in the
[Koha Wiki page about plugins](https://wiki.koha-community.org/wiki/Koha_plugins).

# Installing

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

* Change `<enable_plugins>0<enable_plugins>` to `<enable_plugins>1</enable_plugins>` in your koha-conf.xml file
* Confirm that the path to `<pluginsdir>` exists, is correct, and is writable by the web server
* Restart your webserver

Once set up is complete you will need to alter your UseKohaPlugins
system preference.  On the Tools page you will see the Tools Plugins.
From that page you can upload this plug (the .kpz file).  After that,
the Format selector on the Stage MARC Records for Import page will
give you the option "C/W MARS PlugIn".  This will allow you to import
a simple text file, each line of which contains a link to a bibliographic
record on the C/W MARS web site.  The plugin will read each such record
from the web site, and convert it to a MARC record.

You will also need the `cwmars.rb` script (in the top level of this
git repository).  Copy this file to `/usr/local/bin` and make it
executable.  You may need to edit the path in the first line to point
to the actual location of the ruby executable in your system.
Otherwise the plugin, which is running under Apache and which may not
have the same PATH setting as your shell, may not be able to find
ruby.

By default, the plugin will not show up in Koha in the list of 
tool plugins.  Select "View all plugins" in the "View plugins by class"
selector.
