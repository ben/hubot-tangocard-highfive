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
        # Project script
        robot.loadFile path.resolve('.'), 'index.coffee'
        user = robot.brain.userForId "1",
            name: "mocha"
            room: "#mocha"
        done()
    robot.run()
    robot

cleanup = ->
    robot.shutdown()
    nock.cleanAll()

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

    it 'should respond to ping', (done) ->
        robot.adapter.on 'reply', (env, strs) ->
            debugger
            console.log "got '#{strs}'"
            do done
        debugger
        robot.adapter.receive new TextMessage user, 'TestHubot ping'


describe 'tangocard api', ->
    it 'should be true', (done) ->
        expect(yes).to.equal true
        do done

describe 'highfive', ->
    it 'should be true', (done) ->
        expect(yes).to.equal true
        do done
