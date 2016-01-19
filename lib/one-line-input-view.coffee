module.exports =
class OneLineInputView
  callback: null

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

    @input = document.createElement('input')
    @input.type = 'text'
    @input.onkeydown = (e) ->
      if e.keyIdentifier == 'Enter' and self.callback
        self.callback(self.input.value)
    form.appendChild(@input)

    button = document.createElement('button')
    button.textContent ='OK'
    button.type = 'submit'
    form.appendChild(button)

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element

  setCallback: (callback) ->
    @callback = callback
