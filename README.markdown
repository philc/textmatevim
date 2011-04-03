TextMateVim - The beauty of TextMate meets the power of Vim
===========================================================

TextMateVim is a plugin for TextMate. It lets you define keystrokes to move about and edit your text files with ease, in the spirit of the Vim command-line editor. If a grizzled Vim hacker and a TextMate-using hipster had children, this is the editor their kids would use.

If you've never used Vim before but you've heard that it's a way to type less to get things done, then this is a great chance to try out the elegant editing model that Vim uses while still being able to leverage OSX's normal text-editing shorcuts.

Installation instructions
-------------------------

You can install the latest release of this plugin by [downloading](https://github.com/downloads/philc/textmatevim/TextMateVim-latest-release.zip) and double-clicking it.

Alternatively, you can install it from source:

1. Clone this git repo
2. run `rake build` from within the git repo (you'll need the XCode Developer tools install for this)
3. Copy or symlink `build/Debug/TextMateVim.bundle` into ~/Library/Application\ Support/TextMate/PlugIns/

Basic Vim usage
---------------
There are three modes: insert, command, and visual. In insert mode, you can type text as you normally would. Hit &lt;esc&gt; to enter command mode (your cursor will change appearance). In command mode, you can use the keybindings described below to quickly move about the document with very few keystrokes. Type "i" to enter insert mode again.

In visual mode, you can use the command mode shortcuts to select text.

Keyboard bindings
-----------------
Modifier keys are specified as &lt;C-x&gt;, &lt;M-x&gt;, &lt;A-x&gt; for CTRL+x, META+x, and ALT+x
respectively. You can customize all of these.

Switching modes
    Esc   enter Command Mode.
    i     enter Insert mode
    v     enter Visual mode. While in Visual mode, you can select text using the various movement keys and cut/copy it.

Movement
    h     move backward
    l     move forward
    j     move down
    k     move up

    b     move backward by one word
    w     move forward by one word

    0     move to the beginning of the line
    $     move to the end of the line

    gg    move to the beginning of the document
    G     move to the end of the document

    <C-d> scroll a half page down
    <C-u> scroll a half page up

Cutting, copying and pasting
    x     cut forward
    dd    cut the current line
    D     cut to the end of the line
    dw    cut the next whole word ("d" works with any of the movement modifiers,
          e.g. "d$" cuts to the end of the current line)
    yy    copy line ("y" works with any of the movements modifiers,
          e.g. "y0" copies to the beginning of the line)

Tabs
    J     previous_tab
    K     next_tab

Other
    u     undo

TextMateVim supports command repetition so, for example, typing "5j" will move the cursor down by 5 lines.

Create your own key mappings
----------------------------
You can define your own custom keybindings by creating a `.textmatevimrc` file in your home directory. It's a Ruby file which looks like this:

    # In command mode, map "n" to be "move down":
    mode(:command) do
      map "n", "move_down"
    end

See [default_config.rb](https://github.com/philc/textmatevim/blob/master/src/default_config.rb) for lots of hints and examples. Note that shifts are automatically detected: `<C-F>` is understood to be Ctrl+Shift+f.

Tips
----
* Prefer using "u" in command mode instead of CMD+Z to undo your edits. This is because when editing in command mode, TextMateVim saves the cursor position prior to the edit and will restore it when you use "u". TextMate's default undo system does not.

Contributing
------------
Your contributions are welcome.

If there is an inconsistency with Vim that troubles you, feel free to file a bug. Before making deep changes to TextMateVim to emulate some behavior of Vim, file a bug and discuss the proposal on the issue tracker.

When you're done hacking, send a pull request on Github. Feel free to include a change to the credits with your patch.

Read [DEVELOPERS.markdown](https://github.com/philc/textmatevim/blob/master/DEVELOPERS.markdown) for more information about hacking and debugging TextMateVim. There is a list of some bigger projects [on the wiki](https://github.com/philc/textmatevim/wiki).

Release notes
-------------
0.2 (April 2, 2011)

 - TextMateVim now checks automatically for new versions.
 - Added support for systems running Ruby 1.9.
 - Added y0 and y$ (copy to the beginning or end of line).
 - Tab switching (shift+J and shift+K) now works reliably.
 - Bugfixes.

0.1 (March 24, 2011)

 - Initial release.

License
-------
Copyright (c) 2011 Phil Crosby. Licensed under the [MIT license](http://www.opensource.org/licenses/mit-license.php).

Credits
-------
    Phil Crosby (twitter @philcrosby)
    Kevin Fitzpatrick (who wrote VimMate, which inspired TextMateVim).
