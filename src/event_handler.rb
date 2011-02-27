#!/usr/bin/env ruby
require "rubygems"
require "json"
$LOAD_PATH.push(File.dirname(__FILE__) + "/")
require "keystroke"
require "keymap"

class EventHandler
  attr_accessor :current_mode
  attr_accessor :key_queue
  # TODO(philc): This limit should be based on the longest of the user's mapped commands.
  KEY_QUEUE_LIMIT = 3

  def initialize
    self.current_mode = :insert
    self.key_queue = []
  end

   def handle_key_message(message)
    @message = JSON.parse(message)
    keystroke = KeyStroke.from_character_and_modifier_flags(@message["characters"], @message["modifierFlags"])

    key_queue.push(keystroke.to_s)
    key_queue.shift if key_queue.size > KEY_QUEUE_LIMIT

    command = command_for_key_queue()

    if (command)
      if self.respond_to?(command.to_sym)
        self.key_queue = []
        self.send(command.to_sym)
      else
        raise "Unrecognized command: #{command}"
        []
      end
    elsif key_queue_contains_partial_command?
      no_op_command()
    else
      []
    end
  end

  # Returns the user specified command matching the current queue of keys.
  def command_for_key_queue
    (0).upto(self.key_queue.size - 1) do |i|
      key_sequence = self.key_queue[i..-1]
      command = KeyMap.user_keymap[self.current_mode][key_sequence.map(&:to_s).join]
      return command if command
    end
    nil
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

  def enter_command_mode
    self.current_mode = :command
    ["enterCommandMode"] + (@message["hasSelection"] ? ["moveBackward:"] : [])
  end

  def enter_insert_mode
    self.current_mode = :insert
    ["enterInsertMode"]
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

  # Insertion
  def insert_backward() enter_insert_mode end
  def insert_forward() ["moveForward:"] + enter_insert_mode end

  def insert_at_beginning_of_line() move_to_beginning_of_line + enter_insert_mode end
  def insert_at_end_of_line() move_to_end_of_line + enter_insert_mode end

  def insert_newline_above() ["moveToBeginningOfLine:", "addNewline", "moveUp:"] + enter_insert_mode end
  def insert_newline_below() ["moveToEndOfLine:", "addNewline"] + enter_insert_mode end

  # Cutting
  def cut_backward() ["moveBackwardAndModifySelection:", "writeSelectionToPasteboard", "deleteBackward:"] end
  def cut_forward() ["moveForwardAndModifySelection:", "writeSelectionToPasteboard", "deleteForward:"] end

  # Which end of the selection we're modifying first matters. After hitting undo, we want
  # the cursor to end up where it was prior to this command.
  def cut_word_forward()
    ["moveWordForward:", "moveWordBackwardAndModifySelection:", "writeSelectionToPasteboard",
     "deleteForward:"]
  end

  def cut_word_backward()
    ["moveWordBackwardAndModifySelection:", "writeSelectionToPasteboard", "deleteBackward:"]
  end

  def cut_line()
    ["moveToBeginningOfLine:", "moveDownAndModifySelection:", "writeSelectionToPasteboard", "deleteBackward:"]
  end

  # Other
  # TODO(philc): It would be nice if this could restore the user's cursor position when unrolling one of our
  # commands.
  def undo() ["undo"] end

  def no_op_command() ["noOp"] end
end

def log(str)
  file = File.open("/tmp/event_handler.log", "a") { |file| file.puts(str) }
end

if $0 == __FILE__
  log "TextMateVim event_handler coprocess is online."

  load "default_config.rb"
  event_handler = EventHandler.new
  while message = STDIN.gets
    response = []
    begin
      response = event_handler.handle_key_message(message)
      log "response: #{response.inspect}"
    rescue => error
      log error.to_s
      response = []
    end
    puts response.to_json
    STDOUT.flush
  end
end