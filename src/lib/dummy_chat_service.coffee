module.exports = (robot) ->

    user: (uid, callback) ->
        callback robot.brain.userForName(uid)

    message: (roomid, str) ->
        robot.messageRoom roomid, str
