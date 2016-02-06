{TextEditor} = require 'atom'

module.exports =
class OneLineInputView
  callback: null
  element: null
  editorElement: null
  input: null

  constructor: (serializedState) ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('atom-keyboard-macros')

    form = document.createElement('form')
    self = this
    form.onsubmit = (e) ->
      if self.callback
        self.callback(self.input.value)
    @element.appendChild(form)

    @editorElement = document.createElement('atom-text-editor')
    @input = document.createElement('subview')
    elem = document.createElement('div')
    editor = atom.workspace.buildTextEditor({
      mini: true,
      lineNumberGutterVisible: false,
      placeholderText: 'Macro name'
    })
    @editorElement.setModel(editor)
    elem.appendChild(@editorElement)
    @input.appendChild(elem)
    @input.onkeydown = (e) ->
      if e.keyIdentifier == 'Enter' and self.callback
        value = self.input.value
        self.callback(value)
    form.appendChild(@input)

  focus: ->
    @editorElement.focus()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element

  setCallback: (callback) ->
    @callback = callback
