# Hubot classes
Robot = require "hubot/src/robot"
TextMessage = require("hubot/src/message").TextMessage
path = require 'path'
moment = require 'moment'

# Load assertion methods to this scope
{ expect } = require 'chai'
nock = require 'nock'
nock.disableNetConnect()

# Globals
robot = user = {}

# Test environment variables
process.env.HUBOT_HIGHFIVE_CHAT_SERVICE = 'dummy'
process.env.PORT = 8088
process.env.HUBOT_HOSTNAME = 'http://localhost:8088'

# Mock out the tangocard API
process.env.HUBOT_TANGOCARD_ROOTURL = 'http://tango.example.com/'
process.env.HUBOT_TANGOCARD_CUSTOMER = 'Foo'
process.env.HUBOT_TANGOCARD_ACCOUNT = 'Bar'

# No daily doubles or boomerangs unless we test them explicitly
process.env.HUBOT_HIGHFIVE_DOUBLE_RATE = '0'
process.env.HUBOT_HIGHFIVE_BOOMERANG_RATE = '0'

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

prepNock = ->
    nock('http://tango.example.com')
        .filteringPath /Authorization=[^&]*/g, 'Authorization=FOOBAR'
        .get('/accounts/Foo/Bar?Authorization=FOOBAR')
        .reply 200,
            success: true
            account:
                available_balance: 100
        .post('/cc_fund?Authorization=FOOBAR')
        .reply 200,
            success: true
        .post('/orders?Authorization=FOOBAR')
        .reply 200,
            success: true
            order:
                delivered_at: moment.utc().toISOString()
                reward:
                    number: '123'
    nock('http://jsonip.com')
        .get('/')
        .reply 200, ip: '0.0.0.0'

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

    it 'should have 4', (done) ->
        expect(robot.helpCommands()).to.have.length 4
        do done

    it 'should parse help', (done) ->
        help = robot.helpCommands()
        expected = [
            'hubot highfive @<user> $<amount> for <awesome thing> - makes a loud announcement and sends the user an Amazon.com giftcard',
            'hubot highfive @<user> for <awesome thing> - makes a loud announcement in a public chatroom',
            'hubot highfive config - show URL for configuration UI',
            'hubot highfive stats - show stats about high-fives',
        ]
        expect(expected).to.contain(x) for x in help
        do done

# Test the Tango Card API implementation
describe 'Tango Card', ->
    beforeEach (done) ->
        do prepNock
        prep done
    afterEach cleanup

    it 'should announce the gift card', (done) ->
        message_response 'highfive @foo $25 for something', 'send', (e,strs) ->
            unless strs.match /woo/i
                expect(strs).to.match /.*\$25.*card.*/i
                do done

    it 'should refuse to send too much money in one day', (done) ->
        process.env.HUBOT_HIGHFIVE_DAILY_LIMIT = 30
        message_response 'highfive @foo $20 for nothing', 'send', (e,strs) ->
            return unless strs.match /\$20/
            message_response 'highfive @foo $15 for nothing', 'reply', (e,strs) ->
                if strs.indexOf('$15') == -1
                    expect(strs).to.match /.*sorry.*\$20.*\$30/i
                    delete process.env.HUBOT_HIGHFIVE_DAILY_LIMIT
                    do done

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
            expect(strs).to.match /\$5000.*smaller.*150/i
            do done

    it 'should mention the right limit when refusing to order a card', (done) ->
        process.env.HUBOT_HIGHFIVE_AWARD_LIMIT = 20
        message_response 'highfive @foo $30 for nothing', 'reply', (e, strs) ->
            delete process.env.HUBOT_HIGHFIVE_AWARD_LIMIT
            expect(strs).to.contain '$30'
            do done

    it 'should refuse to send a card if awards are disabled', (done) ->
        process.env.HUBOT_HIGHFIVE_AWARD_LIMIT = 0
        message_response 'highfive @foo $10 for nothing', 'reply', (e,strs) ->
            delete process.env.HUBOT_HIGHFIVE_AWARD_LIMIT
            expect(strs).to.contain 'disabled'
            do done

    it 'should make some noise', (done) ->
        message_response 'highfive @foo for something', 'send', (e,strs) ->
            expect(strs).to.match /woo/i
            expect(strs).to.contain 'foo'
            expect(strs).to.contain 'mocha'
            expect(strs).to.match /\.gif/i
            do done

    it "should complain if it can't find a user", (done) ->
        message_response 'highfive @bar for nothing', 'reply', (e,strs) ->
            expect(strs).to.equal "Who's @bar?"
            do done

    it "should be okay with 'for' or not", (done) ->
        message_response 'highfive @foo something', 'send', (e,strs) ->
            expect(strs).to.match /woo/i
            expect(strs).to.contain 'foo'
            expect(strs).to.contain 'mocha'
            expect(strs).to.match /\.gif/i
            do done


describe 'daily double', ->
    beforeEach (done) ->
        do prepNock
        process.env.HUBOT_HIGHFIVE_DOUBLE_RATE = '1'
        prep done
    afterEach ->
        process.env.HUBOT_HIGHFIVE_DOUBLE_RATE = '0'
        do cleanup

    it 'should double the amount', (done) ->
        message_response 'highfive @foo $10 for something', 'send', (e, strs) ->
            return unless strs.match /gift card is on its way/
            expect(strs).to.match /A \$20 gift card is on its way/
            do done

describe 'config', ->
    beforeEach prep
    afterEach cleanup

    it "should respond", (done) ->
        message_response 'highfive config', 'reply', (e,strs) ->
            expect(strs).to.match /localhost:8088\/highfive\/$/
            do done
