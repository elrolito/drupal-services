Drupal Services
===============

A pretty simple promise-based wrapper for using the Drupal 7 Services 3.x API. Request and response uses JSON.

Handles session cookie, user token and x-csrf headers.

Usage
-----

**NOTE** Major API changes in this version!!

Coffeescript example:

```coffee-script
{Service} = require 'drupal-services'

endpoint =
	protocol: 'https'
	auth: 'user:password'
	hostname: 'apiserver.com'
	pathname: '/myendpoint'

service = new Service endpoint

# Query node resource
service
.index '/node'
.then (results) ->
	console.log results

# If user needs to be logged in, using factory method:
Service
.factory endpoint
.login 'user', 'password'
.then (user) ->
	# Retreive a node
	service.retreive 'node', 1

.then (node) ->
	console.log node

```

Todo
----

I still need to write some more tests :)
