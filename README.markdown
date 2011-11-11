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

Operations
----------

You can perform basically three operations:
 - GET /v1/downtime (lists hosts and all current downtime IDs)
 - DELETE /v1/downtime/:name (deletes all downtime for a host)
 - POST /v1/downtime/:name (will be used to schedule downtime for a host and
                            its services)

As you can see, the API is versioned in case of future interface changes.

Future
------
A basic authkey authentication/authorisation system may be put in, if it seems
useful and practical.

Copyright
---------
This program and libraries are copyright 2011 Oliver Hookins, and licensed
under the GNU General Public License Version 2 or higher.
