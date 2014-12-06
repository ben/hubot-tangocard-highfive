# Description:
#   Reward awesomeness with public recognition and (maybe) dollars.
#
# Commands
#   hubot highfive @<user> for <awesome thing> - makes a loud announcement in a public chatroom
#   hubot highfive @<user> $<amount> for <awesome thing> - makes a loud announcement and sends the user an Amazon.com giftcard
module.exports = (robot) ->
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
