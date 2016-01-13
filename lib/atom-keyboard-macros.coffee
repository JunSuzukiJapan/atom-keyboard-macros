AtomKeyboardMacrosView = require './atom-keyboard-macros-view'
RepeatCountView = require './repeat-count-view'
{CompositeDisposable} = require 'atom'
{normalizeKeystrokes, keystrokeForKeyboardEvent, isAtomModifier, keydownEvent, characterForKeyboardEvent} = require './helpers'
Compiler = require './keyevents-compiler'

module.exports = AtomKeyboardMacros =
  atomKeyboardMacrosView: null
  messagePanel: null
  repeatCountView: null
  repeatCountPanel: null
  subscriptions: null

  keyCaptured: false
  eventListener: null
  keySequence: []
  compiler: null
  compiledCommands: null

  activate: (state) ->
    @atomKeyboardMacrosView = new AtomKeyboardMacrosView(state.atomKeyboardMacrosViewState)
    @messagePanel = atom.workspace.addBottomPanel(item: @atomKeyboardMacrosView.getElement(), visible: false)

    @repeatCountView = new RepeatCountView(state.repeatCountViewState)
    @repeatCountPanel = atom.workspace.addModalPanel(item: @repeatCountView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register commands
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:start_kbd_macro': => @start_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:end_kbd_macro': => @end_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:call_last_kbd_macro': => @call_last_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:repeat_last_kbd_macro': => @repeat_last_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:toggle': => @toggle()

    # add event listener
    @eventListener = @newHandleKeyboardEvent.bind(this)

    @repeatCountView.setCallback(@onGetRepeatCount.bind(this))

    @keyCaptured = false
    @compiler = new Compiler()

  deactivate: ->
    @repeatCountPanel.destroy()
    @messagePanel.destroy()
    @subscriptions.dispose()
    @repeatCountView.destroy()
    @atomKeyboardMacrosView.destroy()
    window.removeEventListener('keydown', @eventListener, true)

  serialize: ->
    atomKeyboardMacrosViewState: @atomKeyboardMacrosView.serialize()
    repeatCountViewState: @repeatCountView.serialize()

  toggle: ->
    if @messagePanel.isVisible()
      @messagePanel.hide()
    else
      @messagePanel.show()

  setText: (text) ->
    @atomKeyboardMacrosView.setText(text)
    @messagePanel.show()

  newHandleKeyboardEvent: (e) ->
    @keySequence.push(e)

  start_kbd_macro: ->
    this.setText('start recording keyboard macros...')
    if @keyCaptured
      #beep()
      return
    @keySequence = []
    @keyCaptured = true
    window.addEventListener('keydown', @eventListener, true)

  end_kbd_macro: ->
    window.removeEventListener('keydown', @eventListener, true)
    @keyCaptured = false
    this.setText('end recording keyboard macros.')
    @compiledCommands = @compiler.compile(@keySequence)

  # Private
  execute_macro_once: ->
    for cmd in @compiledCommands
      cmd.execute()

  call_last_kbd_macro: ->
    if @keyCaptured
      #beep()
      return
    if !@keySequence || @keySequence.length == 0
      this.setText('no keyboard macros.')
      return

    # execute macro
    this.setText('execute keyboard macros.')
    @execute_macro_once()
    this.setText('macro executed')

  repeat_last_kbd_macro: ->
    if @keyCaptured
      #beep()
      return
    if !@keySequence || @keySequence.length == 0
      this.setText('no keyboard macros.')
      return

    @repeatCountPanel.show()

  onGetRepeatCount: (count) ->
    for i in [1..count]
      this.setText("execute keyboard macro #{i}")
      @execute_macro_once()
    this.setText("executed macro #{count} times")
    @repeatCountPanel.hide()
