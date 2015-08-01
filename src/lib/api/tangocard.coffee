BaseApiApp = require './base'

# Tango Card API helper class
class TangoApp extends BaseApiApp
    constructor: (robot) ->
        user = process.env.HUBOT_TANGOCARD_USER
        pass = process.env.HUBOT_TANGOCARD_KEY
        auth = "Basic " + new Buffer("#{user}:#{pass}").toString('base64')
        super robot, process.env.HUBOT_TANGOCARD_ROOTURL || 'https://api.tangocard.com/raas/v1/',
            Authorization: auth

    getAccountStatus: (cust, acct, callback) ->
        @get "accounts/#{cust}/#{acct}", callback

    fundAccount: (cust, acct, amt, ip, cc, auth, callback) ->
        @post 'cc_fund',
            customer: cust
            account_identifier: acct
            amount: amt
            client_ip: ip
            cc_token: cc
            security_code: auth
        , callback

    orderGiftCard: (cust, acct, campaign, amt, from, subject, to, email, message, callback) ->
        data =
            customer: cust
            account_identifier: acct
            campaign: campaign
            recipient:
                name: to
                email: email
            sku: process.env.HUBOT_TANGOCARD_SKU || "AMZN-E-V-STD"
            amount: amt
            reward_from: from
            reward_subject: subject
            reward_message: message
            send_reward: true
        @post 'orders', data, callback

module.exports = TangoApp
