chai = require 'chai'

chai.use require('chai-as-promised')
chai.should()

{Service} = require '../../src/drupal/service'

describe 'Service', ->

  createService = (obj={}) ->
    new Service obj

  createBadService = ->
    new Service 'domain.com/endpoint'

  createStringService = ->
    new Service 'https://domain.com/endpoint'

  obj =
    pathname: 'drupal/endpoint'

  service = createService obj

  describe '#constructor', ->
    it 'throws an error if URL object does not have a pathname', ->
      createService.should.throw Error
      createService.should.throw /requires a pathname/

    it 'throws an error if a string endpoint passed is not a valid url', ->
      createBadService.should.throw TypeError
      createBadService.should.throw /not a valid URL/

    it 'generates an endpoint url if passed a url object with pathname key', ->
      service.endpoint.should.be.an 'object'
      service.endpoint.should.contain.keys 'protocol', 'hostname', 'pathname'

    it 'parses a valid URL to an object', ->
      createStringService.should.not.throw TypeError

      goodService = createStringService()
      endpoint = goodService.endpoint
      endpoint.should.be.an 'object'
      endpoint.hostname.should.exist
      endpoint.pathname.should.exist

    it 'contains some null keys', ->
      service.should.contain.keys 'user', 'cookie', 'csrfToken'

  describe '#formatResourcePath', ->
    it 'strips the extension of the resource path, unless it is .json', ->
      service.formatResourcePath 'user/login.xml'
        .should.not.match /\.xml/

      service.formatResourcePath 'user/login.json'
        .should.match /\.json/
