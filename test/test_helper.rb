require "rubygems"
require "test/unit"
require "shoulda"
require "rr"

$:.push(File.join(File.dirname(__FILE__), "../src"))
$:.push(File.join(File.dirname(__FILE__), "../lib"))

class Test::Unit::TestCase
  include RR::Adapters::TestUnit
end