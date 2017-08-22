{CompositeDisposable} = require 'atom'
{FindNextCommand, FindPreviousCommand, FindNextSelectedCommand, FindPreviousSelectedCommand, SetSelectionAsFindPatternCommand, ReplacePreviousCommand, ReplaceNextCommand, ReplaceAllCommand} = require './macro-command'
KeymapManager = require 'atom-keymap'
keymaps = new KeymapManager
keystrokeForKeyboardEvent = keymaps.keystrokeForKeyboardEvent
keydownEvent = keymaps.keydownEvent
charCodeFromKeyIdentifier = keymaps.charCodeFromKeyIdentifier

module.exports =
class FindAndReplace
  findView: null
  findEditor: null
  replaceEditor: null

  findNext: null
  findPrevious: null
  findNextSelected: null
  findPreviousSelected: null
  setSelectionAsFindPattern: null
  replacePrevious: null
  replaceNext: null
  replaceAll: null

  isRecording: false

  activate: ->
    # wake up find-and-replace
    @editor = atom.workspace.getActiveTextEditor()
    @editorElement = atom.views.getView(@editor)
    atom.commands.dispatch(@editorElement, 'find-and-replace:toggle') # wake up if not active
    atom.commands.dispatch(@editorElement, 'find-and-replace:toggle') # hide

    isRecording = false
    @getFindAndReplaceMethods()

  deactivate: ->

  #
  # get Methods from FindView
  #
  getFindAndReplaceMethods: ->
    if @findNext
      return

    panels = atom.workspace.getBottomPanels()

    for panel in panels
      item = panel.item
      name = item?.__proto__?.constructor?.name
      if name == 'FindView'
        @findView = item

        @findNext = item.findNext
        @findPrevious = item.findPrevious
        @findNextSelected = item.findNextSelected
        @findPreviousSelected = item.findPreviousSelected
        @setSelectionAsFindPattern = item.setSelectionAsFindPattern
        @replacePrevious = item.replacePrevious
        @replaceNext = item.replaceNext
        @replaceAll = item.replaceAll

        @findEditor = item.findEditor
        @replaceEditor = item.replaceEditor

        @replaceAllButton = item.refs.replaceAllButton
        @replaceNextButton = item.refs.replaceNextButton
        @nextButton = item.refs.nextButton
        @regexOptionButton = item.refs.regexOptionButton
        @caseOptionButton = item.refs.caseOptionButton
        @selectionOptionButton = item.refs.selectionOptionButton
        @wholeWordOptionButton = item.refs.wholeWordOptionButton



        if !(@findNext and @findPrevious and @findNextSelected and @findPrevious and @findPreviousSelected and @setSelectionAsFindPattern and @replacePrevious and @replaceNext and @replaceAll and @findEditor and @replaceEditor)
          @findNext = null
          @findPrevious = null
          @findNextSelected = null
          @findPreviousSelected = null
          @setSelectionAsFindPattern = null
          @replacePrevious = null
          @replaceNext = null
          @replaceAll = null
          @findEditor = null
          @replaceEditor = null
          return

        break

  # Util

  getFindText: ->
    @findEditor?.getText()

  getReplaceText: ->
    @replaceEditor?.getText()

  setFindText: (text) ->
    @findEditor?.setText(text)

  setReplaceText: (text) ->
    @replaceEditor?.setText(text)

  #
  # start & stop
  #

  startRecording: (@macroSequence)->
    @isRecording = true
    @addHooks()

  stopRecording: ->
    @removeHooks()
    @isRecording = false

  addHooks: ->
    if !(@findNext and @findPrevious and @findNextSelected and @findPrevious and @findPreviousSelected and @setSelectionAsFindPattern and @replacePrevious and @replaceNext and @replaceAll and @findEditor and @replaceEditor)
      return

    item = @findView
    item.findNext = @findNextMonitor
    item.findPrevious = @findPreviousMonitor
    item.findNextSelected = @findNextSelectedMonitor
    item.findPreviousSelected = @findPreviousSelectedMonitor
    item.setSelectionAsFindPattern = @setSelectionAsFindPatternMonitor
    item.replacePrevious = @replacePreviousMonitor
    item.replaceNext = @replaceNextMonitor
    item.replaceAll = @replaceAllMonitor

    self = this
    @replaceAllButtonHook = (e) ->
      #self.replaceAll()
      self.replaceAllMonitor()
    @replaceAllButton.addEventListener 'click', @replaceAllButtonHook

    @replaceNextButtonHook = (e) ->
      #self.replaceNext()
      self.replaceNextMonitor()
    @replaceNextButton.addEventListener 'click', @replaceNextButtonHook

    @nextButtonHook = (e) ->
      #self.findNext()
      self.findView.findNext = self.findNext
      self.findView.findNext()
      self.findView.findNext = self.findNextMonitor
      #
      self.findNextMonitor()
    @nextButton.addEventListener 'click', @nextButtonHook

    @findEditorKeydownHook = (key) ->
      keystroke = atom.keymaps.keystrokeForKeyboardEvent(key)
      if(keystroke == "enter")
        #self.findNext()
        self.findView.findNext = self.findNext
        self.findView.findNext()
        self.findView.findNext = self.findNextMonitor
        #
        self.findNextMonitor()
    @findEditor.element.addEventListener 'keydown', @findEditorKeydownHook



  removeHooks: ->
    panels = atom.workspace.getBottomPanels()

    for panel in panels
      item = panel.item
      name = item?.__proto__?.constructor?.name
      if name == 'FindView'
        item.findNext = @findNext
        item.findPrevious = @findPrevious
        item.findNextSelected = @findNextSelected
        item.findPreviousSelected = @findPreviousSelected
        item.setSelectionAsFindPattern = @setSelectionAsFindPattern
        item.replaceNext = @replaceNext
        item.replaceAll = @replaceAll

    @replaceAllButton.removeEventListener  'click.atom-keyboard-macros', @replaceAllButtonHook
    @replaceNextButton.removeEventListener 'click.atom-keyboard-macros', @replaceNextButtonHook
    @nextButton.removeEventListener 'click.atom-keyboard-macros', @nextButtonHook
    @findEditor.element.removeEventListener 'keydown.atom-keyboard-macros', @findEditorKeydownHook

  #
  # hook handlers
  #

  # findNext: (options={focusEditorAfter: false}) =>
  findNextMonitor: ->
    if not @isRecording
      #@findNext?()
      return
    options = @findView.model?.getFindOptions()
    @macroSequence.push(new FindNextCommand(this, @getFindText(), options))

  #findPrevious: (options={focusEditorAfter: false}) =>
  findPreviousMonitor: ->
    if not @isRecording
      this.findView.findPrevious = self.findPrevious
      this.findView.findPrevious?()
      this.findView.findPrevious = self.findPreviousMonitor
      return
    options = @findView.model?.getFindOptions()
    @macroSequence.push(new FindPreviousCommand(this, @getFindText(), options))

  # findNextSelected: =>
  findNextSelectedMonitor: ->
    if not @isRecording
      this.findView.findNextSelected = self.findNextSelected
      this.findView.findNextSelected?()
      this.findView.findNextSelected = self.findNextSelectedMonitor
      return
    options = @findView.model?.getFindOptions()
    @macroSequence.push(new FindNextSelectedCommand(this, @getFindText(), options))

  # findPreviousSelected: =>
  findPreviousSelectedMonitor: ->
    if not @isRecording
      this.findView.findPreviousSelected = self.findPreviousSelected
      this.findView.findPreviousSelected?()
      this.findView.findPreviousSelected = self.findPreviousSelectedMonitor
      return
    options = @findView.model?.getFindOptions()
    @macroSequence.push(new FindPreviousSelectedCommand(this, @getFindText(), options))

  # setSelectionAsFindPattern: =>
  setSelectionAsFindPatternMonitor: ->
    if not @isRecording
      this.findView.setSelectionAsFindPattern = self.setSelectionAsFindPattern
      this.findView.setSelectionAsFindPattern?()
      this.findView.setSelectionAsFindPattern = self.setSelectionAsFindPatternMonitor
      return
    options = @findView.model?.getFindOptions()
    @macroSequence.push(new SetSelectionAsFindPatternCommand(this), options)

  # replacePrevious: =>
  replacePreviousMonitor: ->
    if not @isRecording
      this.findView.replacePrevious = self.replacePrevious
      this.findView.replacePrevious?()
      this.findView.replacePrevious = self.replacePreviousMonitor
      return
    options = @findView.model?.getFindOptions()
    @macroSequence.push(new ReplacePreviousCommand(this, @getFindText(), @getReplaceText(), options))

  # replaceNext: =>
  replaceNextMonitor: ->
    if not @isRecording
      this.findView.replaceNext = self.replaceNext
      this.findView.replaceNext?()
      this.findView.replaceNext = self.replaceNextMonitor
      return
    options = @findView.model?.getFindOptions()
    @macroSequence.push(new ReplaceNextCommand(this, @getFindText(), @getReplaceText(), options))

  # replaceAll: =>
  replaceAllMonitor: ->
    if not @isRecording
      this.findView.replaceAll = self.replaceAll
      this.findView.replaceAll?()
      this.findView.replaceAll = self.replaceAllMonitor
      return
    options = @findView.model?.getFindOptions()
    @macroSequence.push(new ReplaceAllCommand(this, @getFindText(), @getReplaceText(), options))
