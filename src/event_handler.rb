#!/usr/bin/env ruby
#
# This event handler receives messages over stdin with the user's keydown events, and it determines which
# actions to take in the editor based on the user's key mappings. It sends messages over stdout.
#
# This is spawned by the TextMateVim objective-C plugin, which opens pipes to this process to communicate
# with it.

require "rubygems"
# TODO(philc): Vendor this gem.
require "json"
$LOAD_PATH.push(File.dirname(__FILE__) + "/")
require "keystroke"
require "keymap"
require "ui_helper"
require "editor_commands"

ENABLE_DEBUG_LOGGING = false

class EventHandler
  include EditorCommands

  attr_accessor :current_mode
  # The list of keys which have been typed. We check this each keystroke to see a full command has been typed.
  attr_accessor :key_queue
  # We keep track of previous commands so that we can unwind them with our undo implementation.
  attr_accessor :previous_command_stack

  # TODO(philc): This limit should really be based on the longest of the user's mapped commands plus room
  # for number prefixes.
  KEY_QUEUE_LIMIT = 5

  # This is how many mutating commands we keep track of, for the purposes of restoring the original cursor
  # position when these commands get unwound via our implementation of undo.
  UNDO_STACK_SIZE = 5

  MUTATING_COMMANDS = %W(cut_backward cut_forward cut_word_forward cut_word_backward cut_line
       cut_to_beginning_of_line cut_to_end_of_line paste_before paste_after)

  def initialize
    self.current_mode = :insert
    self.key_queue = []
    self.previous_command_stack = []
  end

  # Handles a message from the TextMate process.
  # - message: a JSON string, where message["message"] indiciates the type of message.
  def handle_message(message)
    message_json = JSON.parse(message)
    case message_json["message"]
    when "keydown": handle_keydown_message(message_json)
    when "getKeybindings": handle_get_keybindings_message
    end
  end

  # Interprets the user's keystroke event in light of the current mode. This sends a list of commands to
  # TextMate, finally ending with either a "suppressKeystroke" or a "passThroughKeystroke" command.
  def handle_keydown_message(message)
    # @event is used by some commands in editor_commands.rb.
    @event = message
    keystroke = KeyStroke.from_character_and_modifier_flags(@event["characters"], @event["modifierFlags"])

    key_queue.push(keystroke.to_s)
    key_queue.shift if key_queue.size > KEY_QUEUE_LIMIT

    @number_prefix, commands = commands_for_key_queue()
    # Cap the number of commands we'll execute in case someone accidentally types "999x".
    @number_prefix = [50, @number_prefix].min if @number_prefix
    if commands && !commands.empty?
      # Each of our command methods should return an array of methods for TextMateVim to invoke on the
      # TextMate text editor.
      messages = commands.map { |command| execute_command(command) }.flatten
      messages.each do |message|
        # Commands can either be a String (a method name) or a Hash (method name => [arguments])
        if message.is_a?(Hash)
          send_message(message)
        else
          send_message(message => [])
        end
      end
      send_message({ :suppressKeystroke => [] }, false)
    elsif key_queue_contains_partial_command?
      # Note that the queue can contain partial commands even in insert mode, so we may be suppressing
      # keystrokes in insert mode. This suppression logic doesn't account for number prefixes, by design.
      send_message({ :suppressKeystroke => [] }, false)
    else
      # This key is not bound to any command. For insert mode, pass it through. In other modes, suppress it.
      should_pass_through = (self.current_mode == :insert || keystroke.modifiers.include?("M"))
      send_message({ (should_pass_through ? :passThroughKeystroke : :suppressKeystroke) => [] }, false)
    end
  end

  # The commands for the given key queue.
  # Returns a pair containing the number prefix (or 1, if there was no number prefix) typed prior to any
  # commands (e.g. "2" in "2j"), and the list of user specified commands matching the current queue of keys.
  # Note that multiple commands can be specified as the target of a keybinding, e.g.
  # "h" => ["move_forward", "cut_forward"].
  def commands_for_key_queue
    (0).upto(self.key_queue.size - 1) do |i|
      key_sequence = self.key_queue[i..-1].map(&:to_s).join
      number_prefix = key_sequence.scan(/^[1-9][0-9]*/)[0] # 0 can be used in normal mappings.
      key_sequence = key_sequence[number_prefix.size..-1] if number_prefix
      commands = Array(KeyMap.user_keymap[self.current_mode][key_sequence])
      return [(number_prefix || 1).to_i, commands] unless commands.empty?
    end
    [0, []]
  end

  # Executes a single command and returns the responses which should be sent to TextMate. The cursor's
  # original position is saved when executing mutating commands, so we can restore it if the user undos.
  def execute_command(command)
    raise "Unrecognized command: #{command}" unless self.respond_to?(command.to_sym)
    self.key_queue = []
    result = self.send(command.to_sym)
    if MUTATING_COMMANDS.include?(command)
      # Save cursor position prior to the edit, so we can restore later if the user undos.
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
  # [[key, modifier_flags], ...] where modifier_flags is an int. These bindings will be used by TextMateVim
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
  file = File.open("/tmp/textmatevim.log", "a") { |file| file.puts(str) }
end

# More verbose logging used during development.
def debug_log(str) log(str) if ENABLE_DEBUG_LOGGING end

# Sends a message and waits for a response.
# - message: a hash representing the message. This will be converted to JSON.
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
  log "TextMateVim event_handler.rb coprocess has been started."

  load "default_config.rb"
  load_user_config_file
  event_handler = EventHandler.new
  while message = STDIN.gets
    begin
      debug_log "received message: #{message}"
      messages = event_handler.handle_message(message)
      debug_log "response: #{response.inspect}"
    rescue => error
      log error.to_s
      log error.backtrace.join("\n")
    end
  end
end