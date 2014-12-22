class MainViewModel
    constructor: ->
        @services = [
            'slack'
        ]

        @fieldnames = [
            'HUBOT_HIGHFIVE_CHAT_SERVICE',
            'HUBOT_HIGHFIVE_ROOM',
            'HUBOT_HIGHFIVE_AWARD_LIMIT',
            'HUBOT_HIGHFIVE_DAILY_LIMIT',
            'HUBOT_TANGOCARD_ROOTURL'
            'HUBOT_TANGOCARD_USER',
            'HUBOT_TANGOCARD_KEY',
            'HUBOT_TANGOCARD_CC',
            'HUBOT_TANGOCARD_AUTH',
            'HUBOT_TANGOCARD_CUSTOMER',
            'HUBOT_TANGOCARD_ACCOUNT',
            'HUBOT_TANGOCARD_EMAIL',
            'HUBOT_HIGHFIVE_SHEET_EMAIL',
            'HUBOT_HIGHFIVE_SHEET_KEY',
            'HUBOT_HIGHFIVE_SHEET_DOCID',
            'HUBOT_HIGHFIVE_SHEET_SHEETNAME',
        ]

        for f in @fieldnames
            @[f] = ko.observable()

        @cc_number = ko.observable ''
        @cc_expiration = ko.observable ''
        @cc_fname = ko.observable ''
        @cc_lname = ko.observable ''
        @cc_address = ko.observable ''
        @cc_city = ko.observable ''
        @cc_state = ko.observable ''
        @cc_zip = ko.observable ''
        @cc_country = ko.observable ''
        @tangocard_status = ko.observable ''
        @tangocard_class = ko.observable ''
        @cardnote = ko.observable 'optional'
        @cardclass = ko.computed =>
            if @cardnote() == 'optional'
                ''
            else
                'success'

        @configoutput = ko.computed =>
            vars = []
            for k in @fieldnames
                v = @[k]()
                vars.push "#{k}='#{v}'" if v? and v != ''
            vars.join ' \\\n'

    basic_auth: ->
        user = @HUBOT_TANGOCARD_USER()
        pass = @HUBOT_TANGOCARD_KEY()
        "Basic " + btoa(user + ":" + pass)

    tangocard_get: (url, success, error) ->
        baseurl = @HUBOT_TANGOCARD_ROOTURL() || 'https://api.tangocard.com/raas/v1/'
        fullurl = "#{baseurl}#{url}"
        $.ajax
            type: 'GET'
            url: fullurl
            dataType: 'json'
            success: success
            error: error
            headers:
                Authorization: @basic_auth()

    tangocard_post: (url, data, success, error) ->
        baseurl = @HUBOT_TANGOCARD_ROOTURL() || 'https://api.tangocard.com/raas/v1/'
        fullurl = "#{baseurl}#{url}"
        $.ajax
            type: 'POST'
            url: fullurl
            dataType: 'json'
            success: success
            error: error
            data: JSON.stringify data
            headers:
                Authorization: @basic_auth()

    set_tangocard_error: (msg) ->
        @tangocard_status msg
        @tangocard_class 'fail'

    tangocard_setup: ->
        cc = @HUBOT_TANGOCARD_CC()
        auth = @HUBOT_TANGOCARD_AUTH()
        cust = @HUBOT_TANGOCARD_CUSTOMER()
        acct = @HUBOT_TANGOCARD_ACCOUNT() || 'HubotHighfive'
        email = @HUBOT_TANGOCARD_EMAIL()

        @tangocard_class ''
        @tangocard_status 'Checking customer/account status...'

        # TODO: validate inputs

        # Check the account status
        setupAccount = $.Deferred()
        @tangocard_get "accounts/#{cust}/#{acct}"
        , (resp) ->
            setupAccount.resolve()
        , (xhr, status, err) =>
            if xhr.status == 401
                @set_tangocard_error 'Invalid credentials'
                return setupAccount.reject()
            if xhr.status != 404
                @set_tangocard_error "Error: #{err}"
                return setupAccount.reject()

            @tangocard_post 'accounts',
                customer: cust
                identifier: acct
                email: email
            , (resp) ->
                setupAccount.resolve()
            , (xhr, status, err) =>
                @tangocard_status "Error creating account: #{xhr.responseJSON.invalid_inputs_message}"
                @tangocard_class 'fail'
                setupAccount.reject()


        # TODO: create the credit card
        setupAccount.then =>
            ip = require('ip').address()
            # Create the credit card
            data =
                customer: cust
                account_identifier: acct
                client_ip: ip
                credit_card:
                    number: @cc_number()
                    security_code: auth
                    expiration: @cc_expiration()
                    billing_address:
                        f_name: @cc_fname()
                        l_name: @cc_lname()
                        address: @cc_address()
                        city: @cc_city()
                        state: @cc_state()
                        zip: @cc_zip()
                        country: @cc_country()
                        email: email
            @tangocard_post 'cc_register', data
            , (resp) =>
                console.log resp
                @HUBOT_TANGOCARD_CC resp.cc_token
                @tangocard_status 'Success!'
                @tangocard_class 'success'

            , (xhr, status, err) =>
                json = xhr.responseJSON
                if xhr.responseJSON.denial_code == 'CC_DUPREGISTER'
                    return @set_tangocard_error 'This card is already registered. Contact Tango Card to have it removed.'

                errmsg = json.invalid_inputs_message || json.error_message || json.denial_message
                return @set_tangocard_error errmsg

$ ->
    window.vm = new MainViewModel()

    $.getJSON 'values.json', (data) ->
        console.log data
        for k,v of data
            vm[k](v)
        if (data.HUBOT_TANGOCARD_CC || '') != ''
            vm.cardnote 'already completed'

    ko.applyBindings vm

    $('.config-text-area').click ->
        @select()
