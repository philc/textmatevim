# This is a config file which uses the same format that user config files use. It defines the default key
# mappings.

require "keymap"
include KeyMap

# Movement
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
map "gg", "move_to_beginning_of_document"

map "<C-d>", "half_page_down"
map "<C-u>", "half_page_up"

# Insertion
map "i", "insert_backward"
map "a", "insert_forward"
map "I", "insert_at_beginning_of_line"
map "A", "insert_at_end_of_line"
map "O", "insert_newline_above"
map "o", "insert_newline_below"

# Cutting
map "x", "cut_forward"
map "dl", "cut_forward"
map "dh", "cut_backward"
map "dw", "cut_word_forward"
map "db", "cut_word_backward"


mode(:insert) do
  map "<esc>", "enter_command_mode"
end