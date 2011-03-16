# A lightweight JSON implementation which offers mostly the same API as the ruby JSON gem.
# This delegates most of the work to ActiveRecord's YAML-based JSON implementation.
require "activesupport_json"

module JSON
  def self.parse(string)
    ActiveSupport::JSON::Backends::Yaml.decode(string)
  end

  def self.escape(string)
    ActiveSupport::JSON::Encoding.escape(string)
  end
end

class Hash
  def to_json
    result = "{"
    result << self.map { |key, value| %Q(#{JSON.escape(key.to_s)}: #{value.to_json}) }.join(",")
    result << "}"
    result
  end unless method_defined?(:to_json)
end

class Array
  def to_json
    "[#{self.map { |value| value.to_json }.join(", ")}]"
  end
end

class Fixnum
  def to_json() to_s end
end

class Object
  def to_json() JSON.escape(self.to_s) end
end

# A few ad-hoc test cases for ensuring that our cheap-o JSON implementation achieves the expected output.
if $0 == __FILE__
  h1 = { "nested hash" => [1, "a", 2] }
  h2 = { "\e" => "should be escaped", "nested" => h1 }

  output1 = h1.to_json
  output2 = h2.to_json

  puts output1.inspect
  puts output2.inspect

  # require "rubygems"
  # require "json"
  puts JSON.parse(output1).inspect
  puts JSON.parse(output2).inspect
end
