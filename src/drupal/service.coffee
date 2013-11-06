http = require 'http'
https = require 'https'
Q = require 'q'

exports = module.exports = {}

_opts =
  hostname: 'localhost'
  port: 80

class Service
  constructor: (@endpoint, credentials, @opts = _opts, @useSSL = false) ->
    { @username, @password } = credentials
    throw new Error 'Need login credentials' unless @username? or @password?

    @endpoint = "/#{@endpoint}" if @endpoint[0] isnt '/'

    @cookie = null
    @csrfToken = null
    @user = null

    @useSSL = true if @opts.port is 443

    return @

  connect: ->
    if @user? and @csrfToken? and @cookie?
      console.info 'Already connected :)'
      return Q(@user)

    console.info 'Connecting to Service API...'
    Q.when @resource('/system/connect'), (response) =>
      if response.body.user.name is undefined
        Q.when @login(@username, @password), (user) =>
          @user = user

          Q.when @getToken(), (token) =>
            @csrfToken = token
            return @user

      else
        console.info 'Already logged in :)'
        @user = response.body.user
        return @user

  login: (username, password) ->
    body =
      username: username
      password: password

    console.info "Loggin in user: #{username}..."
    Q.when @resource('/user/login', 'post', body), (response) =>
      console.info 'Login successful'
      @cookie = "#{response.body.session_name}=#{response.body.sessid}"

      return response.body.user

  logout: ->
    return Q(false) unless @user?

    Q.when @resource('/user/logout'), (response) =>
      @cookie = @csrfToken = @user = null
      console.log 'User logged out.'

      return Q(true)

  getToken: ->
    console.info 'Getting session token...'
    Q.when @resource('/user/token'), (response) ->
      return response.body.token

  resource: (resource, method = 'post', body = null) ->
    # Strip format extension, just work with json :)
    resource = resource.replace /\.\w+$/i, ''

    options = @opts
    options.path = "#{@endpoint}#{resource}.json"
    options.method = method.toUpperCase()
    options.headers =
      'accept': 'application/json'
      'content-type': 'application/json'
      'transfer-encoding': 'chunked'

    options.headers['x-csrf-token'] = @csrfToken if @csrfToken?
    options.headers['cookie'] = @cookie if @cookie?

    options.agent = new https.Agent options if @useSSL or @opts.port is 443

    return @_request options, body

  _request: (options, body = null) ->
    deferred = Q.defer()
    response = {}
    data = ''

    if @useSSL or @opts.port is 443
      reqMethod = https.request
    else
      reqMethod = http.request

    req = reqMethod options, (res) ->
      response.status = res.statusCode
      response.headers = res.headers

      res.on 'data', (chunk) ->
        data += chunk

      res.on 'end', ->
        try
          response.body = JSON.parse data
        catch error
          deferred.reject error

        deferred.reject response unless response.status is 200

        deferred.resolve response

    if body?
      req.write JSON.stringify(body)

    req.on 'error', (err) ->
      deferred.reject err

    req.end()

    return deferred.promise

exports.Service = Service
