###
TODO: write tests!
###

nock = require 'nock'
nock.disableNetConnect()

endpoint = nock('http://api.drupalservice.com')
  .post('/system/connect.json')
  .reply(200, {
      user: {
        uid: 0,
      }
    })


chai = require 'chai'
chai.should()

describe 'Services', ->
  describe '#connect()', ->
    it 'Returns anonymous user when first called's

