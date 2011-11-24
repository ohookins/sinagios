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

 * Nagios 2.x or later (see notes below)
 * ruby 1.8.5 or later
 * sinatra 1.2.7
 * rack 1.2.4
 * json 1.5.3
 * thin 1.2.11

Optional
--------
These are used mainly for testing or packaging.

 * rake 0.8.7
 * rspec 2.5.0
 * rack-test 0.6.1
 * fpm (see notes below)

Nagios Version
--------------
In Nagios version 2.x the downtime data was maintained in a separate file to
the status information. Sinagios presently only looks inside a single file to
get information on downtime so if you are using Nagios 2.x please set the
status_file entry in the configuration to point to your downtime file (usually
something like /var/log/nagios/downtime.dat).

Installation
============
Assumptions
-----------
 * Apache httpd is installed and in the nagios group.
 * If you want security, authentication etc you will proxypass sinagios through
   httpd (or your web frontend of choice).
 * Nagios is installed and running and the external command interface is
   enabled.

Manual
------
 * git clone this repository
 * install the above mandatory gems
 * mkdir /etc/sinagios and copy rpmfiles/{sinagios.conf,config.ru} into it
 * customise /etc/sinagios/sinagios.conf to match your command and status file
   locations
 * start with 'rake rackup'

Preferred
---------
I only have methods implemented for building RPM packages. Sorry - don't hate me.

Right now fpm (used for packaging) does not have the required features in the
mainline code tree (specifically, using a filelist and being able to specify
configuration files). You can take a look at my fork and merge the patches from
the config_files and inputs_file branches to get a working version. Or just bug
me for an RPM.

 * Build the sinagios package using 'rake package'
 * Build the dependent gems using 'rake package_gems'
 * Install the sinagios package and mandatory gem packages.
 * Start sinagios using 'service sinagios start'
 * Optionally use the Puppet module to deploy and maintain the application.

Configuration
-------------
Sinagios will determine the location of the Nagios files from:
 * Anything passed to Nagios#new (code internals)
 * Config file specified by environment variable SINAGIOS_CONFIG
 * Config file /etc/sinagios/sinagios.conf
 * Defaults:
  * Command file: /var/spool/nagios/cmd/nagios.cmd
  * Status file: /var/log/nagios/status.dat

If you are using the configuration file in /etc/sinagios/sinagios.conf or a
location provided by the environment variable SINAGIOS_CONFIG you can override
either or both of these parameters in the YAML format like the following:

---
cmd_file: /path/to/nagios.cmd
status_file: /path/to/status.dat


Please see the notes in the Requirements section about the location of the
status file depending on your version of Nagios.

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

Continuous Integration
======================
You can see the current build status for Sinagios here:
 * http://travis-ci.org/#!/ohookins/sinagios

Copyright
=========
This program and libraries are copyright 2011 Oliver Hookins, and licensed
under the GNU General Public License Version 2 or higher.
