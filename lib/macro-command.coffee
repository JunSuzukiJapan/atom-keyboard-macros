AtomKeyboardMacrosView = require './atom-keyboard-macros-view'
{CompositeDisposable} = require 'atom'

class MacroCommand
  constructor: (@events) ->

  execute: ->

class InputTextCommand extends MacroCommand
  execute: ->
    for e in @events
      atom.keymaps.simulateTextInput(e)


class KeydownCommand extends MacroCommand
  execute: ->
    for e in @events
      atom.keymaps.handleKeyboardEvent(e)

module.exports =
    MacroCommand: MacroCommand
    InputTextCommand: InputTextCommand
    KeydownCommand: KeydownCommand
