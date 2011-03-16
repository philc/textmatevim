# This is the JSON encoding and decoding implementation taken from the Rails 2.3.5 ActiveSupport module.
# It uses YAML to help on the decoding side.
#
# We're bundling our own Ruby JSON implementation with TextMateVim because we don't have a good UX around
# depending on a gem. If the user doesn't have the gem installed at runtime, we can only dump to a log file.
# Secondly, asking users to "sudo gem install json" before running TextMateVim is misleading, because
# if TextMate is launched through the Finder, the native OSX ruby gem environment will be used. If the user
# has macports installed, then the gem environment TextMateVim uses will not contain the gem they installed
# via the terminal. If we require gems in the future, we should bundle them with TextMateVim.
#
# We're not bundling the JSON gem with TextMateVim because it's GPL.
require "yaml"

#
# The contents of active_support/core_ext/string/starts_ends_with.rb
#
module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Additional string tests.
      module StartsEndsWith
        def self.append_features(base)
          if '1.8.7 and up'.respond_to?(:start_with?)
            base.class_eval do
              alias_method :starts_with?, :start_with?
              alias_method :ends_with?, :end_with?
            end
          else
            super
            base.class_eval do
              alias_method :start_with?, :starts_with?
              alias_method :end_with?, :ends_with?
            end
          end
        end

        # Does the string start with the specified +prefix+?
        def starts_with?(prefix)
          prefix = prefix.to_s
          self[0, prefix.length] == prefix
        end

        # Does the string end with the specified +suffix+?
        def ends_with?(suffix)
          suffix = suffix.to_s
          self[-suffix.length, suffix.length] == suffix
        end
      end
    end
  end
end


#
# The contents of active_support/json/backends/yaml.rb.
# This uses YAML to decode JSON.
#

module ActiveSupport
  module JSON
    DATE_REGEX = /^(?:\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[ \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?))$/

    module Backends
      module Yaml
        ParseError = ::StandardError
        extend self

        # Converts a JSON string into a Ruby object.
        def decode(json)
          YAML.load(convert_json_to_yaml(json))
        rescue ArgumentError => e
          raise ParseError, "Invalid JSON string"
        end

        protected
          # Ensure that ":" and "," are always followed by a space
          def convert_json_to_yaml(json) #:nodoc:
            require 'strscan' unless defined? ::StringScanner
            scanner, quoting, marks, pos, times = ::StringScanner.new(json), false, [], nil, []
            while scanner.scan_until(/(\\['"]|['":,\\]|\\.)/)
              case char = scanner[1]
              when '"', "'"
                if !quoting
                  quoting = char
                  pos = scanner.pos
                elsif quoting == char
                  if json[pos..scanner.pos-2] =~ DATE_REGEX
                    # found a date, track the exact positions of the quotes so we can remove them later.
                    # oh, and increment them for each current mark, each one is an extra padded space that bumps
                    # the position in the final YAML output
                    total_marks = marks.size
                    times << pos+total_marks << scanner.pos+total_marks
                  end
                  quoting = false
                end
              when ":",","
                marks << scanner.pos - 1 unless quoting
              when "\\"
                scanner.skip(/\\/)
              end
            end

            if marks.empty?
              json.gsub(/\\([\\\/]|u[[:xdigit:]]{4})/) do
                ustr = $1
                if ustr.start_with?('u')
                  [ustr[1..-1].to_i(16)].pack("U")
                elsif ustr == '\\'
                  '\\\\'
                else
                  ustr
                end
              end
            else
              left_pos  = [-1].push(*marks)
              right_pos = marks << scanner.pos + scanner.rest_size
              output    = []
              left_pos.each_with_index do |left, i|
                scanner.pos = left.succ
                output << scanner.peek(right_pos[i] - scanner.pos + 1).gsub(/\\([\\\/]|u[[:xdigit:]]{4})/) do
                  ustr = $1
                  if ustr.start_with?('u')
                    [ustr[1..-1].to_i(16)].pack("U")
                  elsif ustr == '\\'
                    '\\\\'
                  else
                    ustr
                  end
                end
              end
              output = output * " "

              times.each { |i| output[i-1] = ' ' }
              output.gsub!(/\\\//, '/')
              output
            end
          end
      end
    end
  end
end


# 
# The contents of active_supportjson/encoding.rb
#

module ActiveSupport
  module JSON
    def self.encode(string) Encoding.encode(string) end

    module Encoding
      ESCAPED_CHARS = {
        "\010" =>  '\b',
        "\f"   =>  '\f',
        "\n"   =>  '\n',
        "\r"   =>  '\r',
        "\t"   =>  '\t',
        "\e"   =>  '\u001b', # NOTE(philc): Properly escape the "escape" character.
        '"'    =>  '\"',
        '\\'   =>  '\\\\',
        '>'    =>  '\u003E',
        '<'    =>  '\u003C',
        '&'    =>  '\u0026' }

      class << self
        # If true, use ISO 8601 format for dates and times. Otherwise, fall back to the Active Support legacy format.
        attr_accessor :use_standard_json_time_format

        attr_accessor :escape_regex
        attr_reader :escape_html_entities_in_json

        def escape_html_entities_in_json=(value)
          self.escape_regex = \
            if @escape_html_entities_in_json = value
              /[\010\f\n\r\t\e"\\><&]/
            else
              /[\010\f\n\r\t\e"\\]/
            end
        end

        def escape(string)
          string = string.dup.force_encoding(::Encoding::BINARY) if string.respond_to?(:force_encoding)
          json = string.
            gsub(escape_regex) { |s| ESCAPED_CHARS[s] }.
            gsub(/([\xC0-\xDF][\x80-\xBF]|
                   [\xE0-\xEF][\x80-\xBF]{2}|
                   [\xF0-\xF7][\x80-\xBF]{3})+/nx) { |s|
            s.unpack("U*").pack("n*").unpack("H*")[0].gsub(/.{4}/n, '\\\\u\&')
          }
          %("#{json}")
        end

        # Converts a Ruby object into a JSON string.
        def encode(value, options = nil)
          options = {} unless Hash === options
          seen = (options[:seen] ||= [])
          seen << value
          value.to_json(options)
        ensure
          seen.pop
        end
      end

      self.escape_html_entities_in_json = true
    end
  end
end