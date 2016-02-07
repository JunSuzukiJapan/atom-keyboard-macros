AtomKeyboardMacrosView = require './atom-keyboard-macros-view'
RepeatCountView = require './repeat-count-view'
OneLineInputView = require './one-line-input-view'
MacroNameSelectListView = require './macro-name-select-list-view'
{CompositeDisposable} = require 'atom'
{normalizeKeystrokes, keystrokeForKeyboardEvent, isAtomModifier, keydownEvent, characterForKeyboardEvent} = require './helpers'
Compiler = require './keyevents-compiler'
{MacroCommand, DispatchCommand} = require './macro-command'
fs = require 'fs'
FindAndReplace = require './find-and-replace'

module.exports = AtomKeyboardMacros =
  atomKeyboardMacrosView: null
  messagePanel: null
  repeatCountView: null
  repeatCountPanel: null
  oneLineInputView: null
  oneLineInputPanel: null
  macroNamesSelectListView: null
  subscriptions: null

  keyCaptured: false
  eventListener: null
  escapeListener: null
  escapeKeyPressed: false
  keySequence: []
  compiler: null
  compiledCommands: null

  runningName_last_kbd_macro: false
  runningExecute_named_macro: false

  quick_save_dirname: null
  quick_save_filename: null
  macro_dirname: null

  find: null

  activate: (state) ->
    @quick_save_dirname = atom.packages.resolvePackagePath('atom-keyboard-macros') + '/__quick/'
    @quick_save_filename = @quick_save_dirname + 'macros.atmkm'
    @macro_dirname = atom.packages.resolvePackagePath('atom-keyboard-macros') + '/macros/'

    @atomKeyboardMacrosView = new AtomKeyboardMacrosView(state.atomKeyboardMacrosViewState)
    @messagePanel = atom.workspace.addBottomPanel(item: @atomKeyboardMacrosView.getElement(), visible: false)

    @repeatCountView = new RepeatCountView(state.repeatCountViewState)
    @repeatCountPanel = atom.workspace.addModalPanel(item: @repeatCountView.getElement(), visible: false)

    @oneLineInputView = new OneLineInputView(state.oneLineInputViewState)
    @oneLineInputPanel = atom.workspace.addModalPanel(item: @oneLineInputView.getElement(), visible: false)

    @macroNamesSelectListView = new MacroNameSelectListView(state.macroNamesSelectListViewState)

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
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:save': => @save()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:load': => @load()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-keyboard-macros:all_macros_to_new_text_editor': => @all_macros_to_new_text_editor()

    #@subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:replace-all': => @replaceAll()

    # make event listener
    @eventListener = @newHandleKeyboardEvent.bind(this)
    @escapeListener = @onEscapeKey.bind(this)

    @keyCaptured = false
    @compiler = new Compiler()
    @find = new FindAndReplace()
    @find.activate()

  deactivate: ->
    @find.deactivate()
    @macroNamesSelectListView.destroy()
    @oneLineInputPanel.destroy()
    @oneLineInputView.destroy()
    @repeatCountPanel.destroy()
    @repeatCountView.destroy()
    @messagePanel.destroy()
    @subscriptions.dispose()
    @atomKeyboardMacrosView.destroy()
    window.removeEventListener('keydown', @escapeListener, true)
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
    if e.target?.className?.indexOf('editor mini') >= 0
      return
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
    @find.startRecording(@keySequence)

    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.focus()

  #
  # stop recording keyboard macros
  #
  end_kbd_macro: ->
    window.removeEventListener('keydown', @eventListener, true)
    @keyCaptured = false
    this.setText('end recording keyboard macros.')
    @compiledCommands = @compiler.compile(@keySequence)
    @find.stopRecording()

  #
  # Util method: execute macro once
  #
  execute_macro_once: ->
    @execute_macro_commands @compiledCommands

  execute_macro_commands: (cmds) ->
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.focus()

    for cmd in cmds
      cmd.execute()

  #
  # Save to file
  #
  table: {}  # named macro table

  addNamedMacroTable: (name, commands) ->
    self = this
    @table[name] = commands

    @macroNamesSelectListView.addItem name

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
    result

  allMacrosToString: ->
    str = '\n'
    for name, cmds of @table
      str += '  ' + name + ': ->\n'
      str += @macro_to_string(cmds) + '\n'
    str

  all_macros_to_new_text_editor: ->
    self = this
    promiss = atom.workspace.open()
    promiss.then (editor) ->
      editor.insertText(self.allMacrosToString())


  #
  # file Util
  #
  ask_filename: (callback) ->
    @oneLineInputPanel.show()
    @oneLineInputView.focus()
    window.addEventListener('keydown', @escapeListener, true)
    @oneLineInputView.setCallback (e) ->
      callback e

  #
  # save
  #

  # save as ...
  save: ->
    _self = this
    fs.exists @macro_dirname, (exists) ->
      if !exists
        fs.mkdirSync _self.macro_dirname
      _self.ask_filename (name) ->
        fullpath = _self.macro_dirname + name
        #console.log('save: ', fullpath)
        _self.save_as fullpath
        _self.oneLineInputPanel.hide()

  save_as: (filename) ->
    str = ''
    for name, cmds of @table
      str += '>' + name + '\n'
      for cmd in cmds
        str += cmd.toSaveString()
    self = this
    fs.writeFile filename, str, (err) ->
      if err
        console.error (err)

  # quick_save
  quick_save: ->
    ___self = this
    fs.exists @quick_save_dirname, (exists) ->
      if !exists
        fs.mkdirSync ___self.quick_save_dirname
      ___self.save_as ___self.quick_save_filename

  #
  # load
  #

  # load as ...
  load: ->
    _self = this
    @ask_filename (name) ->
      fullpath = _self.macro_dirname + name
      _self.load_with_name fullpath
      _self.oneLineInputPanel.hide()

  load_with_name: (name) ->
    self = this
    fs.readFile name, 'utf8', (err, text) ->
      if err
        console.error err
      else
        macros = MacroCommand.loadStringAsMacroCommands text, self.find
        for name, cmds of macros
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
    @oneLineInputView.focus()
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
    #@oneLineInputPanel.show()
    #@oneLineInputView.focus()
    @macroNamesSelectListView.show()
    window.addEventListener('keydown', @escapeListener, true)
    self = this
    #@oneLineInputView.setCallback (text) ->
    @macroNamesSelectListView.setCallback (text) ->
      self.execute_named_macro_with_string(text)
      #self.oneLineInputPanel.hide()

  execute_named_macro_with_string: (name) ->
    if @keyCaptured
      atom.beep()
      return
    cmd = 'atom-keyboard-macros.user:' + name
    editor = atom.workspace.getActiveTextEditor()
    atom.commands.dispatch(atom.views.getView(editor), cmd)

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
    @repeatCountView.focus()
    window.addEventListener('keydown', @escapeListener, true)
    self = this
    @repeatCountView.setCallback (count) ->
      self.onGetRepeatCount(count)

  onEscapeKey: (e) ->
    keystroke = atom.keymaps.keystrokeForKeyboardEvent(e)
    if keystroke == 'escape'
      @escapeKeyPressed = true
      @repeatCountPanel.hide()
      @oneLineInputPanel.hide()
      window.removeEventListener('keydown', @escapeListener, true)


  onGetRepeatCount: (count) ->
    @repeatCountPanel.hide()
    for i in [1..count]
      @setText("execute keyboard macro #{i}")
      @execute_macro_once()
    @setText("executed macro #{count} times")

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
      window.addEventListener('keydown', @escapeListener, true)
      @escaescapeKeyPressed = false
      while editor.getLastCursor().getBufferRow() < editor.getLastBufferRow()
        if @escapeKeyPressed
          break
        @execute_macro_once()
      window.removeEventListener('keydown', @escapeListener, true)
