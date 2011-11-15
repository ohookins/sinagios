Overview
--------

Sinagios is a Sinatra app which provides an extremely basic RESTful API for
manipulating Nagios service and host downtime.

Requirements
------------
 * ruby 1.8.7
 * rake 0.8.7
 * sinatra 1.3.1
 * rspec 2.5.0
 * rack-test 0.6.1
 * mocha 0.9.8
 * json 1.5.3

These are the versions I develop with. It will probably work more or less the
same on similar, but not equal, major versions.

Optionally you need fpm for packaging.

Operations
----------

All structured output is in JSON.

You can perform basically three operations:

 * List hosts and all current downtime IDs
  - GET /v1/downtime

 * Delete all downtime for a host
  - DELETE /v1/downtime/:name

 * Schedule downtime for a host and all its services
  - POST /v1/downtime/:name
  - Params:
   - duration (downtime window expressed in whole seconds)
   - author (name of downtime author, matching [^a-zA-Z0-9\-\.#\s])
   - comment (a comment for the downtime, matching [^a-zA-Z0-9\-\.#\s])
  - All parameters are required.

As you can see, the API is versioned in case of future interface changes.

Future
------
A basic authkey authentication/authorisation system may be put in, if it seems
useful and practical.

Copyright
---------
This program and libraries are copyright 2011 Oliver Hookins, and licensed
under the GNU General Public License Version 2 or higher.
