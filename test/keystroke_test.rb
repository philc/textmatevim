require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))
require "keystroke"

class KeyStrokeTest < Test::Unit::TestCase
  def setup
    @no_modifiers = KeyStroke.from_string("a")
    @cmd_shift_a = KeyStroke.from_string("<M-A>")
  end

  context "from_string" do
    should "parse a single character" do
      assert_equal "a", KeyStroke.from_string("a").key
    end

    should "parse a single modifier" do
      ctrl_a = KeyStroke.from_string("<C-a>")
      assert_equal "a", ctrl_a.key
      assert_equal ["C"], ctrl_a.modifiers
    end

    should "parse multiple modifiers" do
      meta_ctrl_a = KeyStroke.from_string("<M-C-a>")
      assert_equal "a", meta_ctrl_a.key
      assert_equal ["C", "M"], meta_ctrl_a.modifiers
    end

    should "parse the shift modifier" do
      assert_equal ["S"], KeyStroke.from_string("A").modifiers
    end

    should "parse special characters like tab" do
      assert_equal "\t", KeyStroke.from_string("<Tab>").key
    end
  end

  should "to_s properly" do
    assert_equal "<C-M-a>", KeyStroke.from_string("<M-C-a>").to_s
    assert_equal "A", KeyStroke.from_string("A").to_s
    assert_equal "<tab>", KeyStroke.from_string("<TAB>").to_s
  end

  context "modifier_flags" do
    should "OR together modifiers into a flags number" do
      assert_equal 1179648, @cmd_shift_a.modifier_flags
    end
  end
end