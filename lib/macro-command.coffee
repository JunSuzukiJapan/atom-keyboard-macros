AtomKeyboardMacrosView = require './atom-keyboard-macros-view'
{CompositeDisposable} = require 'atom'
{keystrokeForKeyboardEvent, keydownEvent, characterForKeyboardEvent} = require './helpers'

class MacroCommand
  @viewInitialized: false
  @findViewInitialized: false

  @resetForToString: ->
    MacroCommand.viewInitialized = false

  # override this method
  execute: ->

  # override this method
  toString: ->

  # override this method
  toSaveString: ->

  @loadStringAsMacroCommands: (text, findAndReplace) ->
    result = {}
    lines = text.split('\n')
    index = 0
    while index < lines.length
      line = lines[index++]
      if line.length == 0
        continue
      if line[0] != '>' or line.length < 2
        console.error 'illegal format when loading macro commands.'
        return null

      name = line.substring(1)
      #console.log('name: ', name)

      cmds = []

      while (index < lines.length) and (lines[index][0] == '*')
        line = lines[index++]
        if line[0] != '*' or line.length < 2
          console.error 'illegal format when loading macro commands.'
          return null

        switch line[1]
          when 'I'
            while (index < lines.length) and (lines[index][0] == ':')
              line = lines[index++]
              if line.length < 2
                continue
              for i in [1..line.length-1]
                event = MacroCommand.keydownEventFromString(line[i])
                cmds.push(new InputTextCommand(event))

          when 'D'
            line = lines[index++]
            if line[0] != ':' or line.length < 2
              console.error 'illegal format when loading macro commands.'
              return null
            cmd = new DispatchCommand('')
            cmd.command_name = line.substring(1) # fix this line
            cmds.push(cmd)

          when 'K'
            while (index < lines.length) and (lines[index][0] == ':')
              line = lines[index++]
              s = line.substring(1)
              event = MacroCommand.keydownEventFromString(s)
              cmds.push(new KeydownCommand(event))

          when ':'
            cmdName = line.substring(2)
            switch cmdName
              when 'RPLALL'
                console.log(findAndReplace)
                line = lines[index++]
                editText = line.substring(3)
                line = lines[index++]
                replaceText = line.substring(3)
                cmds.push(new ReplaceAllCommand(findAndReplace, editText, replaceText))




          else
            console.error 'illegal format loading macro commands.'
            return null

      result[name] = cmds
      # end while

    result

  @keydownEventFromString: (keystroke) ->
    hasCtrl = keystroke.indexOf('ctrl-') > -1
    hasAlt = keystroke.indexOf('alt-') > -1
    hasShift = keystroke.indexOf('shift-') > -1
    hasCmd = keystroke.indexOf('cmd-') > -1
    s = keystroke.replace('ctrl-', '')
    s = s.replace('alt-', '')
    s = s.replace('shift-', '')
    key = s.replace('cmd-', '')
    event = keydownEvent(key, {
      ctrl: hasCtrl
      alt: hasAlt
      shift: hasShift
      cmd: hasCmd
    })
    event

  @findViewInitialize: ->
    result += tabs + "editorElement = atom.views.getView(atom.workspace.getActiveTextEditor())\n"
    result += tabs + "atom.commands.dispatch(editorElement, 'find-and-replace:toggle') # wake up if not active\n"
    result += tabs + "atom.commands.dispatch(editorElement, 'find-and-replace:toggle') # hide\n"
    result += tabs + "panels = atom.workspace.getBottomPanels()\n"
    result += tabs + "for panel in panels\n"
    result += tabs + "  item = panel.item\n"
    result += tabs + "  name = item?.__proto__?.constructor?.name\n"
    result += tabs + "  if name == 'FindView'\n"
    result += tabs + "    @findNext = item.findNext\n"
    result += tabs + "    @findPrevious = item.findPrevious\n"
    result += tabs + "    @findNextSelected = item.findNextSelected\n"
    result += tabs + "    @findPreviousSelected = item.findPreviousSelected\n"
    result += tabs + "    @setSelectionAsFindPattern = item.setSelectionAsFindPattern\n"
    result += tabs + "    @replacePrevious = item.replacePrevious\n"
    result += tabs + "    @replaceNext = item.replaceNext\n"
    result += tabs + "    @replaceAll = item.replaceAll\n"
    result += tabs + "    @findEditor = item.findEditor\n"
    result += tabs + "    @replaceEditor = item.replaceEditor\n"
    result += tabs + "    @replaceAllButton = item.replaceAllButton\n"
    result += tabs + "    @replaceNextButton = item.replaceNextButton\n"
    result += tabs + "    @nextButton = item.nextButton\n"
    result += tabs + "    @regexOptionButton = item.regexOptionButton\n"
    result += tabs + "    @caseOptionButton = item.caseOptionButton\n"
    result += tabs + "    @selectionOptionButton = item.selectionOptionButton\n"
    result += tabs + "    @wholeWordOptionButton = item.wholeWordOptionButton\n"

    MacroCommand.findViewInitialized = true


class InputTextCommand extends MacroCommand
  constructor: (@events) ->

  execute: ->
    for e in @events
      atom.keymaps.simulateTextInput(e)

  toString: (tabs) ->
    result = ''
    for e in @events
      s = atom.keymaps.keystrokeForKeyboardEvent(e)
      result += tabs + 'atom.keymaps.simulateTextInput(\'' + s + '\')\n'
    result

  toSaveString: ->
    result = '*I\n'
    for e in @events
      s = ':' + characterForKeyboardEvent(e) + '\n'
      result += s
    result

class DispatchCommand
  constructor: (keystroke) ->
    editor = atom.workspace.getActiveTextEditor()
    view = atom.views.getView(editor)
    bindings = atom.keymaps.findKeyBindings({keystrokes: keystroke, target: view})
    if bindings.length == 0
      @command_name = ''
      return
    else
      @command_name = bindings.command
      if !@command_name
        #console.log('bindings', bindings)
        bind = bindings[0]
        @command_name = bind.command
    #console.log('@command_name', @command_name)

  execute: ->
    editor = atom.workspace.getActiveTextEditor()
    if editor
      view = atom.views.getView(editor)
      atom.commands.dispatch(view, @command_name)

  toString: (tabs) ->
    result = ''
    if !MacroCommand.viewInitialized
      result += tabs + 'editor = atom.workspace.getActiveTextEditor()\n'
      result += tabs + 'view = atom.views.getView(editor)\n'
      DispatchCommand.viewInitialized = true
    result += tabs + 'atom.commands.dispatch(view, "' + @command_name + '")\n'
    result

  toSaveString: ->
    '*D\n:' + @command_name + '\n'

class KeydownCommand extends MacroCommand
  constructor: (@events) ->

  execute: ->
    for e in @events
      atom.keymaps.handleKeyboardEvent(e)

  toString: (tabs) ->
    result = ''
    if !MacroCommand.viewInitialized
      result += tabs + 'editor = atom.workspace.getActiveTextEditor()\n'
      result += tabs + 'view = atom.views.getView(editor)\n'
      MacroCommand.viewInitialized = true

    for e in @events
      result += tabs + "event = document.createEvent('KeyboardEvent')\n"
      result += tabs + "bubbles = true\n"
      result += tabs + "cancelable = true\n"
      result += tabs + "view = null\n"
      result += tabs + "alt = #{e.altKey}\n"
      result += tabs + "ctrl = #{e.ctrlKey}\n"
      result += tabs + "cmd = #{e.metaKey}\n"
      result += tabs + "shift = #{e.shiftKey}\n"
      result += tabs + "keyCode = #{e.keyCode}\n"
      result += tabs + "keyIdentifier = #{e.keyIdentifier}\n"
      result += tabs + "location ?= KeyboardEvent.DOM_KEY_LOCATION_STANDARD\n"
      result += tabs + "event.initKeyboardEvent('keydown', bubbles, cancelable, view,  keyIdentifier, location, ctrl, alt, shift, cmd)\n"
      result += tabs + "Object.defineProperty(event, 'keyCode', get: -> keyCode)\n"
      result += tabs + "Object.defineProperty(event, 'which', get: -> keyCode)\n"
      result += tabs + "atom.keymaps.handleKeyboardEvent(event)\n"
    result

  toSaveString: ->
    result = '*K\n'
    for e in @events
      result += ':' + keystrokeForKeyboardEvent(e) + '\n'
    result

class FindNextCommand extends MacroCommand
  constructor: (@findAndReplace, @text, @options) ->

  execute: ->
    @findAndReplace.setFindText(@text)
    @findAndReplace.findNext(@options)

  toString: (tabs) ->

  toSaveString: ->

class FindPreviousCommand extends MacroCommand
  constructor: (@findAndReplace, @text, @options) ->

  execute: ->
    @findAndReplace.setText(@text)
    @findAndReplace.findPrevious(@options)

  toString: (tabs) ->

  toSaveString: ->

class FindNextSelectedCommand extends MacroCommand
  constructor: (@findAndReplace, @text) ->

  execute: ->
    @findAndReplace.setText(@text)
    @findAndReplace.findNextSecected()

  toString: (tabs) ->

  toSaveString: ->

class FindPreviousSelectedCommand extends MacroCommand
  constructor: (@findAndReplace, @text) ->

  execute: ->
    @findAndReplace.setFindText(@text)
    @findAndReplace.findPreviousSelected()

  toString: (tabs) ->

  toSaveString: ->

class SetSelectionAsFindPatternCommand extends MacroCommand
  constructor: (@findAndReplace)->

  execute: ->
    @findAndReplace.setSelectionAsFindPattern()

  toString: (tabs) ->

  toSaveString: ->

class ReplacePreviousCommand extends MacroCommand
  constructor: (@findAndReplace, @findText, @replaceText) ->

  execute: ->
    @findAndReplace.setFindText(@findText)
    @findAndReplace.setReplaceText(@replaceText)
    @findAndReplace.replacePrevious()

  toString: (tabs) ->

  toSaveString: ->

class ReplaceNextCommand extends MacroCommand
  constructor: (@findAndReplace, @findText, @replaceText) ->

  execute: ->
    @findAndReplace.setFindText(@findText)
    @findAndReplace.setReplaceText(@replaceText)
    @findAndReplace.replaceNext()

  toString: (tabs) ->

  toSaveString: ->

class ReplaceAllCommand extends MacroCommand
  constructor: (@findAndReplace, @findText, @replaceText) ->

  execute: ->
    @findAndReplace.setFindText(@findText)
    @findAndReplace.setReplaceText(@replaceText)
    @findAndReplace.replaceAll()

  toString: (tabs) ->
    result = ''
    if !MacroCommand.findViewInitialized
      result += MacroCommand.findViewInitialize()
    result += tabs + '@findEditor?.model?.buffer?.lines[0] = "' + @findText + '"\n'
    result += tabs + '@replaceEditor?.model?.buffer?.lines[0] = "' + @replaceText + '"\n'
    result += tabs + "atom.commands.dispatch(editorElement, 'find-and-replace:replace-all')\n"
    result

  toSaveString: ->
    result = '*:RPLALL\n'
    result += ':F:' + @findText + '\n'
    result += ':R:' + @replaceText + '\n'
    result

module.exports =
    MacroCommand: MacroCommand
    InputTextCommand: InputTextCommand
    KeydownCommand: KeydownCommand
    DispatchCommand: DispatchCommand
    FindNextCommand: FindNextCommand
    FindPreviousCommand: FindPreviousCommand
    FindNextSelectedCommand: FindNextSelectedCommand
    FindPreviousSelectedCommand: FindPreviousSelectedCommand
    SetSelectionAsFindPatternCommand: SetSelectionAsFindPatternCommand
    ReplacePreviousCommand: ReplacePreviousCommand
    ReplaceNextCommand: ReplaceNextCommand
    ReplaceAllCommand: ReplaceAllCommand
