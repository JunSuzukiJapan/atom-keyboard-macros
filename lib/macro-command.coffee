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

class KeydownCommand extends MacroCommand
  constructor: (@events) ->

  execute: ->
    for e in @events
      atom.keymaps.handleKeyboardEvent(e)

  toString: (tabs) ->
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
      result += tabs + 'atom.keymaps.handleKeyboardEvent(' + e + ')\n'
    result

module.exports =
    MacroCommand: MacroCommand
    InputTextCommand: InputTextCommand
    KeydownCommand: KeydownCommand
