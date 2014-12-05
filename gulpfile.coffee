gulp = require 'gulp'
watch = require 'gulp-watch'
coffee = require 'gulp-coffee'
mocha = require 'gulp-mocha'

gulp.task 'test', ->
    gulp.src(['test/*.coffee'], read: false)
        .pipe mocha reporter: 'min'

gulp.task 'watch', ->
    gulp.watch ['**/*.coffee'], ['test']
