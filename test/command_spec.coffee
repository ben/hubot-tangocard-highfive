# Hubot classes
Robot = require "hubot/src/robot"
TextMessage = require("hubot/src/message").TextMessage
path = require 'path'

# Load assertion methods to this scope
{ expect } = require 'chai'
nock = require 'nock'

# Globals
robot = {}
adapter = {}
user = {}

# Create a robot, load our script
createRobot = (enableHttpd, done) ->
    robot = new Robot null, 'mock-adapter', enableHttpd, 'TestHubot'
    robot.adapter.on 'connected', ->
        # Project script
        robot.loadFile path.resolve('.'), 'index.coffee'
        user = robot.brain.userForId "1",
            name: "mocha"
            room: "#mocha"
        done()
    robot.run()
    robot


# Test help output
describe 'help', ->
    beforeEach (done) ->
        robot = createRobot no, done
        adapter = robot.adapter

    afterEach ->
        robot.shutdown()
        nock.cleanAll()

    it 'should have 2', (done)->
        # console.log "'#{x}'" for x in
        expect(robot.helpCommands()).to.have.length 2
        do done

    it 'should parse help', (done)->
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
    it 'should be true', (done) ->
        expect(yes).to.equal true
        do done
