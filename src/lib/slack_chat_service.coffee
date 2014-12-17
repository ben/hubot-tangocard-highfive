# Example implementation for a chat service. This exports three endpoints:
#
# - `user` takes a user name and returns an object with (at least) `name`, `id`, and `email` properties
# - `message` takes a room name/id and a string to send.

SlackApp = require './api/slack'

users_cache = []

module.exports = (robot) ->
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
        new SlackApp(robot).listUsers (resp) ->
            users_cache = resp.members
            callback theUser()

    message: (roomid, str) ->
        # TODO: linkify user and channel mentions
        robot.messageRoom room id, str
