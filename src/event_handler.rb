#!/usr/bin/env ruby
require "rubygems"
require "json"
$LOAD_PATH.push(File.dirname(__FILE__) + "/")
require "keystroke"
require "keymap"
require "ui_helper"

class EventHandler
  attr_accessor :current_mode, :key_queue, :previous_command_stack
  # TODO(philc): This limit should be based on the longest of the user's mapped commands.
  KEY_QUEUE_LIMIT = 3

  # This is how many mutating commands we keep track of, for the purposes of restoring the original cursor
  # position when these commands get unwound via "undo".
  UNDO_STACK_SIZE = 3

  MUTATING_COMMANDS = %W(cut_backward cut_forward cut_word_forward cut_word_backward cut_line
       cut_to_beginning_of_line cut_to_end_of_line paste_before paste_after)

  def initialize
    self.current_mode = :insert
    self.key_queue = []
    self.previous_command_stack = []
  end

  # Executes a single command and returns the response which should be sent to textmate.
  def execute_command(command)
    raise "Unrecognized command: #{command}" unless self.respond_to?(command.to_sym)
    self.key_queue = []
    result = self.send(command.to_sym)
    # When executing commands which modify the document, keep track of the original cursor position
    # so we can restore it when we unwind these commands via undo.
    if MUTATING_COMMANDS.include?(command)
      previous_command_stack.push(
          { :command => command, :line => @message["line"], :column => @message["column"]})
      previous_command_stack.shift if previous_command_stack.size > UNDO_STACK_SIZE
    end
    result
  end

  def handle_key_message(message)
    @message = JSON.parse(message)
    keystroke = KeyStroke.from_character_and_modifier_flags(@message["characters"], @message["modifierFlags"])

    key_queue.push(keystroke.to_s)
    key_queue.shift if key_queue.size > KEY_QUEUE_LIMIT

    commands = commands_for_key_queue()
    if commands.size > 0
      commands.map { |command| execute_command(command) }.flatten
    elsif key_queue_contains_partial_command?
      no_op_command()
    else
      # This key is not bound to any command. If it's insert mode, pass it through.
      should_pass_through = (self.current_mode == :insert || keystroke.modifiers.include?("M"))
      should_pass_through ? [] : no_op_command
    end
  end

  # Returns the user specified command matching the current queue of keys. Multiple commands can be specified
  # as the target of a keybinding (e.g. "h" => ["move_forward", "cut_forward"])
  def commands_for_key_queue
    (0).upto(self.key_queue.size - 1) do |i|
      key_sequence = self.key_queue[i..-1]
      commands = Array(KeyMap.user_keymap[self.current_mode][key_sequence.map(&:to_s).join])
      return commands unless commands.empty?
    end
    []
  end

  # Whether any part of the current queue of keys constitutes the beginning (prefix) of a longer user command.
  def key_queue_contains_partial_command?
    (self.key_queue.size - 1).downto(0) do |i|
      key_sequence = self.key_queue[i..-1]
      return true if EventHandler.is_partial_user_command?(self.current_mode, key_sequence)
    end
    false
  end

  # Whether the given keystrokes are the beginning (prefix) of a longer command.
  def self.is_partial_user_command?(mode, keystrokes)
    keystroke_string = keystrokes.map(&:to_s).join
    # This search could be logarithmic.
    KeyMap.user_keymap[mode].keys.find { |command| command.index(keystroke_string) == 0 } != nil
  end

  #
  # Command methods
  # These methods are all possible methods you can map to when defining keybindings.
  #

  def enter_command_mode
    self.current_mode = :command
    [{ "enterMode:" => ["command"] }] + (@message["hasSelection"] ? ["moveBackward:"] : [])
  end

  def enter_insert_mode
    self.current_mode = :insert
    self.previous_command_stack.clear()
    [{ "enterMode:" => ["insert"] }]
  end

  def enter_visual_mode
    self.current_mode = :visual
    [{ "enterMode:" => ["visual"] }]
  end

  # Movement
  def move_backward() ["moveBackward:"] end
  def move_forward() ["moveForward:"] end
  def move_down() ["moveDown:"] end
  def move_up() ["moveUp:"] end

  def half_page_down() ["moveDown:"] * 6 end
  def half_page_up() ["moveUp:"] * 6 end

  def move_word_backward() ["moveWordBackward:"] end
  def move_word_forward() ["moveWordForward:"] end
  def move_to_end_of_word() ["moveToEndOfWord:"] end

  def move_to_beginning_of_line() ["moveToBeginningOfLine:"] end
  def move_to_end_of_line() ["moveToEndOfLine:"] end

  def move_to_beginning_of_document() ["moveToBeginningOfDocument:"] end
  def move_to_end_of_document() ["moveToEndOfDocument:"] end

  # Movement + selection
  def select_backward() ["moveBackwardAndModifySelection:"] end
  def select_forward() ["moveForwardAndModifySelection:"] end
  def select_down() ["moveDownAndModifySelection:"] end
  def select_up() ["moveUpAndModifySelection:"] end

  def select_half_page_down() ["moveDownAndModifySelection:"] * 6 end
  def select_half_page_up() ["moveUpAndModifySelection:"] * 6 end

  def select_word_backward() ["moveWordBackwardAndModifySelection:"] end
  def select_word_forward() ["moveWordForwardAndModifySelection:"] end
  def select_to_end_of_word() ["moveToEndOfWordAndModifySelection:"] end

  def select_to_beginning_of_line() ["moveToBeginningOfLineAndModifySelection:"] end
  def select_to_end_of_line() ["moveToEndOfLineAndModifySelection:"] end

  def select_to_beginning_of_document() ["moveToBeginningOfDocumentAndModifySelection:"] end
  def select_to_end_of_document() ["moveToEndOfDocumentAndModifySelection:"] end
  
  #
  # Insertion
  #
  def insert_backward() enter_insert_mode end
  def insert_forward() ["moveForward:"] + enter_insert_mode end

  def insert_at_beginning_of_line() move_to_beginning_of_line + enter_insert_mode end
  def insert_at_end_of_line() move_to_end_of_line + enter_insert_mode end

  def insert_newline_above() ["moveToBeginningOfLine:", "addNewline", "moveUp:"] + enter_insert_mode end
  def insert_newline_below() ["moveToEndOfLine:", "addNewline"] + enter_insert_mode end

  #
  # Cutting
  #
  def cut_backward() ["moveBackwardAndModifySelection:", "copySelection", "deleteBackward:"] end
  def cut_forward() ["moveForwardAndModifySelection:", "copySelection", "deleteForward:"] end

  # Which end of the selection we're modifying first matters. After hitting undo, we want
  # the cursor to end up where it was prior to this command.
  def cut_word_forward()
    ["moveWordForward:", "moveWordBackwardAndModifySelection:", "copySelection",
     "deleteForward:"]
  end

  def cut_word_backward()
    ["moveWordBackwardAndModifySelection:", "copySelection", "deleteBackward:"]
  end

  def cut_line()
    ["moveToBeginningOfLine:", "moveDownAndModifySelection:", "copySelection", "deleteBackward:"]
  end

  def cut_to_beginning_of_line()
    ["moveToBeginningOfLineAndModifySelection:", "copySelection", "deleteForward:"]
  end

  def cut_to_end_of_line()
    ["moveToEndOfLineAndModifySelection:", "copySelection", "deleteBackward:"]
  end

  #
  # Copying
  #
  def copy_selection() ["copySelection"] end
  def copy_forward() ["moveForwardAndModifySelection:", "copySelection"] + restore_cursor_position() end

  # VIM will move your cursor to the left when you execute this copy.
  def copy_backward()
    ["moveBackwardAndModifySelection:", "copySelection", "moveForward:", "moveBackward:"]
  end

  def copy_word_forward() ["moveWordForwardAndModifySelection:", "copySelection"] + restore_cursor_position() end

  # VIM will move your cursor to the left when you execute this copy.
  def copy_word_backward()
    ["moveWordBackwardAndModifySelection:", "copySelection"] + restore_cursor_position + ["moveWordBackward:"]
  end

  def copy_line()
    ["moveToBeginningOfLine:", "moveToEndOfLineAndModifySelection:", "copySelection"] +
        restore_cursor_position()
  end

  #
  # Tabs
  #
  def next_tab() ["nextTab"] end
  def previous_tab() ["previousTab"] end

  #
  # Other
  #
  def paste_before() ["paste", "moveForward:"] end

  def paste_after()
    (@message["hasSelection"] ? [] : ["moveForward:"]) + ["paste", "moveForward:"]
  end

  def undo()
    # If we're undoing a previous command which mutated the document, restore the user's cursor position.
    saved_state = previous_command_stack.pop
    ["undo"] + (saved_state ? set_cursor_position(saved_state[:line], saved_state[:column]) : [])
  end

  def no_op_command() ["noOp"] end

  def set_cursor_position(line, column)
    # On the Textmate text view, we have access to a function which lets us set the position of the boundary
    # of one end of the current selection. To collapse that selection, we need to know which end the cursor
    # is on. As a brute force approach, set the selection to the beginning of the document and then move left.
    # Doing so can change the window's vertical scroll position, so we'll restore that.
    [{ "setSelection:column:" => [0, 0] }, "moveBackward:",
     { "setSelection:column:" => [line + 1, column + 1] }, "moveForward:",
     { "scrollTo:" => [@message["scrollY"]] }]
  end

  # Restores the cursor position to whatever it was when this command began executing. Useful for the copy
  # commands, which modify the cursor position to build a selection to copy.
  def restore_cursor_position() set_cursor_position(@message["line"], @message["column"]) end
end

# Loads the user's config file and shows a warning alert message if the file has trouble loading due to
# a syntax error or invalid Ruby.
def load_user_config_file
  config_file_path = File.expand_path("~/.textmatevimrc")
  return unless File.exists?(config_file_path)
  begin
    load(config_file_path)
  rescue LoadError, StandardError => error
    UiHelper.show_alert("Problem loading .textmatevimrc",
        "There was a problem loading your ~/.textmatevimrc:\n\n" + error.to_s)
  end
end

def log(str)
  file = File.open("/tmp/event_handler.log", "a") { |file| file.puts(str) }
end

if $0 == __FILE__
  log "TextMateVim event_handler coprocess is online."

  load "default_config.rb"
  load_user_config_file
  event_handler = EventHandler.new
  while message = STDIN.gets
    response = []
    begin
      response = event_handler.handle_key_message(message)
      log "response: #{response.inspect}"
    rescue => error
      log error.to_s
      log error.backtrace.join("\n")
      response = []
    end
    puts response.to_json
    STDOUT.flush
  end
end