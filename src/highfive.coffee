# Description:
#   Reward awesomeness with public recognition and (maybe) dollars.
#
# Commands
#   hubot highfive @<user> for <awesome thing> - makes a loud announcement in a public chatroom
#   hubot highfive @<user> $<amount> for <awesome thing> - makes a loud announcement and sends the user an Amazon.com giftcard
module.exports = (robot) ->
    robot.respond /ping/i, (msg) ->
        msg.reply 'PONG'
