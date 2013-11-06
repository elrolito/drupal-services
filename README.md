Drupal Services
===============

A pretty simple promise-based wrapper for using the Drupal 7 Services 3.x API. Request and response uses JSON.

Handles session cookie, user token and x-csrf headers.

Usage
-----
Coffeescript example:

```coffee-script
Service = require('drupal-services').Service

service = new Service(
	'/endpoint'                             # Your Drupal Services endpoint
	{ username: 'user', password: 'enter' } # Login credentials
	{                                       # http/https request object
		hostname: 'yourserver.com'
		port: 443
	}
)

service.connect()
	.then(
		(user) ->
			# resource method args: resource path, method, request data (JSON)
			return service.resource 'node/1', 'put', { title: 'updated!' }
	)
	.then(
		(response) ->
			console.log response.body
	)

```