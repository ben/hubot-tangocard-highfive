class BaseApiApp
    constructor: (@robot, @baseurl, @opts) ->

    requester: (endpoint) ->
        @robot.http("#{@baseurl}#{endpoint}").headers(@opts).query(@opts)

    get: (endpoint, callback) ->
        @requester(endpoint).get() (err, res, body) ->
            try
                json = JSON.parse body
            catch error
                @robot.logger.info "API error: #{err}"
            callback json

    post: (endpoint, data, callback) ->
        data = JSON.stringify data
        @requester(endpoint).post(data) (err, res, body) ->
            try
                json = JSON.parse body
            catch error
                @robot.logger.info "API error: #{err}"
            callback json

module.exports = BaseApiApp
