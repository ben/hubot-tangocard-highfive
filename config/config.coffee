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
            'HUBOT_TANGOCARD_EMAIL',
        ]

        for f in @fieldnames
            @[f] = ko.observable()

        @configoutput = ko.computed =>
            vars = []
            for k in @fieldnames
                v = @[k]()
                vars.push "#{k}='#{v}'" if v? and v != ''
            vars.join ' \\\n'

        # Credit card stuff
        @cc_number = ko.observable ''

    basic_auth: ->
        user = @HUBOT_TANGOCARD_USER()
        pass = @HUBOT_TANGOCARD_KEY()
        "Basic " + btoa(user + ":" + pass)

    tangocard_get: (url, success, error) ->
        fullurl = @HUBOT_TANGOCARD_ROOTURL() + url
        $.ajax
            type: 'GET'
            url: fullurl
            dataType: 'json'
            success: success
            error: error
            headers:
                Authorization: @basic_auth()

    tangocard_post: (url, data, success, error) ->
        fullurl = @HUBOT_TANGOCARD_ROOTURL() + url
        $.ajax
            type: 'POST'
            url: fullurl
            dataType: 'json'
            success: success
            error: error
            data: JSON.stringify data
            headers:
                Authorization: @basic_auth()

    tangocard_setup: ->
        auth = @HUBOT_TANGOCARD_AUTH()
        cust = @HUBOT_TANGOCARD_CUSTOMER()
        acct = @HUBOT_TANGOCARD_ACCOUNT() || 'HubotHighfive'
        email = @HUBOT_TANGOCARD_EMAIL()

        # TODO: validate inputs

        # Check the account status
        setupAccount = $.Deferred()
        @tangocard_get "accounts/#{cust}/#{acct}", (resp) ->
            console.log "Account exists"
            setupAccount.resolve()
        , =>
            console.log "Account doesn't exist; creating"
            @tangocard_post 'accounts',
                customer: cust
                identifier: acct
                email: email
            , (resp) ->
                console.log "Success."
                setupAccount.resolve()
            , (xhr, status, err) ->
                console.log "Error creating account: #{status} / #{err}"
                setupAccount.reject()

        # TODO: create the credit card
        setupAccount.then ->
            console.log "Account setup done"

        @HUBOT_TANGOCARD_CC "(something with #{auth})"

$ ->
    window.vm = new MainViewModel()

    $.getJSON 'values.json', (data) ->
        console.log data
        for k,v of data
            vm[k](v)

    ko.applyBindings vm

    $('#configoutput').click ->
        @select()
