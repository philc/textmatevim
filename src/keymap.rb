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

  def map(keystroke_string, command_name, &block)
    keystroke = KeyStroke.from_string(keystroke_string)
    mode = @current_mode || :command
    KeyMap.user_keymap[mode] ||= {}
    KeyMap.user_keymap[mode][keystroke.to_s] = block.nil? ? command_name : block
  end

  private

  def self.user_keymap
    KeyMap::USER_KEYMAP
  end
end