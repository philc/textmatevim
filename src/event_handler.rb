#!/usr/bin/env ruby

require "rubygems"
require "json"
require File.join(File.dirname(__FILE__), "keystroke")

def log(str)
  # puts str
  file = File.open("/tmp/event_handler.log", "a") { |file| file.puts(str) }
end
log "TextMateVim event_handler coprocess is online."

while message = STDIN.gets
  message = JSON.parse(message)
  keystroke = KeyStroke.from_character_and_modifier_flags(message["characters"], message["modifierFlags"])
  result = case keystroke.to_s
    when "h": ["moveBackward:"]
    when "l": ["moveForward:"]
    when "j": ["moveDown:"]
    when "k": ["moveUp:"]
    when "ctrl+d": ["moveDown:"] * 6
    when "ctrl+u": ["moveUp:"] * 6
  else
    []
  end

  puts result.to_json
  STDOUT.flush
end