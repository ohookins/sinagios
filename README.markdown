Overview
========

Sinagios is a Sinatra app which provides an extremely basic RESTful API for
manipulating Nagios service and host downtime.

Requirements
============

These are the versions I develop with. It will probably work more or less the
same on similar, but not equal, major versions.

Mandatory
---------
You need these to run Sinagios.

 * ruby 1.8.7
 * sinatra 1.3.1
 * json 1.5.3

Optional
--------
These are used mainly for testing or packaging.

 * rake 0.8.7
 * rspec 2.5.0
 * rack-test 0.6.1
 * mocha 0.9.8
 * thin 1.2.11 (if you don't want to use WEBrick, Passenger or some other web
   server)

Operations
==========

 * All structured output is in JSON.
 * The API is versioned in case of future interface changes.

You can perform basically three operations:

List hosts and all current downtime IDs
---------------------------------------
GET /v1/downtime

Delete all downtime for a host
------------------------------
DELETE /v1/downtime/:name

Schedule downtime for a host and all its services
-------------------------------------------------
POST /v1/downtime/:name

Parameters (all are required):
 * duration (downtime window expressed in whole seconds)
 * author (name of downtime author, matching [^a-zA-Z0-9\-\.#\s])
 * comment (a comment for the downtime, matching [^a-zA-Z0-9\-\.#\s])

Health Check
------------
GET /v1/health

This bonus fourth operation facilitates some basic health checking of the app.
It will just ensure it has correct access to the status and command files and
return an HTTP 200 and body text of 'OK' if everything is well.

If not, it will attempt to return the exception message and an HTTP 500 code.


Roadmap
=======
Aside from tidy ups, effectively this 1.0.0 version is feature complete.
If there are features you'd like to see implemented, please file an issue.

Copyright
=========
This program and libraries are copyright 2011 Oliver Hookins, and licensed
under the GNU General Public License Version 2 or higher.
