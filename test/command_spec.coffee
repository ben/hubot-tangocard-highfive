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

cleanup = ->
    robot.server.close()
    robot.shutdown()
    nock.cleanAll()

# Message/response helper
message_response = (msg, evt, direct_address, expecter) ->
    # direct_address is optional, need to detect if it's missing to find the callback
    if not expecter?
        expecter = direct_address
        direct_address = true

    robot.adapter.on evt, expecter
    robot.adapter.receive new TextMessage user, "#{if direct_address then 'TestHubot ' else ''}#{msg}"

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

# We handle a couple of varieties of reason: "for X", and just "X".
# That last case still results in hubot sending the reason as "for X".
[{
    reason: 'for something',
    reason_sent: 'for something'
}, {
    reason: 'something',
    reason_sent: 'for something'
}].forEach (reasonCtx) ->

    # Test the command with a given reason
    describe "highfive #{reasonCtx.reason}", ->
        # We want to test the behavior in all four combinations of direct_address
        # and allow_eavesdropping, but false/false is different in that the message
        # is expected to be ignored.  Thus, we test the other three cases here, and
        # special-case the false/false "ignore the message" case separately.
        [{
            direct_address: true,
            allow_eavesdropping: false,
        }, {
            direct_address: true
            allow_eavesdropping: true,
        }, {
            direct_address: false
            allow_eavesdropping: true,
        }].forEach (directCtx) ->
            describe "with allow eavesdropping #{directCtx.allow_eavesdropping} and direct address #{directCtx.direct_address}", ->

                beforeEach (done) ->
                    process.env.HUBOT_HIGHFIVE_ALLOW_EAVESDROPPING = directCtx.allow_eavesdropping.toString()
                    prep done

                afterEach ->
                    delete process.env.HUBOT_HIGHFIVE_ALLOW_EAVESDROPPING
                    do cleanup

                it "shouldn't let you high-five yourself", (done) ->
                    message_response "highfive @mocha #{reasonCtx.reason}", 'reply', directCtx.direct_address, (e,strs) ->
                        expect(strs).to.contain 'clapping'
                        do done

                it "should complain if it can't find a user", (done) ->
                    message_response "highfive @bar #{reasonCtx.reason}", 'reply', directCtx.direct_address, (e,strs) ->
                        expect(strs).to.equal "Who's @bar?"
                        do done

                it 'should make some noise', (done) ->
                    message_response "highfive @foo #{reasonCtx.reason}", 'send', directCtx.direct_address, (e,strs) ->
                        expect(strs).to.match /woo/i
                        expect(strs).to.contain 'foo'
                        expect(strs).to.contain 'mocha'
                        expect(strs).to.match /\.gif/i
                        do done

                it "should send #{reasonCtx.reason_sent} for #{reasonCtx.reason}", (done) ->
                    message_response "highfive @foo #{reasonCtx.reason}", 'send', directCtx.direct_address, (e,strs) ->
                        expect(strs).to.contain reasonCtx.reason_sent
                        do done


        describe 'with allow eavesdropping false and direct address false', ->
            beforeEach prep
            afterEach cleanup

            it "should ignore highfives that aren't directly addressed to hubot", (done) ->
                message_response "highfive @foo #{reasonCtx.reason}", 'send', false, (e,strs) ->
                    expect(true).to.equal(false)
                    do done
                # wait for 1 second to make sure the expecter *isn't* called
                setTimeout done, 1000

        # Test the Tango Card API implementation
        describe 'with 1Tango Card', ->
            # Because we need to tweak settings for many of these tests, they
            # are individually responsible for calling `prep`!
            beforeEach prepNock
            afterEach cleanup

            describe 'default limits', ->
                beforeEach prep

                it 'should announce the gift card', (done) ->
                    message_response "highfive @foo $25 #{reasonCtx.reason}", 'send', (e,strs) ->
                        unless strs.match /woo/i
                            expect(strs).to.match /.*\$25.*card.*/i
                            do done

                it "shouldn't let you send huge gifts", (done) ->
                    message_response "highfive @foo $5000 #{reasonCtx.reason}", 'reply', (e,strs) ->
                        expect(strs).to.match /\$5000.*smaller.*150/i
                        do done

            it 'should refuse to send too much money in one day', (done) ->
                process.env.HUBOT_HIGHFIVE_DAILY_LIMIT = '30'
                prep ->
                    message_response "highfive @foo $20 #{reasonCtx.reason}", 'send', (e,strs) ->
                        return unless strs.match /\$20/
                        message_response "highfive @foo $15 #{reasonCtx.reason}", 'reply', (e,strs) ->
                            if strs.indexOf('$15') == -1
                                expect(strs).to.match /.*sorry.*\$20.*\$30/i
                                delete process.env.HUBOT_HIGHFIVE_DAILY_LIMIT
                                do done

            it 'should mention the right limit when refusing to order a card', (done) ->
                process.env.HUBOT_HIGHFIVE_AWARD_LIMIT = '20'
                prep ->
                    message_response "highfive @foo $30 #{reasonCtx.reason}", 'reply', (e, strs) ->
                        expect(strs).to.contain "$#{process.env.HUBOT_HIGHFIVE_AWARD_LIMIT}"
                        delete process.env.HUBOT_HIGHFIVE_AWARD_LIMIT
                        do done

            it 'should refuse to send a card if awards are disabled', (done) ->
                process.env.HUBOT_HIGHFIVE_AWARD_LIMIT = '0'
                prep ->
                    message_response "highfive @foo $10 #{reasonCtx.reason}", 'reply', (e,strs) ->
                        expect(strs).to.contain 'disabled'
                        delete process.env.HUBOT_HIGHFIVE_AWARD_LIMIT
                        do done

            it 'daily double should double the amount', (done) ->
                process.env.HUBOT_HIGHFIVE_DOUBLE_RATE = '1'
                prep ->
                    message_response "highfive @foo $10 #{reasonCtx.reason}", 'send', (e, strs) ->
                        return unless strs.match /gift card is on its way/
                        expect(strs).to.match /A \$20 gift card is on its way/
                        process.env.HUBOT_HIGHFIVE_DOUBLE_RATE = '0'
                        do done


describe 'config', ->
    beforeEach prep
    afterEach cleanup

    it "should respond", (done) ->
        message_response 'highfive config', 'reply', (e,strs) ->
            expect(strs).to.match /localhost:8088\/highfive\/$/
            do done
