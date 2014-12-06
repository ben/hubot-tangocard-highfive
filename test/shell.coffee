Adapter = require 'hubot/src/adapter'

# Mock adapter

class MockAdapter extends Adapter
    genericEmit = (evt) ->
        # console.log "wrapping #{evt}"
        return (envelope, strings...) ->
            # console.log "-- Emitting #{evt} with '#{strings}'"
            @emit evt, envelope, strings...

    constructor: (robot) ->
        super(robot)

        @send =  genericEmit 'send'
        @reply = genericEmit 'reply'
        @topic = genericEmit 'topic'
        @play =  genericEmit 'play'

    run: -> @emit 'connected'
    close: -> @emit 'closed'


exports.use = (robot) ->
    new MockAdapter robot
