# Example implementation for a chat service. This exports three endpoints:
#
# - `user` takes a user name and returns an object with (at least) `name`, `id`, and `email` properties
# - `message` takes a room name/id, a "from" user, and a "to" user, and a high-five reason, and it pumps out an appropriately noisy message into the room.

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
            user

        user = do theUser
        return callback(user) if user

        # Not found; refresh the cache
        slack.listUsers (resp) ->
            users_cache = resp.members
            callback theUser()

    message: (roomid, from_user, to_user, reason) ->
        message = """
        #{gifGenerator()}
        <!channel> WOOOOOOOOO! <@#{from_user.name}> is high-fiving <@#{to_user.name}> for #{reason}!
        """
        robot.adapter.send {room: roomid}, message
