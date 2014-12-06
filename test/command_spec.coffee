# Hubot classes
Robot = require "hubot/src/robot"
TextMessage = require("hubot/src/message").TextMessage
path = require 'path'

# Load assertion methods to this scope
{ expect } = require 'chai'
nock = require 'nock'

# Globals
robot = user = {}

# Create a robot, load our script
prep = (done) ->
    robot = new Robot path.resolve(__dirname), 'shell', no, 'TestHubot'
    robot.adapter.on 'connected', ->
        # Dummy email service
        process.env.HUBOT_HIGHFIVE_EMAIL_SERVICE = 'dummy'
        # Project script
        robot.loadFile path.resolve('.'), 'index.coffee'
        user = robot.brain.userForId "1",
            name: "mocha"
            room: "#mocha"
        robot.brain.userForId '2',
            name: 'foo'
            room: '#mocha'
        done()
    robot.run()
    robot

cleanup = ->
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

describe 'tangocard api', ->
    it 'should be true', (done) ->
        expect(yes).to.equal true
        do done

describe 'highfive', ->
    beforeEach prep
    afterEach cleanup

    it "shouldn't let you high-five yourself", (done) ->
        message_response 'highfive @mocha for nothing', 'reply', (e,strs) ->
            expect(strs).to.contain 'clapping'
            do done

    it "shouldn't let you send huge gifts", (done) ->
        message_response 'highfive @foo $5000 for nothing', 'reply', (e,strs) ->
            expect(strs).to.contain '$5000'
            do done

    it 'should make some noise', (done) ->
        message_response 'highfive @foo for something', 'send', (e,strs) ->
            expect(strs).to.contain 'WOO'
            do done
