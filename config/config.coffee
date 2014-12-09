class MainViewModel
    constructor: ->

$ ->
    $.getJSON 'values.json', (data) ->
        console.log data
    ko.applyBindings new MainViewModel()
