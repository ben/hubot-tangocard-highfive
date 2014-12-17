Spreadsheet = require 'edit-google-spreadsheet'

# Environment configuration
EMAIL = process.env.HUBOT_HIGHFIVE_SHEET_EMAIL
KEY = process.env.HUBOT_HIGHFIVE_SHEET_KEY # the contents of a .pem file
DOCID = process.env.HUBOT_HIGHFIVE_SHEETID
SHEETNAME = process.env.HUBOT_HIGHFIVE_SHEETNAME

logToSheet = (data) ->
    unless EMAIL and KEY and DOCID and SHEETNAME
        return console.log "Set up HUBOT_HIGHFIVE_SHEET_* environment variables to log gift cards to a Google spreadsheet. Check the hubot-tangocard-highfive readme."

    Spreadsheet.load
        spreadsheetId: DOCID
        worksheetName: SHEETNAME
        oauth:
            email: EMAIL
            key: KEY
    , (err, spreadsheet) ->
        return console.log "Error opening spreadsheet: #{err}" if err
        spreadsheet.receive (err, rows, info) ->
            return console.log "Error reading spreadsheet: #{err}" if err
            args = {}
            args[info.nextRow] = {}
            i = 1
            for item in data
                args[info.nextRow][i++] = item
            spreadsheet.add args
            spreadsheet.send (err) ->
                console.log "Error updating spreadsheet: #{err}" if err

module.exports = logToSheet
