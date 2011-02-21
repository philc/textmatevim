require "rubygems"
require "test/unit"
require "shoulda"

require File.join(File.dirname(__FILE__), "test_helper")
require "keystroke"

class KeyStrokeTest < Test::Unit::TestCase
  def setup
    @no_modifiers = KeyStroke.from_string("a")
    @cmd_shift_a = KeyStroke.from_string("CMD+shift+a")
  end

  context "from_string" do
    should "parse a single character" do
      assert_equal "a", @no_modifiers.key
      assert_equal [], @no_modifiers.modifiers
    end

    should "parse modifiers" do
      assert_equal "a", @cmd_shift_a.key
      assert_equal ["cmd", "shift"], @cmd_shift_a.modifiers
    end
  end

  context "modifier_flags" do
    should "have modifier_flags default to 256" do
      assert_equal 256, @no_modifiers.modifier_flags
    end

    should "OR together modifiers into a flags number" do
      assert_equal 1179912, @cmd_shift_a.modifier_flags
    end
  end

  context "to_s" do
    should "represent a keystroke as a string" do
      assert_equal "cmd+A", @cmd_shift_a.to_s
    end

    should "properly escape characters like tab" do
      assert_equal "cmd+tab", KeyStroke.from_string("cmd+\t").to_s
    end
  end
end