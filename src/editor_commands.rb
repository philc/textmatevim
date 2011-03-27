module EditorCommands

  def enter_command_mode
    self.current_mode = :command
    [{ "enterMode:" => ["command"] }, "selectNone"]
  end

  def enter_insert_mode
    self.current_mode = :insert
    self.previous_command_stack.clear()
    [{ "enterMode:" => ["insert"] }]
  end

  def enter_visual_mode
    self.current_mode = :visual
    [{ "enterMode:" => ["visual"] }]
  end

  def select_none
    @event["hasSelection"] ? ["moveBackward:"] : []
  end

  # Movement
  def move_backward() ["moveBackward:"] * @number_prefix end
  def move_forward() ["moveForward:"] * @number_prefix end
  def move_down() ["moveDown:"] * @number_prefix end
  def move_up() ["moveUp:"] * @number_prefix end

  # NOTE(philc): "half page" is currently approximated by 6 lines up and down.
  def half_page_down() ["moveDown:"] * 6 * @number_prefix end
  def half_page_up() ["moveUp:"] * 6 * @number_prefix end

  def move_word_backward() ["moveWordBackward:"] * @number_prefix end
  def move_word_forward() ["moveWordForward:"] * @number_prefix end
  def move_to_end_of_word() ["moveToEndOfWord:"] * @number_prefix end

  def move_to_beginning_of_line() ["moveToBeginningOfLine:"] end
  def move_to_end_of_line() ["moveToEndOfLine:"] end

  def move_to_beginning_of_document() ["moveToBeginningOfDocument:"] end
  def move_to_end_of_document() ["moveToEndOfDocument:"] end

  # Movement + selection
  def select_backward() ["moveBackwardAndModifySelection:"] * @number_prefix end
  def select_forward() ["moveForwardAndModifySelection:"] * @number_prefix end
  def select_down() ["moveDownAndModifySelection:"] * @number_prefix end
  def select_up() ["moveUpAndModifySelection:"] * @number_prefix end

  def select_half_page_down() ["moveDownAndModifySelection:"] * 6 * @number_prefix end
  def select_half_page_up() ["moveUpAndModifySelection:"] * 6 * @number_prefix end

  def select_word_backward() ["moveWordBackwardAndModifySelection:"] * @number_prefix end
  def select_word_forward() ["moveWordForwardAndModifySelection:"] * @number_prefix end
  def select_to_end_of_word() ["moveToEndOfWordAndModifySelection:"] * @number_prefix end

  def select_to_beginning_of_line() ["moveToBeginningOfLineAndModifySelection:"] end
  def select_to_end_of_line() ["moveToEndOfLineAndModifySelection:"] end

  def select_to_beginning_of_document() ["moveToBeginningOfDocumentAndModifySelection:"] end
  def select_to_end_of_document() ["moveToEndOfDocumentAndModifySelection:"] end

  #
  # Insertion
  #
  def insert_backward() enter_insert_mode end
  def insert_forward() ["moveForward:"] + enter_insert_mode end

  def insert_at_beginning_of_line() move_to_beginning_of_line + enter_insert_mode end
  def insert_at_end_of_line() move_to_end_of_line + enter_insert_mode end

  def insert_newline_above() ["moveToBeginningOfLine:", "addNewline", "moveUp:"] + enter_insert_mode end
  def insert_newline_below() ["moveToEndOfLine:", "addNewline"] + enter_insert_mode end

  #
  # Cutting
  #
  def cut_backward()
    if @event["hasSelection"]
      ["copySelection", "deleteBackward:", "moveForward:"]
    else
      ["moveBackwardAndModifySelection:"] * @number_prefix + ["copySelection", "deleteBackward:"]
    end
  end

  def cut_forward()
    if @event["hasSelection"]
      ["copySelection", "deleteBackward:"]
    else
      ["moveForwardAndModifySelection:"] * @number_prefix + ["copySelection", "deleteForward:"]
    end
  end

  # Which end of the selection we're modifying first matters. After hitting undo, we want
  # the cursor to end up where it was prior to this command.
  def cut_word_forward()
    select_word_forward_including_whitespace(@number_prefix) + ["copySelection", "deleteBackward:"] +
        restore_cursor_position()
  end

  def cut_word_backward()
    ["moveWordBackwardAndModifySelection:"] * @number_prefix + ["copySelection", "deleteBackward:"]
  end

  def cut_line()
    ["moveToBeginningOfLine:"] + ["moveDownAndModifySelection:"] * @number_prefix +
        ["copySelection", "deleteBackward:"]
  end

  def cut_to_beginning_of_line()
    ["moveToBeginningOfLineAndModifySelection:", "copySelection", "deleteForward:"]
  end

  def cut_to_end_of_line()
    ["moveToEndOfLineAndModifySelection:", "copySelection", "deleteBackward:"] + restore_cursor_position()
  end

  #
  # Copying
  #
  def copy_selection() ["copySelection"] end
  def copy_forward() ["moveForwardAndModifySelection:", "copySelection"] + restore_cursor_position() end

  # VIM will move your cursor to the left when you execute this copy.
  def copy_backward()
    ["moveBackwardAndModifySelection:"] * @number_prefix + ["copySelection", "moveForward:", "moveBackward:"]
  end

  def copy_word_forward()
    ["moveWordForwardAndModifySelection:"] * @number_prefix + ["copySelection"] + restore_cursor_position()
  end

  # VIM will move your cursor to the left when you execute this copy.
  def copy_word_backward()
    ["moveWordBackwardAndModifySelection:"] * @number_prefix + ["copySelection"] + restore_cursor_position() +
        ["moveWordBackward:"]
  end

  def copy_line()
    # Note that we want to capture the newline at the end of the line, so when we paste this, it's treated
    # as a line-paste.
    commands = ["moveToBeginningOfLine:"] + ["moveDownAndModifySelection:"] * @number_prefix +
        ["copySelection"]
    commands.each { |command| send_message(command => []) }

    # Note that we have to add a newline onto the end of the selection because if we paste this selection,
    # we want the paste to be treated like a line paste. The copied selection may not have a newline if
    # we've copied the last line of the file.
    clipboard = send_message("getClipboardContents" => [])["clipboardContents"]
    if (clipboard[-1].chr != "\n")
      clipboard += "\n"
      send_message("setClipboardContents:" => [clipboard])
    end

    restore_cursor_position()
  end

  #
  # Tabs
  #
  def next_tab() [{ "clickMenuItem:" => ["Navigation > Next File Tab"] }] * @number_prefix end
  def previous_tab() [{ "clickMenuItem:" => ["Navigation > Previous File Tab"] }] * @number_prefix end

  #
  # Other
  #

  # About pasting:
  #
  # When the clipboard being pasted ends with a newline, treat it as a "line paste". In Vim that means the
  # clipboard will be pasted on its own line instead of in the middle of the line you're currently on.
  #
  # The cursor position after pasting a full line is not quite correct. It's supposed to be set to the
  # first non-whitespace character of the newly pasted text. We're using moveWordForward after the pace to set
  # the cursor position there, but Textmate will skip some characters (like braces) when using moveWordForward
  def paste_before()
    clipboard = send_message("getClipboardContents" => [])["clipboardContents"]
    if clipboard[-1].chr == "\n"
      ["moveToBeginningOfLine:", "paste"] + restore_cursor_position + ["moveToBeginningOfLine:"] +
          (is_whitespace?(clipboard[0].chr) ? ["moveWordForward:"] : [])
    else
      ["paste", "moveForward:"]
    end
  end

  def paste_after()
    clipboard = send_message(:getClipboardContents => [])["clipboardContents"]
    if clipboard[-1].chr == "\n"
      ["moveDown:", "moveToBeginningOfLine:", "paste"] + restore_cursor_position + ["moveDown:"] +
          ["moveToBeginningOfLine:"] + (is_whitespace?(clipboard[0].chr) ? ["moveWordForward:"] : [])
    else
      (@event["hasSelection"] ? [] : ["moveForward:"]) + ["paste", "moveForward:"]
    end
  end

  def undo()
    # If we're undoing a previous command which mutated the document, restore the user's cursor position.
    saved_state = nil
    @number_prefix.times { saved_state = previous_command_stack.pop }
    ["undo"] * @number_prefix +
        (saved_state ? set_cursor_position(saved_state[:line], saved_state[:column]) : [])
  end

  def set_cursor_position(line, column)
    # On the Textmate text view, we have access to a function which lets us set the position of the boundary
    # of one end of the current selection. To collapse that selection, we need to know which end the cursor
    # is on. As a brute force approach, set the selection to the beginning of the document and then move left.
    # This is sure to collapse the selection completely. Doing so can change the window's vertical scroll
    # position, so we must restore that scroll position.
    [{ "setSelection:column:" => [0, 0] }, "moveBackward:",
     { "setSelection:column:" => [line + 1, column + 1] }, "moveForward:",
     { "scrollTo:y:" => [@event["scrollX"], @event["scrollY"]] }]
  end

  # Restores the cursor position to whatever it was when this command began executing. Useful for the copy
  # commands, which heavily modify the cursor position when building up a selection to copy.
  def restore_cursor_position() set_cursor_position(@event["line"], @event["column"]) end

  def select_word_forward_including_whitespace(how_many_words)
    how_many_words.times { send_message("moveWordForwardAndModifySelection:" => []) }
    selection = send_message("getSelectedText" => [])["selectedText"]

    # We're going to keep moving the cursor forward as long as it contains whitespace. Note that Textmate will move the
    # cursor by two characters when moving through runs of whitespace, as if you're moving by tabs.
    trailing_selection_is_whitespace = true
    while trailing_selection_is_whitespace
      send_message("moveForwardAndModifySelection:" => [])
      trailing_selection = send_message("getSelectedText" => [])["selectedText"]
      trailing_selection = trailing_selection[selection.size..-1] || ""
      trailing_selection_is_whitespace = (trailing_selection =~ /^\s+$/)
      if (!trailing_selection_is_whitespace && trailing_selection.size > 0)
        # Undo the last "move forward" command we sent.
        send_message("moveBackwardAndModifySelection:" => [])
      end
    end

    []
  end

  # This is used for development. This will reload the Ruby parts of textmatevim in-process, without having
  # to restart Textmate itself. This allows you to iteratively tweak how commands work.
  def reload_textmatevim
    src_path = ENV["TEXTMATEVIM_SRC_PATH"]
    unless src_path
      log "TEXTMATEVIM_SRC_PATH not found. Define it."
      return []
    end
    load(File.join(src_path, "editor_commands.rb"))
    load(File.join(src_path, "event_handler.rb"))
    []
  end

  def is_whitespace?(character) character =~ /\s/ end
end
