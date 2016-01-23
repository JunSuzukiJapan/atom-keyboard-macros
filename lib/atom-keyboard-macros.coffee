AtomKeyboardMacrosView = require './atom-keyboard-macros-view'
RepeatCountView = require './repeat-count-view'
OneLineInputView = require './one-line-input-view'
{CompositeDisposable} = require 'atom'
{normalizeKeystrokes, keystrokeForKeyboardEvent, isAtomModifier, keydownEvent, characterForKeyboardEvent} = require './helpers'
Compiler = require './keyevents-compiler'
{MacroCommand, DispatchCommand} = require './macro-command'
fs = require 'fs'

module.exports = AtomKeyboardMacros =
  atomKeyboardMacrosView: null
  messagePanel: null
  repeatCountView: null
  repeatCountPanel: null
  oneLineInputView: null
  oneLineInputPanel: null
  subscriptions: null

  keyCaptured: false
  eventListener: null
  escapeListener: null
  keySequence: []
  compiler: null
  compiledCommands: null

  runningName_last_kbd_macro: false
  runningExecute_named_macro: false

  quick_save_dirname: null
  quick_save_filename: null

  activate: (state) ->
    @quick_save_dirname = atom.packages.resolvePackagePath('atom-keyboard-macros') + '/__quick/'
    @quick_save_filename = @quick_save_dirname + 'macros.coffee'

    @atomKeyboardMacrosView = new AtomKeyboardMacrosView(state.atomKeyboardMacrosViewState)
    @messagePanel = atom.workspace.addBottomPanel(item: @atomKeyboardMacrosView.getElement(), visible: false)

    @repeatCountView = new RepeatCountView(state.repeatCountViewState)
    @repeatCountPanel = atom.workspace.addModalPanel(item: @repeatCountView.getElement(), visible: false)

    @oneLineInputView = new OneLineInputView(state.oneLineInputViewState)
    @oneLineInputPanel = atom.workspace.addModalPanel(item: @oneLineInputView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register commands
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:start_kbd_macro': => @start_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:end_kbd_macro': => @end_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:call_last_kbd_macro': => @call_last_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:repeat_last_kbd_macro': => @repeat_last_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:execute_macro_to_bottom': => @execute_macro_to_bottom()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:execute_macro_from_top_to_bottom': => @execute_macro_from_top_to_bottom()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:toggle': => @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:name_last_kbd_macro': => @name_last_kbd_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:execute_named_macro': => @execute_named_macro()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:quick_save': => @quick_save()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:quick_load': => @quick_load()
    #@subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:save': => @save()
    #@subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:load': => @load()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:all_macros_to_new_text_editor': => @all_macros_to_new_text_editor()

    # make event listener
    @eventListener = @newHandleKeyboardEvent.bind(this)
    @escapeListener = @onEscapeKey.bind(this)

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

  # @eventListener
  newHandleKeyboardEvent: (e) ->
    @keySequence.push(e)

  #
  # start recording keyborad macros
  #
  start_kbd_macro: ->
    this.setText('start recording keyboard macros...')
    if @keyCaptured
      atom.beep()
      return
    @keySequence = []
    @keyCaptured = true
    window.addEventListener('keydown', @eventListener, true)

  #
  # stop recording keyboard macros
  #
  end_kbd_macro: ->
    window.removeEventListener('keydown', @eventListener, true)
    @keyCaptured = false
    this.setText('end recording keyboard macros.')
    @compiledCommands = @compiler.compile(@keySequence)

  #
  # Util method: execute macro once
  #
  execute_macro_once: ->
    @execute_macro_commands @compiledCommands

  execute_macro_commands: (cmds) ->
    for cmd in cmds
      cmd.execute()

  #
  # Save to file
  #
  table: {}  # named macro table

  addNamedMacroTable: (name, commands) ->
    self = this
    @table[name] = commands

    # remove old command if exists
    prevCommand = atom.commands.selectorBasedListenersByCommandName['atom-keyboard-macros.user:' + name]
    if prevCommand
      atom.commands.selectorBasedListenersByCommandName['atom-keyboard-macros.user:' + name] = null
    # add new command
    atom.commands.add 'atom-workspace', ('atom-keyboard-macros.user:' + name), ->
      self.execute_macro_commands commands

  macro_to_string: (cmds) ->
    result = ''
    tabs = '    '
    MacroCommand.resetForToString()

    for cmd in cmds
      result += cmd.toString(tabs)
    #console.log('result ', result)
    result

  allMacrosToString: ->
    str = '\n'
    for name, cmds of @table
      str += '  ' + name + ': ->\n'
      str += @macro_to_string(cmds) + '\n'
    #console.log('macros \n', str)
    str

  all_macros_to_new_text_editor: ->
    self = this
    promiss = atom.workspace.open()
    promiss.then (editor) ->
      editor.insertText(self.allMacrosToString())

  ###
  last_macro_to_string: ->
    if @keyCaptured
      atom.beep()
      return

    if @compiledCommands and @compiledCommands.length > 0
      result = 'atom-keyboard-macros.user.' + 'methodName' + ': ->\n'
      result += @macro_to_string(@compiledCommands)
      console.log('macro: ', result)
    else
      atom.beep()
  ###



  #
  # file Util
  #
  ask_filename: (callback) ->
    @oneLineInputPanel.show()
    @oneLineInputView.input.focus()
    @oneLineInputView.setCallback (e) ->
      console.log('callback')
      callback e

  #
  # save
  #

  # save as ...
  save: ->
    _self = this
    @ask_filename (name) ->
      console.log('save: ', name)
      _self.save_as name
      _self.oneLineInputPanel.hide()

  save_as: (filename) ->
    str = ''
    for name, cmds of @table
      str += '>' + name + '\n'
      for cmd in cmds
        str += cmd.toSaveString()
    #console.log('save to: ', filename, '\n  ', str)
    self = this
    fs.exists @quick_save_dirname, (exists) ->
      if !exists
        console.log('savedir ', self.quick_save_dirname)
        fs.mkdirSync self.quick_save_dirname
      fs.writeFile filename, str, (err) ->
        if err
          console.log(err)

  # quick_save
  quick_save: ->
    @save_as @quick_save_filename

  #
  # load
  #

  # load as ...
  load: ->
    _self = this
    @ask_filename (name) ->
      _self.load_with_name name

  load_with_name: (name) ->
    self = this
    fs.readFile name, 'utf8', (err, text) ->
      if err
        console.error err
      else
        macros = MacroCommand.loadStringAsMacroCommands text
        for name, cmds of macros
          #console.log('name: ', name, ', cmds: ', cmds)
          self.addNamedMacroTable(name, cmds)

  # quick_load
  quick_load: ->
    @load_with_name @quick_save_filename

  #
  # name last keyboard macro
  #
  name_last_kbd_macro: ->
    @runningName_last_kbd_macro = true
    @oneLineInputPanel.show()
    @oneLineInputView.input.focus()
    window.addEventListener('keydown', @escapeListener, true)
    self = this
    @oneLineInputView.setCallback (text) ->
      self.name_last_kbd_macro_with_string(text)
      self.oneLineInputPanel.hide()


  name_last_kbd_macro_with_string: (name) ->
    if @keyCaptured
      atom.beep()
      return

    if @compiledCommands and @compiledCommands.length > 0
      @addNamedMacroTable(name, @compiledCommands)
    else
      atom.beep()

  #
  # execute named macro
  #
  execute_named_macro: ->
    @runningExecute_named_macro = true
    @oneLineInputPanel.show()
    @oneLineInputView.input.focus()
    window.addEventListener('keydown', @escapeListener, true)
    @oneLineInputView.setCallback (text) ->
      execute_named_macro_with_string(text)
      self.oneLineInputPanel.hide()

  execute_named_macro_with_string: (name) ->
    if @keyCaptured
      atom.beep()
      return
    cmd = 'atom-keyboard-macros.user:' + name
    editor = atom.workspace.getActiveTextEditor()
    atom.commands.dispatch(atom.views.getView(editor), cmd)

  ###
  onLineInput: (text) ->
    if @runningName_last_kbd_macro
      @name_last_kbd_macro_with_string(text)
    else if @runningExecute_named_macro
      @execute_named_macro_with_string(text)

    @runningName_last_kbd_macro = false
    @runningExecute_named_macro = false
    @oneLineInputPanel.hide()
  ###

  #
  # call last macro
  #
  call_last_kbd_macro: ->
    if @keyCaptured
      atom.beep()
      return
    if !@keySequence || @keySequence.length == 0
      this.setText('no keyboard macros.')
      return

    # execute macro
    this.setText('execute keyboard macros.')
    @execute_macro_once()
    this.setText('macro executed')

  #
  # repeat last macro
  #
  repeat_last_kbd_macro: ->
    if @keyCaptured
      atom.beep()
      return
    if !@keySequence || @keySequence.length == 0
      this.setText('no keyboard macros.')
      return

    @repeatCountPanel.show()
    @repeatCountView.input.focus()
    window.addEventListener('keydown', @escapeListener, true)
    @repeatCountView.setCallback onGetRepeatCount

  onEscapeKey: (e) ->
    keystroke = atom.keymaps.keystrokeForKeyboardEvent(e)
    if keystroke == 'escape'
      @repeatCountPanel.hide()
      @oneLineInputPanel.hide()
      window.removeEventListener('keydown', @escapeListener, true)


  onGetRepeatCount: (count) ->
    for i in [1..count]
      this.setText("execute keyboard macro #{i}")
      @execute_macro_once()
    this.setText("executed macro #{count} times")
    @repeatCountPanel.hide()

  #
  # execute macro to bottom of the editor
  #
  execute_macro_to_bottom: ->
    this.setText("execute keyboard macro to bottom of the buffer.")
    @util_execute_macro_to_bottom()
    this.setText("executed keyboard macro to bottom of the buffer.")

  #
  # execute macro from top to bottom of the editor
  #
  execute_macro_from_top_to_bottom: ->
    this.setText("execute keyboard macro from top to bottom of the buffer.")
    editor = atom.workspace.getActiveTextEditor()
    if editor
      editor.moveToTop()
    @util_execute_macro_to_bottom()
    this.setText("executed keyboard macro from top to bottom of the buffer.")

  # Util: execute macro to bottom
  util_execute_macro_to_bottom: ->
    editor = atom.workspace.getActiveTextEditor()
    if editor
      while editor.getLastCursor().getBufferRow() < editor.getLastBufferRow()
        @execute_macro_once()
