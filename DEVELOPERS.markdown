Overview
========
TextMateVim is composed of two parts. The first is a TextMate plugin written in Objective C. The second is an event handler written in Ruby. At a high level, the objective C plugin spawns the Ruby event handler as a child process and passes it keydown events. The Ruby event handler has all of the logic related to implementing users' key mappings.

The rationale for having the Ruby event handler is that the Ruby portion is far easier to change and debug, and can even be modified while TextMate is running.

Building & Hacking
==================
To build the plugin, from the root of the project directory, run

    rake build

The plugin will appear in `build/Debug/TextMateVim.bundle`. At this point you could copy or symlink the plugin into your `/Library/Application Support/TextMate/PlugIns` directory and start playing with it.

However, the best and fastest way to hack on this plugin is to launch a second "developer" instance of TextMate, so that you don't jack up your primary TextMate environment while changing this plugin.

To create a second developer copy of TextMate, perform these steps:

    cp -R /Applications/TextMate /Applications/DevTextMate
    mv /Applications/DevTextMate.app/Contents/MacOS/TextMate /Applications/DevTextMate.app/Contents/MacOS/DevTextMate
    cp -R cp ~/Library/Application\ Support/TextMate ~/Library/Application\ Support/DevTextMate

Now you can run two TextMates side-by-side, each with their own different bundles and plugins.

To both build and load the TextMateVim plugin into your Developer TextMate, run

    rake debug

Tests
=====
For any large refactorings or non-trivial changes, leverage the unit tests. You can run them like this:

    rake test

Coding style
============
 * Follow the style in the file you're editing.
 * Ensure your lines don't exceed 110 characters.

References
==========
After browsing through the source code, you'll see that most of the modal editing commands are implemented in editor_commands.rb. Most of the commands that we send to TextMate are methods on Cocoa's NSResponder class. Browsing the Apple documentation for what NSResponder can do will tell you what's possible.

Exploring Textmate's classes
-----------------------------
The best way to poke around with TextMate's classes is to use the FScript Injection service. It allows you to explore with a GUI at runtime the classes TextMate is using, and invoke methods on them. You can use a Firebug-style inspector to identify the various views which make up TextMate. The most important is the primary text editing class, OakTextView. You'll see many references to this in the code.

[http://pmougin.wordpress.com/2010/01/05/the-revenge-of-f-script-anywhere/](http://pmougin.wordpress.com/2010/01/05/the-revenge-of-f-script-anywhere/)


Another way to explore classes is to perform a classdump of TextMate. I've found this less useful than using the FScript explorer. Here's an overview of how to do this:

[http://www.culater.net/wiki/moin.cgi/CocoaReverseEngineering](http://www.culater.net/wiki/moin.cgi/CocoaReverseEngineering)