require File.join(File.dirname(__FILE__), "test_helper")
require "event_handler"

class EventHandlerTest < Test::Unit::TestCase
  def stub_keymap(keymap)
    KeyMap.stubs(:user_keymap).returns(keymap)
  end

  context "stubbed keymap" do
    setup do
      stub_keymap({ :insert => { "h" => "move_backward" } })
      @event_handler = EventHandler.new
    end

    should "respond with the correct command from the user's keymap" do
      assert_equal ["moveBackward:"], type_key("h")
    end

    should "transition to insert mode from command mdoe" do
      @event_handler.current_mode = :command
      stub_keymap(:command => { "i" => "enter_insert_mode" })
      type_key "i"
      assert_equal :insert, @event_handler.current_mode
    end

    should "transition to command mode from insert mode" do
      @event_handler.current_mode = :insert
      stub_keymap(:insert => { "<esc>" => "enter_command_mode" })
      type_key "\e"
      assert_equal :command, @event_handler.current_mode
    end

    should "queue up keystrokes and execute commands consistent of multiple keystrokes" do
      @event_handler.current_mode = :command
      stub_keymap(:command => { "gg" => "move_to_beginning_of_document" })
      # The first key should result in a noOp, because it might turn out to be part of the "gg" command.
      assert_equal ["noOp"], type_key("g")
      assert_equal ["moveToBeginningOfDocument:"], type_key("g")
      assert_equal [], @event_handler.key_queue
    end
  end

  context "keymap" do
    should "parse out multiple keystrokes from a string" do
      assert_equal "x<C-M-y>Z", KeyMap.keystrokes_from_string("x<M-C-y>Z").map(&:to_s).join
    end
  end

  def type_key(key)
    @event_handler.handle_key_message({ :characters => key, :modifierFlags => 0 }.to_json)
  end
end