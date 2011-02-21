#!/usr/bin/env ruby

require "rubygems"
require "json"

def log(str)
  # puts str
  file = File.open("/tmp/event_handler.log", "a") { |file| file.puts(str) }
end
log "TextMateVim event_handler coprocess is online."

while input = STDIN.gets
  log "read line: #{input}"
  puts({ :method => "go" }.to_json)
  STDOUT.flush
end