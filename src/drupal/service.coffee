# Drupal Service API module
# ===

'use strict'

http = require 'http'
https = require 'https'
path = require 'path'
querystring = require 'querystring'
URL = require 'url'

_ = require 'lodash'
concat = require 'concat-stream'
Q = require 'q'

exports = module.exports = {}

Drupal = {}

# Drupal Service class.
#
# @example Create a new service with an endpoint object
#   endpoint =
#     hostname: 'apidomain.com'
#     pathname: '/myendpoint'
#
#   Service.factory endpoint
#
# @example Create a new service with an endpoint string
#   endpoint = 'https://apidomain.com/myendpoint'
#
#   service = new Service endpoint
#
# @author Rolando Henry <elrolito@me.com>
#
class Drupal.Service

  # Create an instance of Drupal.Service
  #
  # @see #constructor
  # @return {Drupal.Service} Service instance
  #
  @factory: (endpoint, httpOptions) ->
    new Drupal.Service endpoint, httpOptions

  # Construct a new Drupal Service.
  #
  # @param {String|Object} endpoint valid URL string or object to endpoint
  # @param {Object} httpOptions optional options to pass to http(s) request
  # @see http://nodejs.org/api/http.html Node HTTP API for valid options
  # @throw {Error} if pathname is not set in endpoint object
  # @throw {TypeError} if endpoint string is not a vaild URL
  #
  constructor: (@endpoint, @httpOptions={}) ->
    # If `endpoint` is passed as an object, make sure `pathname` is set.
    if _.isPlainObject @endpoint
      unless _.has @endpoint, 'pathname'
        throw new Error 'Endpoint requires a pathname.'

    if _.isString @endpoint
      # Convert to URL object if `endpoint` is a string.
      @endpoint = URL.parse @endpoint

      unless @endpoint.hostname?
        throw new TypeError "#{@endpoint} is not a valid URL."

    # Set some defaults.
    @endpoint.protocol ?= 'http'
    @endpoint.hostname ?= 'localhost'

    # Merge `endpoint` object into `httpOptions` for use in requests.
    _.merge @httpOptions, @endpoint

    # Will throw an error if included.
    delete @httpOptions.protocol

    # Initialize session variables.
    @cookie = null    # session cookie
    @csrfToken = null # csrfToken for x-csrf-token header
    @user = null      # logged in user object

    return @

  # Authorize a user for all future requests.
  #
  # @param {String} username user to login
  # @param {String} password user password
  # @return {Q.promise|Object} promise resolves to logged in user
  #
  login: (username, password) ->
    deferred = Q.defer()

    # User is already authorized and session is stored.
    if @user? and @csrfToken? and @cookie?
      console.info 'Already logged in :)'
      deferred.resolve @user

    Q.try =>
      # POST data to pass to request.
      body =
        username: username
        password: password

      deferred.notify message: 'Connecting to Service API.'
      @resource '/system/connect', null, 'post'
      .progress deferred.notify
      .then (response) =>
        if response.body.user isnt @user
          # Login user.
          deferred.notify message: "Logging in user: #{username}"
          @resource '/user/login', body, 'post'
          .progress deferred.notify
          .then (response) =>
            deferred.notify message: 'Login successful'
            deferred.resolve @createSession(response)

        else
          # Create session based on current logged in user.
          deferred.notify message: "User #{username} already logged in."
          deferred.resolve @createSession(response)

    .catch deferred.reject

    return deferred.promise

  # Logout current user.
  #
  # @return {Q.promise|Boolean} promise resolves whether user was logged out
  #
  logout: ->
    deferred = Q.defer()

    deferred.resolve false unless @user?

    Q.try =>
      @resource '/user/logout', null, 'post'
      .progress deferred.notify
      .then (response) =>
        @cookie = @csrfToken = @user = null

        deferred.resolve true

    .catch deferred.reject

    return deferred.promise

  # Gets CSRF token.
  #
  # @return {Q.promise|String} retrieved token
  #
  getToken: ->
    deferred = Q.defer()

    Q.try =>
      deferred.notify message: 'Getting session token.'
      @resource '/user/token', null, 'post'
      .progress deferred.notify
      .then (response) ->
        deferred.resolve response.body.token

    .catch deferred.reject

    return deferred.promise

  # Create session for future requests.
  #
  # @param {Object} data response object from `system/connect` call
  # @return {Q.promise|Object} promise resolves to logged in user
  #
  createSession: (data) ->
    deferred = Q.defer()

    @user = data.body.user
    @cookie = "#{data.body.session_name}=#{data.body.sessid}"

    Q.try =>
      # Get CSRF token.
      @getToken()
      .progress deferred.notify
      .then (token) =>
        @csrfToken = token
        deferred.resolve @user

    .catch deferred.reject

    return deferred.promise

  # Fromats resource to endpoint pathname and search string.
  #
  # @param {String} resource path to format
  # @return {String} formatted path with query string if any
  #
  formatResourcePath: (resource) ->
    # Strip all but `json` extensions from resource path.
    resource = resource.replace /\.\w+$/i, '' unless /\.json$/.test resource

    reqPath = path.join '/', @endpoint.pathname, resource

    # Add query parameters as search string if they exist.
    if @queryParams?
      search = querystring.stringify @queryParams
      reqPath = [reqPath, search].join '?'

    return reqPath

  # Adds query params to the request.
  #
  # @param {String} key param key
  # @param {String} value param value
  # @return {Drupal.Service} chainable
  #
  addQueryParam: (key, value) ->
    @queryParams ?= {}
    @queryParams[key] = value

    return @

  # Clears all query params.
  #
  # @return {Drupal.Service} chainable
  #
  clearQueryParams: ->
    @queryParams = {}

    return @

  # Get index of a resource.
  #
  # @param {String} resource service resource to index
  # @return {Q.promise|Array} promise resolves to an array of results
  #
  index: (resource) ->
    @resource resource
    .get 'body'

  # Retrieve a specific resource.
  #
  # @param {String} resource service resource to retrieve
  # @param {String|Integer} id resource id
  # @return {Q.promise|Object} promise resolves to result object
  retrieve: (resource, id) ->
    resource = path.join resource, id.toString()
    @resource resource
    .get 'body'

  # Main method to call a resource from a REST service.
  #
  # @param {String} resource service resource to call
  # @param {Object} body data to pass to request [default: null]
  # @param {String} method REST request method [default: 'get']
  # @return {Q.promise|Object} promise resolves to response object
  #
  resource: (resource, body=null, method='get') ->
    # Set up the options for the request.
    options = _.clone @httpOptions
    options.path = @formatResourcePath resource
    options.method = method.toUpperCase()
    options.headers =
      'accept': 'application/json'
      'content-type': 'application/json'
      'transfer-encoding': 'chunked'

    # Set session request headers if necessary.
    options.headers['x-csrf-token'] = @csrfToken if @csrfToken?
    options.headers['cookie'] = @cookie if @cookie?

    # Make the actual request.
    @makeRequest options, body

  # Make the actual HTTP(S) request.
  #
  # @param {Object} options request options
  # @param {Object} body data to pass to request
  # @see http://nodejs.org/api/http.html Node HTTP API for valid options
  # @return {Q.promise|Object} promise resolves to response object
  #
  makeRequest: (options, body=null) ->
    deferred = Q.defer()

    response =
      body: ''

    Q.try =>
      if @endpoint.protocol is 'https'
        reqMethod = https.request
      else
        reqMethod = http.request

      sink = concat (data) ->
        unless response.headers['content-type'] is 'application/json'
          deferred.reject new TypeError 'Did not return JSON.'

        else

          response.body = JSON.parse data

        deferred.resolve response

      deferred.notify message: "Requesting #{options.path}"
      req = reqMethod options, (res) ->
        response.status = res.statusCode
        response.headers = res.headers

        unless res.statusCode is 200
          obj =
            error: new Error 'Request error.'
            response: response

          deferred.reject obj

        res.pipe sink

      if body?
        req.write JSON.stringify(body)

      req.on 'error', deferred.reject
      .end()

    .catch deferred.reject

    return deferred.promise

exports.Service = Drupal.Service
