# Description:
#   Entry point for Tango Card highfive script
Fs   = require 'fs'
Path = require 'path'

module.exports = (robot) ->
    path = Path.resolve __dirname, 'src'
    robot.loadFile path, file for file in Fs.readdirSync(path)
