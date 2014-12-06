# Description:
#   Reward awesomeness with public recognition and (maybe) dollars.
#
# Commands
#   hubot highfive @<user> for <awesome thing> - makes a loud announcement in a public chatroom
#   hubot highfive @<user> $<amount> for <awesome thing> - makes a loud announcement and sends the user an Amazon.com giftcard

module.exports = (robot) ->
    # Services for getting emails from users
    email_fetchers =
        slack: (uid, callback) ->
            new SlackApp(robot).getUser uid, (resp) ->
                callback resp.user.profile.email
        dummy: (uid, callback) ->
            callback "#{uid}@example.com"

    email_fetcher = email_fetchers[process.env.HUBOT_HIGHFIVE_EMAIL_SERVICE || 'slack']

    # The main responder
    robot.respond /highfive (@\S+)( \$(\d+))? for (.*)/, (msg) ->
        to_user = robot.brain.userForName msg.match[1][1..]
        from_user = msg.message.user
        amt = parseInt(msg.match[3] or 0)
        reason = msg.match[4]

        # Safety checks:
        # - Don't target a nonexistent user
        # - Don't send money to yourself
        # - $200 or less
        # - Any others?
        unless to_user
            return msg.reply "Who's #{msg.match[1]}?"
        if to_user.name == from_user.name
            return msg.reply "High-fiving yourself is just clapping."
        if amt > 200
            return msg.reply "$#{amt} is more like a high-500. Think smaller."

        # TODO: more noise
        msg.send "WOOOOOO #{to_user.name}! #{from_user.name} is high-fiving you for #{reason}!"

        if amt > 0
            # Get an email address for sending the giftcard
            email_fetcher to_user.id, (to_email) ->
                msg.send "$#{amt} is on its way to #{to_email} as we speak!"

class BaseApiApp
    constructor: (@robot, @baseurl, @queryopts) ->

    requester: (endpoint) ->
        @robot.http("#{@baseurl}#{endpoint}").query(@queryopts)

    get: (endpoint, callback) ->
        console.log
        @requester(endpoint).get() (err, res, body) =>
            console.log err, body
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
