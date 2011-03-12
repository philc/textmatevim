#!/usr/bin/env ruby
require "rubygems"
require "json"
$LOAD_PATH.push(File.dirname(__FILE__) + "/")
require "keystroke"
require "keymap"
require "ui_helper"
require "editor_commands"

ENABLE_DEBUG_LOGGING = false

class EventHandler
  include EditorCommands

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

  # Handles a message from the Textmate process.
  # - message: a JSON string, where message["message"] indiciates the type of message.
  def handle_message(message)
    message_json = JSON.parse(message)
    case message_json["message"]
    when "keydown": handle_keydown_message(message_json)
    when "getKeybindings": handle_get_keybindings_message
    end
  end

  # Interprets the keystroke event in light of the current mode.
  # Returns a list of commands that TextMateVim should perform. The ["no_op"] command instructs TextMateVim
  # to ignore the current keystroke. An empty list means to pass-through the keystroke.
  def handle_keydown_message(message)
    @event = message
    keystroke = KeyStroke.from_character_and_modifier_flags(@event["characters"], @event["modifierFlags"])

    key_queue.push(keystroke.to_s)
    key_queue.shift if key_queue.size > KEY_QUEUE_LIMIT

    commands = commands_for_key_queue()
    if !commands.empty?
      message_commands = commands.map { |command| execute_command(command) }.flatten
      message_commands.each do |message_command|
        if message_command.is_a?(Hash)
          send_message(message_command)
        else
          send_message(message_command => [])
        end
      end
      send_message({ :suppressKeystroke => [] }, false)
    elsif key_queue_contains_partial_command?
      send_message({ :suppressKeystroke => [] }, false)
    else
      # This key is not bound to any command. For insert mode, pass it through. In other modes, suppress it.
      should_pass_through = (self.current_mode == :insert || keystroke.modifiers.include?("M"))
      send_message({ (should_pass_through ? :passThroughKeystroke : :suppressKeystroke) => [] }, false)
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

  # Executes a single command and returns the response which should be sent to textmate. The cursor's
  # original position is saved when executing mutating commands, so we can restore it if the user undos.
  def execute_command(command)
    raise "Unrecognized command: #{command}" unless self.respond_to?(command.to_sym)
    self.key_queue = []
    result = self.send(command.to_sym)
    # When executing commands which modify the document, keep track of the original cursor position
    # so we can restore it when we unwind these commands via undo.
    if MUTATING_COMMANDS.include?(command)
      previous_command_stack.push(
          { :command => command, :line => @event["line"], :column => @event["column"]})
      previous_command_stack.shift if previous_command_stack.size > UNDO_STACK_SIZE
    end
    result
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

  # Returns all keybindings for all modes that the user has mapped, in the form of:
  # [[key, modifier_flags], ...] where modifier_flags is an int. These bindings will be used by Textmatevim
  # to disable any Textmate menu items which conflict with the user's mapped keystrokes.
  def handle_get_keybindings_message
    keystroke_strings = KeyMap.user_keymap.map { |mode, bindings| bindings.keys }.flatten.uniq.sort
    keystrokes = keystroke_strings.map { |string| KeyMap.keystrokes_from_string(string) }.flatten.uniq
    keybindings = keystrokes.map do |keystroke|
      [keystroke.modifiers.include?("S") ? keystroke.key.upcase : keystroke.key,
       keystroke.modifier_flags(false)]
    end
    send_message({ :keybindings => keybindings }, false)
  end
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

def debug_log(str) log(str) if ENABLE_DEBUG_LOGGING end

# Send message sends a message and waits for a response.
def send_message(message, wait_for_response = true)
  debug_log("sending message: #{message}")
  puts message.to_json
  STDOUT.flush
  return nil unless wait_for_response
  response = STDIN.gets
  debug_log("received response: #{response}")
  JSON.parse(response)
end

if $0 == __FILE__
  log "TextMateVim event_handler.rb coprocess is online."

  load "default_config.rb"
  load_user_config_file
  event_handler = EventHandler.new
  while message = STDIN.gets
    response = []
    begin
      debug_log "received message: #{message}"
      messages = event_handler.handle_message(message)
      debug_log "response: #{response.inspect}"
    rescue => error
      log error.to_s
      log error.backtrace.join("\n")
      response = []
    end
  end
end