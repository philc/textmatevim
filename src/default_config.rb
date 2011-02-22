# This is a config file which uses the same format that user config files use. It defines the default key
# mappings.

require "keymap"
include KeyMap

map "i", "enter_insert_mode"

map "h", "move_backward"
map "l", "move_forward"
map "j", "move_down"
map "k", "move_up"

map "b", "move_word_backward"
map "w", "move_word_forward"
map "e", "move_to_end_of_word"

map "0", "move_to_beginning_of_line"
map "$", "move_to_end_of_line"

map "G", "move_to_end_of_document"

map "ctrl+d", "half_page_down"
map "ctrl+u", "half_page_up"

mode(:insert) do
  map "escape", "enter_command_mode"
end