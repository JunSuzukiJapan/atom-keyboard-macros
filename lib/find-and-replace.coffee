{CompositeDisposable} = require 'atom'
{keystrokeForKeyboardEvent, keydownEvent, characterForKeyboardEvent} = require './helpers'
{FindNextCommand, FindPreviousCommand, FindNextSelectedCommand, FindPreviousSelectedCommand, SetSelectionAsFindPatternCommand, ReplacePreviousCommand, ReplaceNextCommand, ReplaceAllCommand} = require './macro-command'

module.exports =
class FindAndReplace
  findEditor: null
  replaceEditor: null

  #toggle: ->
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
    editorElement = atom.views.getView(atom.workspace.getActiveTextEditor())
    atom.commands.dispatch(editorElement, 'find-and-replace:toggle') # wake up if not active
    atom.commands.dispatch(editorElement, 'find-and-replace:toggle') # hide

    isRecording = false
    @getFindAndReplaceMethods()

  deactivate: ->
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

    @replaceAllButton.removeEventListener('on', @replaceAllButtonHook)


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
        console.log('item', item)

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

        @replaceAllButton = item.replaceAllButton
        @replaceNextButton = item.replaceNextButton
        @nextButton = item.nextButton
        @regexOptionButton = item.regexOptionButton
        @caseOptionButton = item.caseOptionButton
        @selectionOptionButton = item.selectionOptionButton
        @wholeWordOptionButton = item.wholeWordOptionButton

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
          self.replaceAllMonitor()
        @replaceAllButton.on 'click', @replaceAllButtonHook

        #console.log('item',item)

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

  stopRecording: ->
    @isRecording = false

  #
  # hook handlers
  #

  # findNext: (options={focusEditorAfter: false}) =>
  findNextMonitor: (options={focusEditorAfter: false}) ->
    #@findNext(options)

    if not @isRecording
      return
    @macroSequence.push(new FindNextCommand(this, @getFindText(), options))

  #findPrevious: (options={focusEditorAfter: false}) =>
  findPreviousMonitor: (options={focusEditorAfter: false}) ->
    #@findPrevious(options)

    if not @isRecording
      return
    @macroSequence.push(new FindPreviousCommand(this, @getFindText(), options))

  # findNextSelected: =>
  findNextSelectedMonitor: ->
    #@findNextSelected()

    if not @isRecording
      return
    @macroSequence.push(new FindNextSelectedCommand(this, @getFindText()))

  # findPreviousSelected: =>
  findPreviousSelectedMonitor: ->
    #@findPreviousSelected()

    if not @isRecording
      return
    @macroSequence.push(new FindPreviousSelectedCommand(this, @getFindText()))

  # setSelectionAsFindPattern: =>
  setSelectionAsFindPatternMonitor: ->
    #@setSelectionAsFindPattern()

    if not @isRecording
      return
    @macroSequence.push(new SetSelectionAsFindPatternCommand(this))

  # replacePrevious: =>
  replacePreviousMonitor: ->
    #@replacePrevious()

    if not @isRecording
      return
    @macroSequence.push(new ReplacePreviousCommand(this, @getFindText(), @getReplaceText()))

  # replaceNext: =>
  replaceNextMonitor: ->
    #@replaceNext()

    if not @isRecording
      return
    @macroSequence.push(new ReplaceNextCommand(this, @getFindText(), @getReplaceText()))

  # replaceAll: =>
  replaceAllMonitor: ->
    #@replaceAll()

    console.log('this', this)

    if not @isRecording
      return
    @macroSequence.push(new ReplaceAllCommand(this, @getFindText(), @getReplaceText()))

  ###
  find-and-replace:find-next: true
  find-and-replace:find-next-selected: true
  find-and-replace:find-previous: true
  find-and-replace:find-previous-selected: true
  find-and-replace:replace-all: true
  find-and-replace:replace-next: true
  find-and-replace:select-all: true
  find-and-replace:select-next: true
  #find-and-replace:show: true
  #find-and-replace:show-replace: true
  find-and-replace:toggle: true
  #find-and-replace:use-selection-as-find-pattern: true
  ###
###
  handleEvents: ->
    @handleFindEvents()
    @handleReplaceEvents()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'find-and-replace:select-all': => @findNextMonitor
      'find-and-replace:select-next': => @findPreviousMonitor
      'find-and-replace:toggle': => @toggleMonitor

  handleFindEvents: ->
    @subscriptions.add atom.commands.add 'atom-workspace',
      'find-and-replace:find-next': => @findNextMonitor
      'find-and-replace:find-previous': => @findPreviousMonitor
      'find-and-replace:find-next-selected': @findNextSelectedMonitor
      'find-and-replace:find-previous-selected': @findPreviousSelectedMonitor
      'find-and-replace:use-selection-as-find-pattern': @setSelectionAsFindPatternMonitor

  handleReplaceEvents: ->
    @subscriptions.add atom.commands.add 'atom-workspace',
      'find-and-replace:replace-previous': @replacePreviousMonitor
      'find-and-replace:replace-next': @replaceNextMonitor
      'find-and-replace:replace-all': @replaceAllMonitor










  search: (findPattern, options) ->
    if arguments.length is 1 and typeof findPattern is 'object'
      options = findPattern
      findPattern = null
    findPattern ?= @findEditor.getText()
    @model.search(findPattern, options)

  findAll: (options={focusEditorAfter: true}) =>
    @findAndSelectResult(@selectAllMarkers, options)

  findNext: (options={focusEditorAfter: false}) =>
    @findAndSelectResult(@selectFirstMarkerAfterCursor, options)

  findPrevious: (options={focusEditorAfter: false}) =>
    @findAndSelectResult(@selectFirstMarkerBeforeCursor, options)

  findAndSelectResult: (selectFunction, {focusEditorAfter, fieldToFocus}) =>
    @search()
    @findHistoryCycler.store()

    if @markers?.length > 0
      selectFunction()
      if fieldToFocus
        fieldToFocus.focus()
      else if focusEditorAfter
        workspaceElement = atom.views.getView(atom.workspace)
        workspaceElement.focus()
      else
        @findEditor.focus()
    else
      atom.beep()

  replaceNext: =>
    @replace('findNext', 'firstMarkerIndexStartingFromCursor')

  replacePrevious: =>
    @replace('findPrevious', 'firstMarkerIndexBeforeCursor')

  replace: (nextOrPreviousFn, nextIndexFn) ->
    @search()
    @findHistoryCycler.store()
    @replaceHistoryCycler.store()

    if @markers?.length > 0
      unless currentMarker = @model.currentResultMarker
        if position = @[nextIndexFn]()
          currentMarker = @markers[position.index]

      @model.replace([currentMarker], @replaceEditor.getText())
      @[nextOrPreviousFn](fieldToFocus: @replaceEditor)
    else
      atom.beep()

  replaceAll: =>
    @search()
    if @markers?.length
      @findHistoryCycler.store()
      @replaceHistoryCycler.store()
      @model.replace(@markers, @replaceEditor.getText())
    else
      atom.beep()
###
