AtomKeyboardMacrosView = require './atom-keyboard-macros-view'
{CompositeDisposable} = require 'atom'

module.exports = AtomKeyboardMacros =
  atomKeyboardMacrosView: null
  modalPanel: null
  subscriptions: null

  keyCaptured: false
  keySequence: []

  activate: (state) ->
    @atomKeyboardMacrosView = new AtomKeyboardMacrosView(state.atomKeyboardMacrosViewState)
    @modalPanel = atom.workspace.addBottomPanel(item: @atomKeyboardMacrosView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register commands
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:start_kbd_macro': => @start_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:end_kbd_macro': => @end_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:call_last_kbd_macro': => @call_last_kbd_macro()

    #@originalHandleKeyboardEvent = atom.keymaps.handleKeyboardEvent
    @keyCaptured = false
    window.addEventListener('keydown', this.newHandleKeyboardEvent.bind(this), true)

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @atomKeyboardMacrosView.destroy()

  serialize: ->
    atomKeyboardMacrosViewState: @atomKeyboardMacrosView.serialize()

  setText: (text) ->
    @atomKeyboardMacrosView.setText(text)
    @modalPanel.show()

  newHandleKeyboardEvent: (e) ->
    #console.log('capture ', @keyCaptured)
    if @keyCaptured
      #console.log('Capture ', e)
      @keySequence.push(e)

  start_kbd_macro: ->
    this.setText('start recording keyboard macros...')
    if @keyCaptured
      #beep()
      return
    @keySequence = []
    @keyCaptured = true

  end_kbd_macro: ->
    @keyCaptured = false
    this.setText('end recording keyboard macros.')
#    @keySequence.pop() # remove ')' key
#    @keySequence.pop() # remove 'shift' key
#    @keySequence.pop() # remove 'x' key
#    @keySequence.pop() #() remove 'ctrl' key

  call_last_kbd_macro: ->
    if @keyCaptured
      #beep()
      return
    if !@keySequence || @keySequence.length == 0
      this.setText('no keyboard macros.')
      return

    # execute macro
    this.setText('execute keyboard macros.')
    for e in @keySequence
      atom.keymaps.handleKeyboardEvent(e)
