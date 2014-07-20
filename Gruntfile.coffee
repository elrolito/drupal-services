exports = module.exports = (grunt) ->
  grunt.loadNpmTasks 'grunt-codo'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-mocha-test'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    clean:
      dist: ['lib']
      codo: ['api']

    codo:
      options:
        name: 'DrupalServicesAPI'
        title: 'Drupal Services API Documentation'
        output: 'api/'
      src: ['src']

    coffee:
      compile:
        files: [
          expand: true
          cwd: 'src/'
          src: ['**/*.coffee']
          dest: 'lib/'
          ext: '.js'
        ]

    coffeelint:
      app: ['src/**/*.coffee']

    mochaTest:
      options:
        reporter: 'spec'
        require: 'coffee-script/register'
        growl: true
      src: ['test/**/*.coffee']

    watch:
      source:
        files: ['**/*.coffee']
        tasks: ['coffeelint', 'coffee']
        options:
          cwd: 'src/'

  grunt.registerTask 'test', ['mochaTest']
  grunt.registerTask 'api', ['codo']
  grunt.registerTask 'default', ['clean', 'coffeelint', 'coffee', 'test', 'api']
