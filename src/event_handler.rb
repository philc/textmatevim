#!/usr/bin/env ruby
require "rubygems"
require "json"
$LOAD_PATH.push(File.dirname(__FILE__) + "/")
require "keystroke"
require "keymap"

class EventHandler
  attr_accessor :current_mode

  def initialize
    self.current_mode = :insert
  end

  def handle_key_message(message)
    message = JSON.parse(message)
    keystroke = KeyStroke.from_character_and_modifier_flags(message["characters"], message["modifierFlags"])

    command = KeyMap.user_keymap[self.current_mode][keystroke.to_s] rescue nil
    if (command && self.respond_to?(command.to_sym))
      self.send(command.to_sym)
    else
      []
    end
  end

  #
  # Command methods
  # These methods are all possible methods you can map to when defining keybindings.
  def enter_insert_mode
    self.current_mode = :insert
    ["enterInsertMove"]
  end

  def enter_command_mode
    self.current_mode = :command
    ["enterCommandMode"]
  end


  # These could be defined programmatically with define_method, but it turns out to be clearer this way.
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

  def move_to_end_of_document() ["moveToEndOfDocument:"] end

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
      log error.inspect
      response = []
    end
    puts response.to_json
    STDOUT.flush
  end
end