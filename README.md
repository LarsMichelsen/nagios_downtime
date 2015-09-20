# nagios_downtime - Script based downtime scheduling

nagios_downtime can be used to schedule downtimes directly from monitored
machines to automaticaly schedule downtimes in Nagios only with having access
to the Nagios CGIs. There is no additional connection needed.

You can schedule those downtimes automaticaly on system reboot by an init
script. You could also run the script to schedule downtimes for special
services e.g. during backups of databases. nagios_downtime can create a
downtime in Nagios before shuting down the database to start the backup (add
mode) and delete the downtime again when the backup is finished (del mode).

Scheduling downtimes for planned downtimes gives you several advantages:

* No alerts are raised by planned downtimes
* The unplanned downtime in reporting is not affected by such downtimes

Currently the nagios_downtime Scripts are shipped for Linux (written in Perl)
and Windows (written in VBS). The intention was to have two scripts for the
different platforms to reach one goal. During time both scripts diverged a
bit. I started development of these scripts back in 2005, so please don't
be too strict with the coding style, I am a bit unhappy with this for myself,
but currently don't have the time to fix this. Maybe I find the time to fix
this one day. You are welcome to send improvements!

## Linux (Perl script)

### Prerequisites (Perl)

* Perl
* Perl Modules:
  * LWP
  * Switch
  * Net::Ping
  * Sys::Hostname
  * Getopt::Long

### Usage

You can use the provided init script to set up a basic downtime scheduling. In
some cases you may need to change the parameter in the init script calls or the
options in the nagios_downtime file to fit your needs. For example the options
for accessing the CGI files will be needed to be changed in most environments.

You basicaly have two ways to provide the options to the script:

a) via command line
b) via editing the options in the script

For details about the single command line parameters please execute this:

```
# nagios_downtime -h
```

You may change the basic like Nagios host, cgi path, cgi user and password 
using the options in the nagios_downtime script. This way you don't need to
provide the parameters on each call.

Examples:

This command can be used to schedule a downtime of 15 minutes on the nagios
host (nagios.my-domain.com). The CGIs are located at /nagios/cgi-bin. The
CGIs can be accessed by the user nagiosadmin with password nagiosadmin. A
host-downtime for the host webserver.my-domain.com will be scheduled.

```
# nagios_downtime -m add -t 15 -S nagios.my-domain.com -p /nagios/cgi-bin \
                  -u nagiosadmin -P nagiosadmin -H webserver.my-domain.com
```

With this command you can terminate the downtime. You need to have the
saving of the downtime ids enabled (See next chapter).

```
# nagios_downtime -m del -S nagios.my-domain.com -p /nagios/cgi-bin \
                  -u nagiosadmin -P nagiosadmin -H webserver.my-domain.com
```

### Init script installation (Should work on SuSE, RedHat, CentOS, Fedora)

Copy the file `nagios_downtime` to `/usr/bin`. And make sure it is executable.

```
# cp -p nagios_downtime /usr/bin
# chmod +x /usr/bin/nagios_downtime
```

Copy the init script `nagios_downtime.init` to `/etc/init.d`. Also make sure it is
executable.

```
# cp -p nagios_downtime.init /etc/init.d
# chmod +x /etc/init.d/nagios_downtime.init
```

Activate the init script to be executed on system shutdown.

```
# chkconfig --add nagios_downtime
# chkconfig nagios_downtime on
```

### Downtime deletion

The deletion of downtimes is a new feature in nagios_downtime 0.5.

You need to set the vars `$storeDowntimeIds` and `$downtimePath` in the head of the
nagios_downtime file to be able to use the feature. Once enabled newly
scheduled downtimes can be deleted by calling nagios_downtime in deletion mode
(`-m del`).

## Bugs and Support

I decided to use GitHub for managing project related communication, you
can find the project at (https://github.com/LaMi-/nagios_downtime).

The nagios_downtime scripts were previously homed on my personal, a bit outdated, blog.
You might find some useful information there in the related articles or commennts
(http://larsmichelsen.com/nagios-downtime/).

## Thanks

Thanks to all supporters of open source software. Keep up the great work!

## Licensing

Copyright (C) 2014 Lars Michelsen <lm@larsmichelsen.com>

All outcome of the project is licensed under the terms of the GNU GPL v2.
Take a look at the LICENSE file for details.
