Spreadsheet = require 'edit-google-spreadsheet'

# Environment configuration
EMAIL = process.env.HUBOT_HIGHFIVE_SHEET_EMAIL
KEY = process.env.HUBOT_HIGHFIVE_SHEET_KEY
DOCID = process.env.HUBOT_HIGHFIVE_SHEET_DOCID
SHEETNAME = process.env.HUBOT_HIGHFIVE_SHEET_SHEETNAME

logToSheet = (robot, data) ->
    unless EMAIL and KEY and DOCID and SHEETNAME
        return robot.logger.info "Set up HUBOT_HIGHFIVE_SHEET_* environment variables to log gift cards to a Google spreadsheet. Check the hubot-tangocard-highfive readme."

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
            args = {}
            args[info.nextRow] = {}
            i = 1
            for item in data
                args[info.nextRow][i++] = item
            spreadsheet.add args
            spreadsheet.send (err) ->
                robot.logger.info "Error updating spreadsheet: #{err}" if err

module.exports = logToSheet
