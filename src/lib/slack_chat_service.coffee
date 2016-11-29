# Example implementation for a chat service. This exports three endpoints:
#
# - `user` takes a user name and returns an object with (at least) `name`, `id`, and `email` properties
# - `message` takes a room name/id, a "from" user, and a "to" user, and a high-five reason, and it pumps out an appropriately noisy message into the room.
# - `double` takes a room name/id, and announces a daily double
# - `boomerang` takes a room name/id and a user, and announces that that user is getting $10

SlackApp = require './api/slack'


users_cache = []
channel_cache = []

module.exports = (robot, gifGenerator) ->
    slack = new SlackApp(robot)

    user: (uid, callback) ->
        # If the user is mentioned, uid looks like `<@U123456>`
        # If not, uid looks like `username`
        uid = uid.replace /^[<@]*|[>]$/gm, ''
        theUser = ->
            user = (u for u in users_cache when uid in [u.name, u.id])[0]
            user.email = user.profile.email if user
            user.real_name ?= user.profile.real_name if user
            user

        user = do theUser
        return callback(user) if user

        # Not found; refresh the cache
        robot.logger.debug "HIGHFIVE refreshing Slack user cache"
        slack.listUsers (resp) ->
            robot.logger.info "Slack error:", resp.error unless resp.ok
            users_cache = resp.members || []
            callback theUser()

    message: (roomid, from_user, to_user, reason) ->
        message = """
        #{gifGenerator()}
        <!channel> WOOOOOOOOO! <@#{from_user.name}> is high-fiving <@#{to_user.name}> for #{reason}!
        """
        robot.adapter.send {room: roomid}, message

    double: (roomid, doubleChooser) ->
        robot.messageRoom roomid, "*DAILY DOUBLE!* #{doubleChooser()}"

    boomerang: (roomid, user) ->
        robot.messageRoom roomid, "*BOOMERANG!* You're getting $10 too, <@#{user.name}>!"
