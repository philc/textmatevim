# This is the  configuration DSL that users include into their config files to define key mappings.
#
# Key mappings can be defined using map() and mode():
#   map "j", "moveLeft"
#   map "g,g", "scrollToTop"
#   map("z,z") { arbitrary ruby code }
#
#   mode(:insert) do
#     map "esc", "exitInsertMode"
#   end

require "keystroke"
module KeyMap
  USER_KEYMAP = {}
  @current_mode = nil

  def mode(mode, &block)
    @current_mode = mode.to_sym
    block.call
    @current_mode = nil
  end

  # Parses a string which may contain multiple keystrokes, like "x<C-1>yz".
  def self.keystrokes_from_string(keystroke_string)
    keystrokes = []
    keystroke_string = keystroke_string.dup
    while keystroke_string.size > 0
      char = keystroke_string[0].chr
      if char != "<"
        keystrokes.push(KeyStroke.from_string(char))
        keystroke_string = keystroke_string[1..-1]
      elsif char == "<"
        i = keystroke_string.index(">")
        raise "Invalid key mapping" unless i
        keystrokes.push(KeyStroke.from_string(keystroke_string[0..i]))
        keystroke_string = keystroke_string[(i + 1)..-1] || ""
      end
    end
    keystrokes
  end

  def map(keystroke_string, command_name, &block)
    # keystroke_string may have many keys embedded (e.g. <C-A>gxyz). Parse each one out and then join them
    # back together, so the string of keys is normalized, e.g. the modifiers are in the correct sequence.
    keystrokes = KeyMap.keystrokes_from_string(keystroke_string)
    mode = @current_mode || :command
    KeyMap.user_keymap[mode] ||= {}
    KeyMap.user_keymap[mode][keystrokes.map(&:to_s).join] = block.nil? ? command_name : block
  end

  def self.user_keymap
    KeyMap::USER_KEYMAP
  end
end