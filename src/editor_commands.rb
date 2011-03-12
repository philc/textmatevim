module EditorCommands

  def enter_command_mode
    self.current_mode = :command
    log "hasselection?"
    log @event["hasSelection"]
    [{ "enterMode:" => ["command"] }] + (@event["hasSelection"] ? ["moveBackward:"] : [])
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
    @event["hasSelection"] ? ["moveBackward:"] : no_op_command()
  end

  # Movement
  def move_backward() ["moveBackward:"] end
  def move_forward() ["moveForward:"] end
  def move_down() ["moveDown:"] end
  def move_up() ["moveUp:"] end

  def half_page_down() ["moveDown:"] * 6 end
  def half_page_up() ["moveUp:"] * 6 end

  def move_word_backward() ["moveWordBackward:"] end
  def move_word_forward() ["moveWordForward:"] end
  def move_to_end_of_word() ["moveToEndOfWord:"] end

  def move_to_beginning_of_line() ["moveToBeginningOfLine:"] end
  def move_to_end_of_line() ["moveToEndOfLine:"] end

  def move_to_beginning_of_document() ["moveToBeginningOfDocument:"] end
  def move_to_end_of_document() ["moveToEndOfDocument:"] end

  # Movement + selection
  def select_backward() ["moveBackwardAndModifySelection:"] end
  def select_forward() ["moveForwardAndModifySelection:"] end
  def select_down() ["moveDownAndModifySelection:"] end
  def select_up() ["moveUpAndModifySelection:"] end

  def select_half_page_down() ["moveDownAndModifySelection:"] * 6 end
  def select_half_page_up() ["moveUpAndModifySelection:"] * 6 end

  def select_word_backward() ["moveWordBackwardAndModifySelection:"] end
  def select_word_forward() ["moveWordForwardAndModifySelection:"] end
  def select_to_end_of_word() ["moveToEndOfWordAndModifySelection:"] end

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
  def cut_backward() ["moveBackwardAndModifySelection:", "copySelection", "deleteBackward:"] end
  def cut_forward()
    @event["hasSelection"] ?
        ["copySelection", "deleteBackward:", "moveForward:"] :
        ["moveForwardAndModifySelection:", "copySelection", "deleteForward:"]
  end

  # Which end of the selection we're modifying first matters. After hitting undo, we want
  # the cursor to end up where it was prior to this command.
  def cut_word_forward()
    ["moveWordForward:", "moveWordBackwardAndModifySelection:", "copySelection",
     "deleteForward:"]
  end

  def cut_word_backward()
    ["moveWordBackwardAndModifySelection:", "copySelection", "deleteBackward:"]
  end

  def cut_line()
    ["moveToBeginningOfLine:", "moveDownAndModifySelection:", "copySelection", "deleteBackward:"]
  end

  def cut_to_beginning_of_line()
    ["moveToBeginningOfLineAndModifySelection:", "copySelection", "deleteForward:"]
  end

  def cut_to_end_of_line()
    ["moveToEndOfLineAndModifySelection:", "copySelection", "deleteBackward:"]
  end

  #
  # Copying
  #
  def copy_selection() ["copySelection"] end
  def copy_forward() ["moveForwardAndModifySelection:", "copySelection"] + restore_cursor_position() end

  # VIM will move your cursor to the left when you execute this copy.
  def copy_backward()
    ["moveBackwardAndModifySelection:", "copySelection", "moveForward:", "moveBackward:"]
  end

  def copy_word_forward() ["moveWordForwardAndModifySelection:", "copySelection"] + restore_cursor_position() end

  # VIM will move your cursor to the left when you execute this copy.
  def copy_word_backward()
    ["moveWordBackwardAndModifySelection:", "copySelection"] + restore_cursor_position + ["moveWordBackward:"]
  end

  def copy_line()
    ["moveToBeginningOfLine:", "moveToEndOfLineAndModifySelection:", "copySelection"] +
        restore_cursor_position()
  end

  #
  # Tabs
  #
  def next_tab() ["nextTab"] end
  def previous_tab() ["previousTab"] end

  #
  # Other
  #
  def paste_before() ["paste", "moveForward:"] end

  def paste_after()
    (@event["hasSelection"] ? [] : ["moveForward:"]) + ["paste", "moveForward:"]
  end

  def undo()
    # If we're undoing a previous command which mutated the document, restore the user's cursor position.
    saved_state = previous_command_stack.pop
    ["undo"] + (saved_state ? set_cursor_position(saved_state[:line], saved_state[:column]) : [])
  end

  def set_cursor_position(line, column)
    # On the Textmate text view, we have access to a function which lets us set the position of the boundary
    # of one end of the current selection. To collapse that selection, we need to know which end the cursor
    # is on. As a brute force approach, set the selection to the beginning of the document and then move left.
    # Doing so can change the window's vertical scroll position, so we'll restore that.
    [{ "setSelection:column:" => [0, 0] }, "moveBackward:",
     { "setSelection:column:" => [line + 1, column + 1] }, "moveForward:",
     { "scrollTo:" => [@event["scrollY"]] }]
  end

  # Restores the cursor position to whatever it was when this command began executing. Useful for the copy
  # commands, which modify the cursor position to build a selection to copy.
  def restore_cursor_position() set_cursor_position(@event["line"], @event["column"]) end

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
    return no_op_command
  end
end
