# Description:
#   Reward awesomeness with public recognition and (maybe) dollars.
#
# Commands:
#   hubot highfive @<user> for <awesome thing> - makes a loud announcement in a public chatroom
#   hubot highfive @<user> $<amount> for <awesome thing> - makes a loud announcement and sends the user an Amazon.com giftcard
#   hubot highfive config - show URL for configuration UI
#   hubot highfive stats - show stats about high-fives

Path = require 'path'
fs = require 'fs'
coffee = require 'coffee-script'
moment = require 'moment'

TangoApp = require './lib/api/tangocard'
sheet = require './lib/sheet'
tango = require './lib/tango'

try
    ChatService = require "./lib/#{process.env.HUBOT_HIGHFIVE_CHAT_SERVICE}_chat_service"
catch
    console.log "HIGHFIVE Falling back to dummy chat service. You probably don't want this; set HUBOT_HIGHFIVE_CHAT_SERVICE to fix it."
    ChatService = require './lib/dummy_chat_service'

double_rate = parseFloat(process.env.HUBOT_HIGHFIVE_DOUBLE_RATE || 0.1)
boomerang_rate = parseFloat(process.env.HUBOT_HIGHFIVE_BOOMERANG_RATE || 0.1)

module.exports = (robot) ->
    robot.logger.info "double rate is #{double_rate}"
    robot.logger.info "boomerang rate is #{boomerang_rate}"

    # Random GIF choice, including extras from the environment
    extra_gifs = []
    if process.env.HUBOT_HIGHFIVE_GIFS
        try
            env_gifs = process.env.HUBOT_HIGHFIVE_GIFS.split /\s+/
            extra_gifs = (g for g in env_gifs when g)
            robot.logger.debug "Gifs is now #{JSON.stringify GIFs.concat(extra_gifs)}"
        catch e
            robot.logger.warning "HUBOT_HIGHFIVE_GIFS isn't parseable. Check the readme for proper formatting. (#{e} '#{process.env.HUBOT_HIGHFIVE_GIFS}')"
    gifChooser = ->
        allgifs = GIFs.concat(extra_gifs)
        allgifs[ Math.floor(Math.random() * allgifs.length) ]
    doubleChooser = ->
        doubleGifs[ Math.floor(Math.random() * doubleGifs.length) ]

    # Utility for getting two users at once
    chatService = ChatService(robot, gifChooser)
    userFetcher = (uid1, uid2, callback) ->
        chatService.user uid1, (uobj1) ->
            chatService.user uid2, (uobj2) ->
                callback uobj1, uobj2

    # Helper for recording daily limits. Returns two values:
    # - Whether or not the user can spend `amount`
    # - The new daily total. This includes `amount` if it fits within the limit.
    record_daily_total = (username, amount) ->
        yesterday = moment().subtract 1, 'day'
        limit = parseInt(process.env.HUBOT_HIGHFIVE_DAILY_LIMIT || 500)
        # Fetch from brain
        current_totals = robot.brain.get('highfive_daily_totals') or {}
        # Calculate the running total in the last 24 hours
        users_totals = (current_totals[username] or [])
        users_totals = users_totals.filter((x) -> x.date >= yesterday)
        total = users_totals.reduce ((acc,x) -> acc + x.amt), 0
        unless total + amount <= limit
            # Too much
            return [false, total]
        # Permission granted. Record the gift.
        users_totals.push
            date: moment()
            amt: amount
        current_totals[username] = users_totals
        robot.brain.set 'highfive_daily_totals', current_totals
        robot.logger.debug "HIGHFIVE daily totals #{JSON.stringify robot.brain.get 'highfive_daily_totals'}"
        [true, total + amount]

    # Config UI serving
    configpath = Path.join __dirname, '..', 'config'
    route_to_file = (route, file) ->
        robot.router.get "/highfive/#{route}", (req, res) ->
            res.sendfile Path.join configpath, file
    route_to_file '', 'config.html'
    route_to_file 'config.css', 'config.css'
    route_to_file 'gridforms.js', 'gridforms.js'
    robot.router.get '/highfive/config.js', (req, res) ->
        res.set 'Content-Type', 'application/javascript'
        cs = fs.readFileSync Path.join(configpath, 'config.coffee'), 'utf-8'
        res.send coffee.compile cs
    robot.router.get '/highfive/values.json', (req, res) ->
        res.set 'Content-Type', 'application/x-javascript'
        data = {}
        envvars = [
            'HUBOT_HIGHFIVE_CHAT_SERVICE',
            'HUBOT_HIGHFIVE_ROOM',
            'HUBOT_HIGHFIVE_AWARD_LIMIT',
            'HUBOT_HIGHFIVE_DAILY_LIMIT',
            'HUBOT_HIGHFIVE_DOUBLE_RATE',
            'HUBOT_HIGHFIVE_BOOMERANG_RATE',
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
        data.ipaddr = require('ip').address()
        res.send JSON.stringify data

    # Ask for the config UI
    robot.respond /highfive config/, (msg) ->
        hostname = process.env.HUBOT_HOSTNAME || 'http://localhost:8080'
        msg.reply "#{hostname}/highfive/"

    robot.respond /highfive stats/, (msg) ->
        sheet.stats msg

    # The main responder
    robot.respond /highfive (.+?)(?: +\$(\S+))? +(?:for )?(.*)/, (msg) ->
        robot.logger.debug msg.match[1], msg.match[2], msg.match[3]
        from_user = msg.message.user.name
        to_user = msg.match[1][1..]
        amt = parseFloat(msg.match[2] or 0)
        awardLimit = parseInt(process.env.HUBOT_HIGHFIVE_AWARD_LIMIT || 150)
        reason = msg.match[3]
        robot.logger.debug "from `#{from_user}` to `#{to_user}` amount `#{amt}` reason `#{reason}`"
        userFetcher from_user, to_user, (from_obj, to_obj) ->
            robot.logger.debug "from #{from_obj?.email} to #{to_obj?.email}"

            draw1 = Math.random()
            draw2 = Math.random()
            do_double = draw1 < double_rate
            do_boomerang = draw2 < boomerang_rate
            robot.logger.info "Double #{draw1} < #{double_rate} => #{do_double}"
            robot.logger.info "Boomerang #{draw2} < #{boomerang_rate} => #{do_boomerang}"

            # Safety checks:
            # Don't target a nonexistent user or a robot
            if to_obj?.is_bot
                return msg.reply "Robots don't _do_ high fives."
            unless to_obj?.email
                return msg.reply "Who's #{msg.match[1]}?"
            # Don't target yourself
            if to_obj?.email == from_obj?.email
                return msg.reply "High-fiving yourself is just clapping."
            # Apply value limits
            if amt > 0 and awardLimit == 0
                return msg.reply "Gift cards are disabled."
            if amt > awardLimit
                return msg.reply "$#{amt} is more like a high-500. Think smaller, like maybe $#{awardLimit || 150} or less."
            # Daily limit from each user
            [allowed, total] = record_daily_total from_user, amt
            unless allowed
                limit = parseInt(process.env.HUBOT_HIGHFIVE_DAILY_LIMIT || 500)
                robot.logger.info "HIGHFIVE #{from_user} tried to send $#{amt}, but has already sent $#{total} (limit is $#{limit})"
                return msg.reply "Sorry, you've already gifted $#{total} in the last 24 hours. Keep it under $#{limit}, please."

            # I guess it's okay. Make some noise.
            roomid = process.env.HUBOT_HIGHFIVE_ROOM || msg.envelope.room
            chatService.message roomid, from_obj, to_obj, reason

            # Daily Double! Randomly double the award amount
            if do_double
                amt *= 2
                chatService.double roomid, doubleChooser

            if amt == 0
                sheet.logToSheet robot, [
                    moment().format('YYYY/MM/DD HH:mm:ss'), # date
                    from_obj.email,                         # from
                    to_obj.email,                           # to
                    amt,                                    # amount
                    reason,                                 # reason
                    '',                                     # gift card code
                    # TODO: link to transcript?
                  ]
            if awardLimit != 0 and amt > 0
                return tango(robot).order msg, from_obj, to_obj, amt, reason
                , (order) ->
                    msg.send "A $#{amt} gift card is on its way!"
                    m = moment(order.delivered_at).format 'YYYY/MM/DD HH:mm:ss'
                    sheet.logToSheet robot, [
                        m,                    # date
                        from_obj.email,       # from
                        to_obj.email,         # to
                        amt,                  # amount
                        reason,               # why
                        order.reward.number,  # gift card code
                        # TODO: link to transcript?
                    ]

                    # Randomly high-five back $10
                    if do_boomerang
                        return tango(robot).order msg, from_obj, from_obj, 10, 'Boomerang'
                        , (order) ->
                            chatService.boomerang roomid, from_obj, 
                            sheet.logToSheet robot, [
                                m,
                                from_obj.email,
                                from_obj.email,
                                10,
                                '(Boomerang)',
                                order.reward.number,
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
    'http://i.giphy.com/lcYFNTaz4U9jy.gif',
    'http://i.giphy.com/Dwu7IpRyVA5Nu.gif',
    'http://i.giphy.com/JQNM4AgN7lFUA.gif',
    'http://i.giphy.com/9MGNxEMdWB2tq.gif',
    'http://i.giphy.com/V5VZ64VJp1neo.gif',
    'http://i.giphy.com/LdnaND03GRE9q.gif',
    'http://i.giphy.com/2FazevvcDdyrf1E7C.gif',
    'http://i.giphy.com/il5XqHUQxAdVe.gif',
    'http://i.giphy.com/2AlVpRyjAAN2.gif',
    'http://i.giphy.com/r2BtghAUTmpP2.gif',
    'http://i.giphy.com/fD2tbCl4snSi4.gif',
    'http://persephonemagazine.com/wp-content/uploads/2013/02/borat-letterman-high-five.gif',
    'http://i.giphy.com/10ThjPOApliaSA.gif',
    'http://i.giphy.com/14rRtgywkOitDa.gif',
    'http://i.giphy.com/rM9Cl7MZphBqU.gif',
    'http://i.giphy.com/t8JeALG3O5SPS.gif',
    'http://i.giphy.com/rSCVJasn8uZP2.gif',
    'http://i.giphy.com/10LKovKon8DENq.gif',
    'http://i.giphy.com/M9TuBZs3LIQz6.gif',
    'http://i.giphy.com/Ch7el3epcW3Wo.gif',
    'http://i.giphy.com/1HPzxMBCTvjMs.gif',
    'http://i.giphy.com/BP9eSu9cnnGN2.gif',
    'http://i.giphy.com/vuFJaBLVTtnZS.gif',
    'http://i.giphy.com/PTJGTImkgRycU.gif',
    'http://i.giphy.com/l41lHvfYqxWus1oYw.gif',
    'http://i.giphy.com/xIhGpmuVtuEpi.gif',
]

doubleGifs = [
    'http://38.media.tumblr.com/95c33d41c60bdacf23d283afc8f334cd/tumblr_mlnjwx8GHP1r7w8cbo1_250.gif',
    'http://33.media.tumblr.com/214e4048f22e926ded55fd4ae241f6ec/tumblr_mnf63iWNST1rdmnfqo1_500.gif',
    'http://media.giphy.com/media/tBb19f3Vpki3RF6ukne/giphy.gif',
    'http://media.giphy.com/media/hxXTaintauS9G/giphy.gif',
    'http://cdn.gifbay.com/2013/01/insane_double_backflip-25659.gif',
    'http://i.imgur.com/Zed3hiu.gif',
]
