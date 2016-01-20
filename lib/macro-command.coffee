AtomKeyboardMacrosView = require './atom-keyboard-macros-view'
{CompositeDisposable} = require 'atom'
{keydownEvent} = require './helpers'

class MacroCommand
  execute: ->

class InputTextCommand extends MacroCommand
  constructor: (@events) ->

  execute: ->
    for e in @events
      atom.keymaps.simulateTextInput(e)

  toString: (tabs) ->
    result = ''
    for e in @events
      s = atom.keymaps.keystrokeForKeyboardEvent(e)
      #console.log('e: ', e, s)
      result += tabs + 'atom.keymaps.simulateTextInput(' + e + ')\n'
    result

class DispatchCommand
  @viewInitialized: false

  constructor: (keystroke) ->
    bindings = atom.keymaps.findKeyBindings({keystrokes: keystroke})
    if bindings.length == 0
      @command_name = ''
      return
    else
      @command_name = bindings.command
      if !@command_name
        bind = bindings[bindings.length - 1]
        @command_name = bind.command
    #console.log('@command_name', @command_name)

  execute: ->
    editor = atom.workspace.getActiveTextEditor()
    if editor
      view = atom.views.getView(editor)
      atom.commands.dispatch(view, @command_name)

  @resetForToString: ->
    DispatchCommand.viewInitialized = false

  toString: (tabs) ->
    result = ''
    if !DispatchCommand.viewInitialized
      result += tabs + 'editor = atom.workspace.getActiveTextEditor()\n'
      result += tabs + 'view = atom.views.getView(editor)\n'
      DispatchCommand.viewInitialized = true
    result += tabs + 'atom.commands.dispatch(view, "' + @command_name + '")\n'
    result


class KeydownCommand extends MacroCommand
  constructor: (@events) ->

  execute: ->
    for e in @events
      atom.keymaps.handleKeyboardEvent(e)

  toString: (tabs) ->
    return '\n'
    ###
    result = ''
    for e in @events
      k = keydownEvent(e.keyIdentifier, {
          ctrl: e.ctrlKey
          shift: e.shiftKey
          alt: e.altKey
          cmd: e.metaKey
        })
      k.which = e.which
      k.keyCode = e.keyCode
      result += tabs + 'atom.keymaps.handleKeyboardEvent(' + k + ')\n'
    result
    ###

module.exports =
    MacroCommand: MacroCommand
    InputTextCommand: InputTextCommand
    KeydownCommand: KeydownCommand
    DispatchCommand: DispatchCommand
