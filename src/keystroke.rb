# Represents a keystroke consisting of a key
# and its modifiers.
class KeyStroke
  include Comparable
  private

  # Translation of modifier keys to their int modifier flag.
  # http://developer.apple.com/documentation/Cocoa/Reference/ApplicationKit/Classes/
  # nsevent_Class/Reference/Reference.html#//apple_ref/occ/instm/NSEvent/modifierFlags
  AlphaShiftKeyMask = 1 << 16
  ShiftKeyMask      = 1 << 17
  ControlKeyMask    = 1 << 18
  AlternateKeyMask  = 1 << 19
  CommandKeyMask    = 1 << 20
  NumericPadKeyMask = 1 << 21
  HelpKeyMask       = 1 << 22
  FunctionKeyMask   = 1 << 23

  # Refer to Vim's readable key mapping: http://vim.wikia.com/wiki/Mapping_keys_in_Vim_-_Tutorial_(Part_2)
  @@readable_to_key = {
    "enter" => "\r",
    "tab" => "\t",
    "space" => " ",
    "esc" => "\e",
    "backspace" => "\b"
  }
  @@key_to_readable = @@readable_to_key.invert

  MODIFIER_MAP = {
    "M" => CommandKeyMask,
    "C" => ControlKeyMask,
    "A" => AlternateKeyMask,
    "S" => ShiftKeyMask,
    # Unused:
    "fn" => FunctionKeyMask,
    "numpad" => NumericPadKeyMask
  }

  public

  # An array of zero or more modifiers
  attr_accessor :modifiers
  attr_accessor :key

  def initialize()
    @modifiers = []
  end

  # Returns a keystroke from a string description of the keystroke.
  # The keystroke_string should be in the form of "z" or "<M-h>".
  def self.from_string(keystroke_string)
    keystroke = KeyStroke.new

    char = keystroke_string[0].chr
    if char == "<"
      raise "Invalid keystroke" unless keystroke_string.match(/<[^<>]+>/)
      keystroke_string = keystroke_string[1..-2] # Strip off the <>
      modifiers = keystroke_string.split("-")[0..-2]
      keystroke.modifiers = modifiers.sort
      # Extract the keystroke which follows all of those modifiers.
      key = keystroke_string.match(/(?:.\-)*(.+)/)[1]
      keystroke.key = @@readable_to_key[key.downcase] || key
    else
      raise "keystroke should contain only one character" if keystroke_string.size > 1
      keystroke.key = char
    end

    if (keystroke.key.size == 1 && keystroke.key.downcase != keystroke.key)
      keystroke.modifiers = (keystroke.modifiers + ["S"]).uniq.sort
      keystroke.key.downcase!
    end

    keystroke
  end

  # Converts the key's modifiers to a bitmask, for use with Cocoa's key event APIs.
  def modifier_flags(include_shift = true)
    modifiers = self.modifiers.dup
    modifiers.delete("S") unless include_shift
    flags = 0
    modifiers.each { |modifier| flags = flags | MODIFIER_MAP[modifier] }
    flags
  end

  def self.from_character_and_modifier_flags(character, modifier_flags)
    keystroke = KeyStroke.new
    keystroke.modifiers = flags_to_modifiers(modifier_flags)
    keystroke.key = character if character
    keystroke
  end

  def self.flags_to_modifiers(modifier_flags)
    modifier_keys = {
      "M" => modifier_flags & CommandKeyMask != 0,
      "C" => modifier_flags & ControlKeyMask != 0,
      "A" => modifier_flags & AlternateKeyMask != 0,
      "S" => modifier_flags & ShiftKeyMask != 0
    }
    modifier_keys.reject! { |key, value| value == false }.keys.sort
  end

  def to_s
    key = self.key.dup
    modifiers = self.modifiers.dup
    if modifiers.include?("S")
      modifiers.delete("S")
      key.upcase!
    end

    if modifiers.empty?
      @@key_to_readable[key] ? "<#{@@key_to_readable[key]}>" : key
    else
      "<" + modifiers.map { |modifier| modifier + "-" }.join + (@@key_to_readable[key] || key) + ">"
    end
  end

  def <=>(other)
    to_s <=> other.to_s
  end
end
