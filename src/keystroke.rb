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

  @@readable_to_key = {
    "enter" => "\r",
    "tab" => "\t",
    "space" => " ",
    "escape" => "\e",
    "backspace" => "\b"
  }
  @@key_to_readable = @@readable_to_key.invert

  MODIFIER_MAP = {
    "cmd" => CommandKeyMask,
    "ctrl" => ControlKeyMask,
    "fn" => FunctionKeyMask,
    "opt" => AlternateKeyMask,
    "shift" => ShiftKeyMask,
    "numpad" => NumericPadKeyMask
  }

  public

  # An array of zero or more modifiers
  attr_accessor :modifiers
  attr_accessor :key

  def initialize
    @modifiers = []
  end

  # Returns a keystroke from a string description of the keystroke.
  # The keystroke_string should be in the form of "CMD+H".
  def self.from_string(keystroke_string)
    keystroke = KeyStroke.new
    parts = keystroke_string.downcase.split("+")
    keystroke.key = parts.last
    keystroke.key = @@readable_to_key[keystroke.key] if @@readable_to_key[keystroke.key]
    if parts.size > 1
      keystroke.modifiers = parts[0..-2]
    end

    # We must special case the arrow keys. It's nice to be able to say "up" in your keystroke_string,
    # but unfortunately "up" is a combination of the up key and the function and numpad modifiers,
    # at least on the alulminimum bluetooth keyboard.
    if ["up", "down", "right", "left"].include?(keystroke.key)
      keystroke.modifiers += ["fn"]
    end
    keystroke.modifiers.sort!
    keystroke
  end

  def modifier_flags
    return 256 if modifiers.empty?
    # When cocoa sends us events with modifiers, they have the 3rd bit set for some reason. Unclear why.
    # Adding 8 to our modifier flags to match Cocoa's.
    flags = 256 + 8
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
      "cmd" => modifier_flags & CommandKeyMask != 0,
      "ctrl" => modifier_flags & ControlKeyMask != 0,
      "fn" => modifier_flags & FunctionKeyMask != 0,
      "opt" => modifier_flags & AlternateKeyMask != 0,
      "shift" => modifier_flags & ShiftKeyMask != 0
    }
    modifier_keys.reject! { |key, value| value == false }.keys.sort
  end

  def text
    # The text associated with this keystroke. Usually it's the character corresponding to the keycode of the
    # keystroke, but its value can be set to more than one character when we're executing a snippet.
    @text || (is_modifier? ? nil : self.key)
  end

  def text=(value)
    @text = value
  end

  def to_s
    parts = []

    if key
      if is_modifier?
        parts = [translate_to_modifier(key)]
      else
        parts = modifiers.dup
        # inspect will properly escape characters like "\t", but it will include "" around
        # the key. Remove them.
        escaped = key.inspect[1..-2]
        parts.push(@@key_to_readable[key] || escaped)

        # When shift is used with a regular character, like shift+g, just translate that to "G".
        # When shift is used with a non-regular character, leave it on (e.g. shift+UP)
        # Instead of returning "shift+g", 
        if (parts.include?("shift") && escaped.downcase != escaped.upcase)
          parts.delete("shift")
          parts[-1] = parts.last.upcase
        end
      end
    else
      parts = modifiers.dup
    end

    return parts.join("+")
  end

  def <=>(other)
    to_s <=> other.to_s
  end

  def is_modifier?
    translated_key = translate_to_modifier(self.key)
    translated_key and MODIFIER_MAP.has_key?(translated_key)
  end

  def translate_to_modifier(key)
    # The key is going to be precise, like "left_cmd". Translate this into "cmd" if possible.
    key = key.sub("left_", "").sub("right_", "")
    return nil unless %w(cmd ctrl fn opt shift numpad).include?(key)
    key
  end
end
