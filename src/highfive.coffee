# Description:
#   Reward awesomeness with public recognition and (maybe) dollars.
#
# Commands:
#   hubot highfive @<user> for <awesome thing> - makes a loud announcement in a public chatroom
#   hubot highfive @<user> $<amount> for <awesome thing> - makes a loud announcement and sends the user an Amazon.com giftcard
#   hubot highfive config - show URL for configuration UI

Path = require 'path'
fs = require 'fs'
coffee = require 'coffee-script'

TangoApp = require './lib/api/tangocard'
SlackApp = require './lib/api/slack'
logToSheet = require './lib/sheet'

try
    ChatService = require "./lib/#{process.env.HUBOT_HIGHFIVE_CHAT_SERVICE}_chat_service"
catch
    robot.logger.info "HIGHFIVE Falling back to dummy chat service. You probably don't want this; set HUBOT_HIGHFIVE_CHAT_SERVICE to fix it."
    ChatService = require './lib/dummy_chat_service'

module.exports = (robot) ->

    # Utility for getting two users at once
    chatService = ChatService(robot, -> GIFs[ Math.floor(Math.random() * GIFs.length) ])
    userFetcher = (uid1, uid2, callback) ->
        chatService.user uid1, (uobj1) ->
            chatService.user uid2, (uobj2) ->
                callback uobj1, uobj2

    # Config UI serving
    configpath = Path.join __dirname, '..', 'config'
    robot.router.get '/highfive/', (req, res) ->
        res.set 'Content-Type', 'text/html'
        res.sendfile Path.join configpath, 'config.html'
    robot.router.get '/highfive/config.css', (req, res) ->
        res.set 'Content-Type', 'text/css'
        res.sendfile Path.join configpath, 'config.css'
    robot.router.get '/highfive/gridforms.js', (req, res) ->
        res.set 'Content-Type', 'application/x-javascript'
        res.sendfile Path.join configpath, 'gridforms.js'
    robot.router.get '/highfive/config.js', (req, res) ->
        res.set 'Content-Type', 'application/x-javascript'
        cs = fs.readFileSync Path.join(configpath, 'config.coffee'), 'utf-8'
        js = coffee.compile cs
        res.send js
    robot.router.get '/highfive/values.json', (req, res) ->
        res.set 'Content-Type', 'application/x-javascript'
        data = {}
        envvars = [
            'HUBOT_HIGHFIVE_CHAT_SERVICE',
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
            'HUBOT_HIGHFIVE_SHEET_EMAIL',
            'HUBOT_HIGHFIVE_SHEET_KEY',
            'HUBOT_HIGHFIVE_SHEET_DOCID',
            'HUBOT_HIGHFIVE_SHEET_SHEETNAME',
        ]
        for v in envvars
            data[v] = process.env[v] || ''
        res.send JSON.stringify data

    # Ask for the config UI
    robot.respond /highfive config/, (msg) ->
        hostname = process.env.HUBOT_HOSTNAME || 'http://localhost:8080'
        msg.reply "#{hostname}/highfive/"

    # The main responder
    robot.respond /highfive (.+?)( \$(\d+))? for (.*)/, (msg) ->
        from_user = msg.message.user.name
        to_user = msg.match[1][1..]
        amt = parseInt(msg.match[3] or 0)
        reason = msg.match[4]
        robot.logger.debug "from `#{from_user}` to `#{to_user}` amount `#{amt}` reason `#{reason}`"
        userFetcher from_user, to_user, (from_obj, to_obj) ->
            robot.logger.debug "from #{from_obj?.email} to #{to_obj?.email}"
            # Safety checks:
            # - Don't target a nonexistent user
            # - Don't target yourself
            # - $150 or less
            # - Any others?
            unless to_obj?.email
                return msg.reply "Who's #{msg.match[1]}?"
            if to_obj?.email == from_obj?.email
                return msg.reply "High-fiving yourself is just clapping."
            if amt > (process.env.HUBOT_HIGHFIVE_AWARD_LIMIT || 150)
                return msg.reply "$#{amt} is more like a high-500. Think smaller."

            roomid = process.env.HUBOT_HIGHFIVE_ROOM || msg.envelope.room
            chatService.message roomid, from_obj, to_obj, reason

            if amt > 0 and process.env.HUBOT_HIGHFIVE_AWARD_LIMIT != 0
                tango = new TangoApp(robot)
                cust = process.env.HUBOT_TANGOCARD_CUSTOMER
                acct = process.env.HUBOT_TANGOCARD_ACCOUNT

                tango.getAccountStatus cust, acct, (resp) ->
                    robot.logger.debug "account status `#{JSON.stringify resp}`"

                    unless resp.success
                        return msg.send "(Problem getting Tango Card status: '#{resp.error_message}'. You might want 'highfive config'.)"
                    return sendCard() if resp.account.available_balance/100 >= amt

                    # Insufficient balance, attempt to fund the account
                    amtToFund = (process.env.HUBOT_HIGHFIVE_AWARD_LIMIT || 150) * 2 * 100 # in cents
                    cc = process.env.HUBOT_TANGOCARD_CC
                    auth = process.env.HUBOT_TANGOCARD_AUTH
                    robot.http('http://jsonip.com').get() (err, res, body) ->
                        jsonip = JSON.parse body

                        tango.fundAccount cust, acct, amtToFund, jsonip.ip, cc, auth, (resp) ->
                            robot.logger.debug "funding response `#{JSON.stringify resp}`"
                            unless resp.success
                                return msg.send "(Problem funding Tango Card account: '#{resp.denial_message}'. You might want 'highfive config'.)"
                            return sendCard() if resp.success

                sendCard = ->
                    message = "High five for #{reason}!"
                    tango.orderAmazonDotComCard cust, acct, 'High-five', amt*100, from_user, 'High Five!', to_user, to_obj.email, message, (resp) ->
                        robot.logger.debug "order response `#{JSON.stringify resp}`"
                        unless resp.success
                            errmsg = resp.invalid_inputs_message || resp.error_message || resp.denial_message
                            return msg.send "(Problem ordering gift card: '#{errmsg}'. You might want 'highfive config'.)"
                        msg.send "A $#{amt} gift card is on its way!"
                        logToSheet [
                            resp.order.delivered_at,    # date
                            from_obj.email,                 # from
                            to_obj.email,                   # to
                            amt,                        # amount
                            reason,                     # why
                            resp.order.reward.number,   # gift card code
                        ]


# GIFs for celebration
GIFs = [
    'http://i.giphy.com/zl170rmVMCpEY.gif',
    'http://i.giphy.com/yoJC2vEwxkwbMZmSCk.gif',
    'http://i.giphy.com/Qh5dZDCFqr1dK.gif',
    'http://i.giphy.com/GCLlQnV7wzKLu.gif',
    'http://i.giphy.com/MhHXeM4SpKrpC.gif',
    'http://i.giphy.com/Z7bxVQl7nWes.gif',
    'http://i.giphy.com/ns8SCo6O6g7nO.gif',
    'http://a.fod4.com/images/GifGuide/dancing/280sw007883.gif',
    'http://a.fod4.com/images/GifGuide/dancing/pr2.gif',
    'http://0.media.collegehumor.cvcdn.com/46/28/291cb0abc0c99142aace1353dc12b755-car-race-high-five.gif',
    'http://2.media.collegehumor.cvcdn.com/75/26/b31d5b98a4a27537d075960b7b247773-giant-high-five-from-jackass.gif',
    'http://2.media.collegehumor.cvcdn.com/84/67/ff88c44dec5f9c2747e30549a375d481-bear-high-five.gif',
    'http://0.media.collegehumor.cvcdn.com/17/53/30709bc3c9b060baf771c0b2e2626f95-snow-white-high-five.gif',
    'http://i.giphy.com/p3LmvxiO6noGc.gif',
    'http://i.giphy.com/DYvroxifyHEmA.gif',
    'http://i.giphy.com/kolvlRnXh8Jj2.gif',
    'http://i.giphy.com/tX5iDEX1n1Xxe.gif',
    'http://i.giphy.com/xeXEpUVvAxCV2.gif',
    'http://i.giphy.com/UkhHIZ37IDRGo.gif',
    'http://i.giphy.com/oUZqX2UgK2xnq.gif',
    'http://a.fod4.com/images/GifGuide/dancing/163563561.gif',
    'http://i.giphy.com/mEOjrcTumos80.gif',
    'http://i.giphy.com/99dauSQPLUuIg.gif',
    'http://i.giphy.com/3HICMfLGqgWRy.gif',
    'http://i.giphy.com/GYU7rBEQtBGfe.gif',
    'http://i.giphy.com/vXEeRBP3QeJ2w.gif',
    'http://i.giphy.com/Cj3Ce7e8h2EKY.gif',
    'http://i.giphy.com/3Xtt7hlXvUTvi.gif',
    'http://i.giphy.com/1453cgfKvRLMyc.gif',
    'http://i.giphy.com/WdxAL8nmOCQ5a.gif',
    'http://a.fod4.com/images/GifGuide/dancing/tumblr_llatbbCeky1qbnthu.gif',
    'http://i.giphy.com/FrDlVZMD96nzG.gif',
]
