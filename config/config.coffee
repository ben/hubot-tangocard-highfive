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
            'HUBOT_HIGHFIVE_TANGOCARD_KEY',
            'HUBOT_HIGHFIVE_TANGOCARD_CC',
            'HUBOT_HIGHFIVE_TANGOCARD_AUTH',
        ]

        for f in @fieldnames
            @[f] = ko.observable()

        @configoutput = ko.computed =>
            vars = []
            for k in @fieldnames
                v = @[k]()
                vars.push "#{k}=#{v}" if v? and v != ''
            vars.join ' \\\n'

        # Credit card stuff
        @cc_number = ko.observable ''

    cc_go: ->
        console.log "Number #{@cc_number()}, auth #{@HUBOT_HIGHFIVE_TANGOCARD_AUTH()}"
        # TODO: send this to the Tango Card API
        @HUBOT_HIGHFIVE_TANGOCARD_CC "(something with #{@HUBOT_HIGHFIVE_TANGOCARD_AUTH()})"

$ ->
    window.vm = new MainViewModel()

    $.getJSON 'values.json', (data) ->
        console.log data
        for k,v of data
            vm[k](v)

    ko.applyBindings vm

    $('#configoutput').click ->
        @select()
