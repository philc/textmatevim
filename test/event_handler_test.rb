require File.join(File.dirname(__FILE__), "test_helper")
require "event_handler"

class EventHandlerTest < Test::Unit::TestCase
  def stub_keymap(keymap)
    KeyMap.stubs(:user_keymap).returns(keymap)
  end

  def setup
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

  def type_key(key)
    @event_handler.handle_key_message({ :characters => key, :modifierFlags => 0 }.to_json)
  end
end