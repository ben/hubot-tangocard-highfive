class MainViewModel
    constructor: ->
        @services = [
            'slack'
        ]

        @fieldnames = [
            'HUBOT_HIGHFIVE_EMAIL_SERVICE',
            'HUBOT_HIGHFIVE_ROOM',
            'HUBOT_HIGHFIVE_AWARD_LIMIT',
            'HUBOT_TANGOCARD_ROOTURL'
            'HUBOT_TANGOCARD_USER',
            'HUBOT_TANGOCARD_KEY',
            'HUBOT_TANGOCARD_CC',
            'HUBOT_TANGOCARD_AUTH',
            'HUBOT_TANGOCARD_CUSTOMER',
            'HUBOT_TANGOCARD_ACCOUNT',
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

    tangocard_get: (url, callback) ->
        user = @HUBOT_HIGHFIVE_TANGOCARD_USER()
        pass = @HUBOT_HIGHFIVE_TANGOCARD_KEY()
        $.ajax
            type: 'GET'
            url: url
            success: callback
            headers:
                Authorization: "Basic " + btoa(user + ":" + pass)

    tangocard_setup: ->
        auth = @HUBOT_HIGHFIVE_TANGOCARD_AUTH()
        cust = @HUBOT_HIGHFIVE_TANGOCARD_CUSTOMER()
        acct = @HUBOT_HIGHFIVE_TANGOCARD_ACCOUNT()

        # TODO: validate inputs

        # TODO: Add an account if it doesn't already exist

        @HUBOT_HIGHFIVE_TANGOCARD_CC "(something with #{auth})"

$ ->
    window.vm = new MainViewModel()

    $.getJSON 'values.json', (data) ->
        console.log data
        for k,v of data
            vm[k](v)

    ko.applyBindings vm

    $('#configoutput').click ->
        @select()
