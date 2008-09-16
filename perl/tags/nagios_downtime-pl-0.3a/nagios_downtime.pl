#!/usr/bin/perl -w
#
# Copyright (c) 2007 Lars Michelsen http://www.vertical-visions.de
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
# #############################################################
# SCRIPT:       nagios_downtime.pl
# VERSION:      0.3
# CREATED:      27.03.06
# LAST UPDATED: 16.04.07
# AUTHOR:       Lars Michelsen
# DECRIPTION:   Sends a HTTP(S)-GET to the nagios web server to
#               enter a downtime for a host or service.
# PARAMS:       /H: Hostname (Wie im Nagios)
#               /S: Servicename (Wie im Nagios)
#               /T: Downtime von jetzt, in Minuten
#               /D: Debug
#               /?: Help
# CHANGES:
# 20.12.2006    - Using Getopt::Long for handling the params
# 01.02.2007    - New Config Option: $nagiosAuthName for setting
#                 the right Basic Auth "Auth Name"
# 15.04.2007    - Added SSL support (Crypt::SSLeay is needed)
# 16.04.2007    - Date format selection via new config value
#                 named $nagiosDateFormat
#               - Added some basic response handling of response
#                 code and content
# 27.04.2007 Bugfix with Authentication (thanks jwj)
# #############################################################

# #############################################################
# Configuration (-> Here you have to set some values!)
# #############################################################

# Protocol for the GET Request, In most cases "http", "https" is also possible
my $nagiosWebProto = "http";
# IP or FQDN of Nagios server (example: nagios.domain.de)
my $nagiosServer = "YOUR.NAGIOSSERVER.DE";
# IP or FQDN of Nagios web server. In most cases same as $nagiosServer, if empty automaticaly using $nagiosServer
my $nagiosWebServer = "YOUR.NAGIOS.WEB.SERVER";
# Port of Nagios webserver (If $nagiosWebProto is set to https, this should be SSL Port 443)
my $nagiosWebPort = 80;
# Web path to Nagios cgi-bin (example: /nagios/cgi-bin/)
my $nagiosCgiPath = "RELATIV-PATH-TO-CGI-BIN";
# User to take for authentication and author to enter the downtime (example: nagiosadmin)
my $nagiosUser = "BASIC AUTH USERNAME";
# Password for above user
my $nagiosUserPw = "BASIC AUTH PASSWORD";
# Name of authentication realm, set in the Nagios .htaccess file (example: "Nagios Access")
my $nagiosAuthName = "BASIC AUTH NAME";
# Nagios date format (same like set in value "date_format" in nagios.cfg)
my $nagiosDateFormat = "euro";

# Typ (1: Host Downtime, 2: Service Downtime)
my $downtimeType = 1;
# Default Downtime duration in minutes
my $downtimeDuration = 10;
# Default Downtime text
my $downtimeComment = "Linux Downtime-Script";
# Default Debugmode: off => 0 or on => 1
my $debug = 0;

# #############################################################
# Don't change anything below, except you know what you are doing.
# #############################################################

use strict;
use warnings;
use Net::Ping;
use LWP 5.64;
use Sys::Hostname;
use Getopt::Long;
use Switch;

my $arg;
my $p;
my $i = 0;
my $oBrowser;
my $oResponse;
my $hostname = "";
my $service = "";
my $start;
my $end;
my $url = "";
my $help = "";

Getopt::Long::Configure('bundling');
GetOptions(
    "h"   => \$help, "help"        => \$help,
    "D"   => \$debug, "debug"        => \$debug,
    "T=i" => \$downtimeDuration, "downtime=i"       => \$downtimeDuration,
    "C=i" => \$downtimeComment, "comment=s"       => \$downtimeComment,
    "H=s" => \$hostname, "hostname=s"       => \$hostname,
    "S=s" => \$service, "service=s"  => \$service);

if($help) {
    about();
    exit;
}

# get hostname if not set via param
if($hostname eq "") {
    $hostname = hostname;
}

if($nagiosWebServer eq "") {
    $nagiosWebServer = $nagiosServer;
}

# calc start time
$start = gettime(time);

# calc end time
$end = gettime(time+$downtimeDuration*60);

# Check if Nagios web server is reachable via ping, if not, terinate the script
$p = Net::Ping->new();
if(!$p->ping($nagiosWebServer)) {
    # Nagios web server is not pingable
    print "ERROR: Given Nagios web server \"" . $nagiosWebServer . "\" not reachable via ping\n";
    exit(1);
} else {
    # initialize browser
    my $oBrowser = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1,timeout => 30);

    if($downtimeType == 1) {
        # Schedule Host Downtime
        $url = $nagiosWebProto . "://" . $nagiosWebServer . ":" . $nagiosWebPort . $nagiosCgiPath . "cmd.cgi?cmd_typ=55&cmd_mod=2" .
            "&host=" . $hostname .
            "&com_author=" . $nagiosUser . "&com_data=" . $downtimeComment .
            "&trigger=0&start_time=" . $start . "&end_time=" . $end .
            "&fixed=1&childoptions=1&btnSubmit=Commit";

        if($debug == 1) {
            print "HTTP-GET: " . $url;
        }
    } else {
        # Schedule Service Downtime
        $url = $nagiosWebProto . "://" . $nagiosWebServer . ":" . $nagiosWebPort . $nagiosCgiPath . "cmd.cgi?cmd_typ=56&cmd_mod=2" .
            "&host=" . $hostname . "&service=" . $service .
            "&com_author=" . $nagiosUser . "&com_data=" . $downtimeComment .
            "&trigger=0&start_time=" . $start . "&end_time=" . $end .
            "&fixed=1&btnSubmit=Commit";

        if($debug == 1) {
            print "HTTP-GET: " . $url;
        }
    }

    # Only try to auth if auth informations given
    if($nagiosAuthName ne "" && $nagiosUserPw ne "") {
        # submit auth informations
        $oBrowser->credentials($nagiosWebServer.':'.$nagiosWebPort, $nagiosAuthName, $nagiosUser => $nagiosUserPw);
    }

    # Send the get request to the web server
    $oResponse = $oBrowser->get($url);

    if($debug == 1) {
        print "HTTP-Response: " . $oResponse->content;
    }

    # Handle response code, not in detail, only first char
    switch(substr($oResponse->code,0,1)) {
        # 2xx response code is OK
        case 2 {
            # Do some basic handling with the response content
            switch($oResponse->content) {
                case /Your command request was successfully submitted to Nagios for processing/ {
                    print "OK: Downtime was submited successfully\n";
                    exit(0);
                }
                case /Sorry, but you are not authorized to commit the specified command\./ {
                    print "ERROR: Maybe not authorized or wrong host- or servicename\n";
                    exit(1);
                }
                case /Author was not entered/ {
                    print "ERROR: No Author entered, define Author in \$nagiosUser var\n";
                    exit(1);
                }
                else {
                    print "ERROR: Some undefined error occured, turn debug mode on to view what happened\n";
                    exit(1);
                }
            }
        }
        case 3 {
            print "ERROR: HTTP Response code 3xx says \"moved url\" (".$oResponse->code.")\n";
            exit(1);
        }
        case 4 {
            print "ERROR: HTTP Response code 4xx says \"client error\" (".$oResponse->code.")\n";
            exit(1);
        }
        case 5 {
            print "ERROR: HTTP Response code 5xx says \"server error\" (".$oResponse->code.")\n";
            exit(1);
        }
        else {
            print "ERROR: HTTP Response code unhandled by script (".$oResponse->code.")\n";
            exit(1);
        }
    }
}

# Regular end of script
# #############################################################

# ###
# Subs
# ###

sub about {
        print "Nagios Downtime Script by Lars Michelsen \n" .
         "Usage:        nagios_downtime.pl [-H] [-S] [-T] [-h]\n" .
         "      -H      -       Hostname, like in Nagios\n" .
         "      -S      -       Servicename, like in Nagios (If empty, host downtime is submit)\n" .
         "      -T      -       Downtime in minutes\n" .
         "      -C      -       Comment for the downtime\n" .
         "      -D      -       Debug\n" .
         "      -h      -       This message\n";
}

sub gettime {
        my $timestamp;
        $timestamp = shift;

        if($timestamp eq "") {
                $timestamp = time;
        }

        my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime($timestamp);
        # correct values
        $year += 1900;
        $month += 1;

        # add leading 0 to values lower than 10
        $month = $month < 10 ? $month = "0".$month : $month;
        $mday = $mday < 10 ? $mday = "0".$mday : $mday;
        $hour = $hour < 10 ? $hour = "0".$hour : $hour;
        $min = $min < 10 ? $min = "0".$min : $min;
        $sec = $sec < 10 ? $sec = "0".$sec : $sec;

        switch ($nagiosDateFormat) {
            case "euro" {
                return $mday."\-".$month."\-".$year." ".$hour.":".$min.":".$sec;
            }
            case "us" {
                return $month."\-".$mday."\-".$year." ".$hour.":".$min.":".$sec;
            }
            case "iso8601" {
                return $year."\-".$month."\-".$mday." ".$hour.":".$min.":".$sec;
            }
            case "strict-iso8601" {
                return $year."\-".$month."\-".$mday."T".$hour.":".$min.":".$sec;
            }
            else {
                print "ERROR: No valid date format given in \$nagiosDateFormat";
                exit(1);
            }
        }
}

# #############################################################
# EOF
# #############################################################
