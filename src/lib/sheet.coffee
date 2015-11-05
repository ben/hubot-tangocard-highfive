Spreadsheet = require 'edit-google-spreadsheet'
_ = require 'lodash'
moment = require 'moment'

# Environment configuration
EMAIL = process.env.HUBOT_HIGHFIVE_SHEET_EMAIL
KEY = process.env.HUBOT_HIGHFIVE_SHEET_KEY
DOCID = process.env.HUBOT_HIGHFIVE_SHEET_DOCID
SHEETNAME = process.env.HUBOT_HIGHFIVE_SHEET_SHEETNAME

module.exports.logToSheet = (robot, data) ->
    unless EMAIL and KEY and DOCID and SHEETNAME
        return robot.logger.info "Set up HUBOT_HIGHFIVE_SHEET_* environment variables to log gift cards to a Google spreadsheet. Check the hubot-tangocard-highfive readme."

    Spreadsheet.load
        # debug: true
        spreadsheetId: DOCID
        worksheetName: SHEETNAME
        oauth:
            email: EMAIL
            key: KEY
    , (err, spreadsheet) ->
        return robot.logger.info "Error opening spreadsheet: #{err}" if err
        spreadsheet.receive (err, rows, info) ->
            return robot.logger.info "Error reading spreadsheet: #{err}" if err
            args = {}
            args[info.nextRow] = {}
            i = 1
            for item in data
                args[info.nextRow][i++] = item
            spreadsheet.add args
            spreadsheet.send (err) ->
                robot.logger.info "Error updating spreadsheet: #{err}" if err

module.exports.stats = (robot, msg) ->
    Spreadsheet.load
        spreadsheetId: DOCID
        worksheetName: SHEETNAME
        oauth:
            email: EMAIL
            key: KEY
    , (err, spreadsheet) ->
        return robot.logger.info "Error opening spreadsheet: #{err}" if err
        spreadsheet.receive (err, rows, info) ->
            return robot.logger.info "Error reading spreadsheet: #{err}" if err
            # console.log rows
            givers = {}
            receivers = {}

            addTo = (arr, email, amt) ->
                arr[email] ?=
                    email: email
                    amount: 0
                    count: 0
                arr[email].amount += amt
                arr[email].count += 1
            earliest = moment()
            earliest.subtract 90, 'days'
            for rid,r of rows when rid != '1'
                date = moment(r['1'])
                continue if date < earliest
                from = r['2']
                to = r['3']
                amt = parseInt(r['4'].replace /[$ ]/, '')
                addTo givers, from, amt
                addTo receivers, to, amt

            sortedBy = (obj, field) ->
                wrapped = _(v for k,v of obj)
                wrapped.sortBy((x) -> x[field]).reverse().value()
            giversByAmount = sortedBy givers, 'amount'
            giversByCount = sortedBy givers, 'count'
            receiversByAmount = sortedBy receivers, 'amount'
            receiversByCount = sortedBy receivers, 'count'
            txter = (header, arr, formatter) ->
                for x in arr
                    header += "\n\t#{x.email}: #{formatter(x)}"
                header
            msg.send txter('*Top givers by dollars:*', giversByAmount, (x) -> "$#{x.amount}")
            msg.send txter('*Top givers by gifts:*', giversByCount, (x) -> "#{x.count}")
            msg.send txter('*Top receivers by dollars:*', receiversByAmount, (x) -> "$#{x.amount}")
            msg.send txter('*Top receivers by gifts:*', receiversByCount, (x) -> "#{x.count}")
