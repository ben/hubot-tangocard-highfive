module.exports = (robot, randomGifFetcher) ->

    user: (uid, callback) ->
        callback robot.brain.userForName(uid)

    message: (roomid, from_user, to_user, reason) ->
        robot.messageRoom roomid, """
        #{randomGifFetcher()}
        WOOOOOOOOO! #{from_user.name} is high-fiving #{to_user.name} for #{reason}!
        """

    double: (roomid, doubleChooser) ->
        robot.messageRoom roomid, "DAILY DOUBLE! #{doubleChooser()}"

    boomerang: (roomid, user) ->
        robot.messageRoom roomid, "BOOMERANG! You're getting $10 too, #{user.name}!"
