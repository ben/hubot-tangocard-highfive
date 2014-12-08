# Description:
#   Reward awesomeness with public recognition and (maybe) dollars.
#
# Commands:
#   hubot highfive @<user> for <awesome thing> - makes a loud announcement in a public chatroom
#   hubot highfive @<user> $<amount> for <awesome thing> - makes a loud announcement and sends the user an Amazon.com giftcard
#
# Configuration:
#   HUBOT_HIGHFIVE_EMAIL_SERVICE - Service for looking up email addresses by user names (defaults to 'slack')
#   HUBOT_SLACK_API_TOKEN - If using the 'slack' email service, this is your API token. Get one from https://api.slack.com/tokens
#   HUBOT_HIGHFIVE_ROOM - Room for making noise when someone is high-fived. Defaults to the room the request was made in
#   HUBOT_HIGHFIVE_AWARD_LIMIT - upper limit for giftcard awards. Set to 0 to disable giftcards. Default is 150.

module.exports = (robot) ->
    # Services for getting emails from users
    email_fetchers =
        slack: (username1, username2, callback) ->
            new SlackApp(robot).listUsers (resp) ->
                grabber = (name) ->
                    (x.profile.email for x in resp.members when x.name == name)[0]
                [e1, e2] = (grabber(u) for u in [username1, username2])
                callback e1, e2
        dummy: (username1, username2, callback) ->
            # This is for testing.
            [e1, e2] = (robot.brain.userForName(u)?.email for u in [username1, username2])
            callback e1, e2

    email_fetcher = email_fetchers[process.env.HUBOT_HIGHFIVE_EMAIL_SERVICE || 'slack']

    # The main responder
    robot.respond /highfive (@\S+)( \$(\d+))? for (.*)/, (msg) ->
        from_user = msg.message.user.name
        to_user = msg.match[1][1..]
        amt = parseInt(msg.match[3] or 0)
        reason = msg.match[4]

        email_fetcher from_user, to_user, (from_email, to_email) ->
            # Safety checks:
            # - Don't target a nonexistent user
            # - Don't send money to yourself
            # - $150 or less
            # - Any others?
            unless to_email
                return msg.reply "Who's #{msg.match[1]}?"
            if to_email == from_email
                return msg.reply "High-fiving yourself is just clapping."
            if amt > (process.env.HUBOT_HIGHFIVE_AWARD_LIMIT || 150)
                return msg.reply "$#{amt} is more like a high-500. Think smaller."

            # TODO: more noise
            msg.send """
            @channel WOOOOOO #{to_user}!
            #{from_user} is high-fiving you for #{reason}!
            """

            if amt > 0 and process.env.HUBOT_HIGHFIVE_AWARD_LIMIT != 0
                msg.send "A $#{amt} gift card is on its way as we speak!"
                # TODO: tangocard API

        , (e1, e2) -> # error callback from email_fetcher
            console.log "ERROR '#{e1}' '#{e2}'"
            msg.reply "Who's #{msg.match[1]}?" unless e1

class BaseApiApp
    constructor: (@robot, @baseurl, @queryopts) ->

    requester: (endpoint) ->
        @robot.http("#{@baseurl}#{endpoint}").query(@queryopts)

    get: (endpoint, callback) ->
        @requester(endpoint).get() (err, res, body) =>
            try
                json = JSON.parse body
            catch error
                console.log "API error: #{err}"
            callback json

# Slack API helper class
class SlackApp extends BaseApiApp
    constructor: (robot) ->
        super robot, 'https://slack.com/api/',
            token: process.env.HUBOT_SLACK_API_TOKEN

    listUsers: (callback) ->
        @get 'users.list', callback

    getUser: (uid, callback) ->
        @get "users.info?user=#{uid}", callback
