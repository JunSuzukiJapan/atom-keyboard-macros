module.exports =
class RepeatCountView
  callback: null

  constructor: (serializedState) ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('atom-keyboard-macros')

    # Create message element
    message = document.createElement('div')
    message.textContent = "Repeat count:"
    message.classList.add('message')
    @element.appendChild(message)

    @input = document.createElement('input')
    @input.type = 'number'
    @input.value = 1
    message.appendChild(@input)
    ###
    @input.onsubmit = (e) ->
      console.log('submit')
      if @callback and @input.value
        @callback(@input.value)
    ###

    self = this
    button = document.createElement('button')
    button.textContent = 'Execute'
    button.onclick = (e) ->
      if self.callback
        self.callback(self.input.value)
      #self.getElement().hide()
    message.appendChild(button)

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element

  setCallback: (callback) ->
    @callback = callback
