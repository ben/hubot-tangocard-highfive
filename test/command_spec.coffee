# Hubot classes
Robot = require "hubot/src/robot"
TextMessage = require("hubot/src/message").TextMessage
path = require 'path'

# Load assertion methods to this scope
{ expect } = require 'chai'
nock = require 'nock'

# Globals
robot = user = {}

# Test environment variables
process.env.HUBOT_HIGHFIVE_EMAIL_SERVICE = 'dummy'
process.env.PORT = 8088
process.env.HUBOT_HOSTNAME = 'http://localhost:8088'

# Create a robot, load our script
prep = (done) ->
    robot = new Robot path.resolve(__dirname), 'shell', yes, 'TestHubot'
    robot.adapter.on 'connected', ->
        # Project script
        robot.loadFile path.resolve('.'), 'index.coffee'
        # Some test users
        user = robot.brain.userForId "1",
            name: "mocha"
            email: "mocha@example.com"
            room: "#mocha"
        robot.brain.userForId '2',
            name: 'foo'
            email: 'foo@example.com'
            room: '#mocha'
        done()
    robot.run()

cleanup = ->
    robot.server.close()
    robot.shutdown()
    nock.cleanAll()

# Message/response helper
message_response = (msg, evt, expecter) ->
    robot.adapter.on evt, expecter
    robot.adapter.receive new TextMessage user, "TestHubot #{msg}"

# Test help output
describe 'help', ->
    beforeEach prep
    afterEach cleanup

    it 'should have 2', (done) ->
        expect(robot.helpCommands()).to.have.length 2
        do done

    it 'should parse help', (done) ->
        help = robot.helpCommands()
        expected = [
            'hubot highfive @<user> $<amount> for <awesome thing> - makes a loud announcement and sends the user an Amazon.com giftcard',
            'hubot highfive @<user> for <awesome thing> - makes a loud announcement in a public chatroom',
        ]
        expect(expected).to.contain(x) for x in help
        do done

# Test the Tango Card API implementation
describe 'tangocard api', ->
    # TODO

# Test the command itself
describe 'highfive', ->
    beforeEach prep
    afterEach cleanup

    it "shouldn't let you high-five yourself", (done) ->
        message_response 'highfive @mocha for nothing', 'reply', (e,strs) ->
            expect(strs).to.contain 'clapping'
            do done

    it "shouldn't let you send huge gifts", (done) ->
        message_response 'highfive @foo $5000 for nothing', 'reply', (e,strs) ->
            expect(strs).to.match /\$5000.*smaller/i
            do done

    it 'should make some noise', (done) ->
        message_response 'highfive @foo for something', 'send', (e,strs) ->
            expect(strs).to.match /.*woo[\s\S]*\.gif/i
            do done

    it "should complain if it can't find a user", (done) ->
        message_response 'highfive @bar for nothing', 'reply', (e,strs) ->
            expect(strs).to.equal "Who's @bar?"
            do done

    it 'should announce the gift card', (done) ->
        message_response 'highfive @foo $25 for something', 'send', (e,strs) ->
            unless strs.match /woo/i
                expect(strs).to.match /.*\$25.*card.*/i
                do done

describe 'config', ->
    beforeEach prep
    afterEach cleanup

    it "should respond", (done) ->
        message_response 'highfive config', 'reply', (e,strs) ->
            expect(strs).to.match /localhost:8088\/highfive$/
            do done
