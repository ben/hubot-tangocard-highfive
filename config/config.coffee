class MainViewModel
    constructor: ->
        @services = [
            'slack'
        ]

        @fieldnames = [
            'HUBOT_HIGHFIVE_EMAIL_SERVICE',
            'HUBOT_HIGHFIVE_ROOM',
            'HUBOT_HIGHFIVE_AWARD_LIMIT',
            # TODO: tangocard variables
        ]

        for f in @fieldnames
            @[f] = ko.observable()

        @configoutput = ko.computed =>
            vars = []
            for f in @fieldnames
                vars.push "#{f}=#{@[f]()}"
            vars.join ' \\\n'

$ ->
    window.vm = new MainViewModel()

    $.getJSON 'values.json', (data) ->
        console.log data
        for k,v of data
            vm[k](v)

    ko.applyBindings vm

    $('#configoutput').click ->
        @select()
