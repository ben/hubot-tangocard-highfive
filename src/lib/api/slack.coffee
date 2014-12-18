BaseApiApp = require './base'

# Slack API helper class
class SlackApp extends BaseApiApp
    constructor: (robot) ->
        super robot, 'https://slack.com/api/',
            token: process.env.HUBOT_SLACK_TOKEN

    listUsers: (callback) ->
        @get 'users.list', callback

    getUser: (uid, callback) ->
        @get "users.info?user=#{uid}", callback

module.exports = SlackApp
