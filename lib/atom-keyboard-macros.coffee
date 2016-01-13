AtomKeyboardMacrosView = require './atom-keyboard-macros-view'
{CompositeDisposable} = require 'atom'
{normalizeKeystrokes, keystrokeForKeyboardEvent, isAtomModifier, keydownEvent, characterForKeyboardEvent} = require './helpers'
Compiler = require './keyevents-compiler'

module.exports = AtomKeyboardMacros =
  atomKeyboardMacrosView: null
  modalPanel: null
  subscriptions: null

  keyCaptured: false
  eventListener: null
  keySequence: []
  compiler: null
  compiledCommands: null

  activate: (state) ->
    @atomKeyboardMacrosView = new AtomKeyboardMacrosView(state.atomKeyboardMacrosViewState)
    @modalPanel = atom.workspace.addBottomPanel(item: @atomKeyboardMacrosView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register commands
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:start_kbd_macro': => @start_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:end_kbd_macro': => @end_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:call_last_kbd_macro': => @call_last_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:toggle': => @toggle()

    # add event listener
    @eventListener = this.newHandleKeyboardEvent.bind(this)

    @keyCaptured = false
    @compiler = new Compiler()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @atomKeyboardMacrosView.destroy()
    window.removeEventListener('keydown', @eventListener, true)

  serialize: ->
    atomKeyboardMacrosViewState: @atomKeyboardMacrosView.serialize()

  toggle: ->
    console.log('toggle')
    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()

  setText: (text) ->
    @atomKeyboardMacrosView.setText(text)
    @modalPanel.show()

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
    #@keySequence.pop() # remove ')' key
    #@keySequence.pop() # remove 'shift' key
    #@keySequence.pop() # remove 'x' key
    #@keySequence.pop() #() remove 'ctrl' key
    @compiledCommands = @compiler.compile(@keySequence)


  call_last_kbd_macro: ->
    if @keyCaptured
      #beep()
      return
    if !@keySequence || @keySequence.length == 0
      this.setText('no keyboard macros.')
      return

    # execute macro
    this.setText('execute keyboard macros.')
    for cmd in @compiledCommands
      console.log('execute: ', cmd)
      cmd.execute()


###
    hasNextStroke = false
    for e in @keySequence
      console.log('e: ', e)

      if e.altKey || e.ctrlKey || e.metaKey || hasNextStroke
        atom.keymaps.handleKeyboardEvent(e)
        hasNextStroke = false

        # ２ストローク以上のコマンドの場合の処理
        keystroke = keystrokeForKeyboardEvent(e)
        console.log('keystroke:', keystroke)
        cmd = atom.keymaps.findKeyBindings({keystrokes: keystroke})
        console.log('cmd: ', cmd)
        if cmd.length == 0
          console.log('in command process')
          hasNextStroke = true

      else
        atom.keymaps.simulateTextInput(e)

    #atom.keymaps.clear()
###
