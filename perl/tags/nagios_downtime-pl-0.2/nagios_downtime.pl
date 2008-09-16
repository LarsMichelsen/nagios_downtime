#!/usr/bin/perl -w
# *********************************************************
# VERSION:      0.2
# CREATED:      27.03.06
# LAST UPDATED: 01.02.07 (by andurin@nagios-wiki.de)
# AUTHOR:       Lars Michelsen
# DECRIPTION:   Portiert von nagios_downtime.vbs
#                               Beim AusfÃ¼hren des Scriptes wird eine
#               Nachricht an den Nagios Server geschickt.
#               Durch diese Nachricht wird innerhalb der
#               nÃ¤chsten x Minuten fÃ¼r diesen Service keine
#               Benachrichtigung generiert
# PARAMS:       /H: Hostname (Wie im Nagios)
#               /S: Servicename (Wie im Nagios)
#               /T: Downtime von jetzt, in Minuten
#               /D: Debug
#               /?: Help
# CHANGES:
# 20.12.2006    Verwendung von Getopt::Long fuer Params
#               Grund: mit der original Logik wurde keine
#                      Servicedescription anerkannt
# 01.02.2007    New Config Option: $nagiosAuthName for setting
#               the right Basic Auth "Auth Name"
# *********************************************************
 
 
 
# Here you have to set some values!
my $nagiosServer = "YOUR.NAGIOSSERVER.DE"; # example: nagios.domain.de
my $nagiosWebServer = "YOUR.NAGIOS.WEB.SERVER"; # example: monitor.domain.de
my $nagiosCgiPath = "RELATIV-PATH-TO-CGI-BIN"; # example: /cgi-bin/
my $nagiosUser = "BASIC AUTH USERNAME"; # User to take for Authentication "nagiosadmin"
my $nagiosUserPw = "BASIC AUTH PASSWORD"; # Password for above User
my $nagiosAuthName = "BASIC AUTH NAME"; # example: "Nagios Access"
 
 
# Typ (1: Host Downtime, 2: Service Downtime)
my $typ = 1;
 
# Default-Donwtime in Minuten
my $downtime = 10;
 
 
# Debugmode: off => 0 or on => 1
my $debug = 0;
 
 
# Don't change anything below, except you know what you are doing.
 
use strict;
use warnings;
# Ping Befehl
use Net::Ping;
# Browser
use LWP 5.64;
use Sys::Hostname;
use Getopt::Long;
 
# Deklarieren der Variablen
my $arg;
my $p;
my $i = 0;
my $browser;
my $response;
my $hostname = "";
my $dienst = "";
my $start;
my $ende;
my $url = "";
my $help = "";
 
 
Getopt::Long::Configure('bundling');
GetOptions(
        "h"   => \$help, "help"        => \$help,
        "D"   => \$debug, "debug"        => \$debug,
        "T=i" => \$downtime, "downtime=i"       => \$downtime,
        "H=s" => \$hostname, "hostname=s"       => \$hostname,
        "S=s" => \$dienst, "service=s"  => \$dienst);
 
if ($help) {
        about();
        exit;
}
 
# Hostnamen ermitteln, sofern keiner gesetzt
if($hostname eq "") {
        $hostname = hostname;
}
 
# Festlegen der Startzeit
$start = gettime(time);
 
# Festlegen der Endzeit
$ende = gettime(time+$downtime*60);
 
# Wenn der Nagios Server nicht erreichbar ist, Script beenden
 
$p = Net::Ping->new();
if(!$p->ping($nagiosServer)) {
        # Server nicht anpingbar!
        if($debug == 1) {
                print $nagiosServer . " not reachable via ping!"
        }
        exit;
} else {
        # Normal weiterlaufen...
 
        # Browser initialisieren
        my $browser = LWP::UserAgent->new(env_proxy => 1,
        keep_alive => 1,
        timeout => 30);
        if($typ == 1) {
                # Schedule Host Downtime
                $url = "http://" . $nagiosWebServer . $nagiosCgiPath . "cmd.cgi?" .
                        "cmd_typ=55" .
                    "&cmd_mod=2" .
                    "&host=" . $hostname .
                    "&com_author=" . $nagiosUser .
                    "&com_data=Linux Downtime-Script" .
                    "&trigger=0" .
                    "&start_time=" . $start .
                    "&end_time=" . $ende .
                    "&fixed=1" .
                    "&childoptions=1" .
                    "&btnSubmit=Commit";
 
                if($debug == 1) {
                        print "HTTP-GET: " . $url;
                }
        } else {
                # Schedule Service Downtime
                $url = "http://" . $nagiosWebServer . $nagiosCgiPath . "cmd.cgi?" .
                        "cmd_typ=56" .
                        "&cmd_mod=2" .
                        "&host=" . $hostname .
                        "&service=" . $dienst .
                        "&com_author=" . $nagiosUser .
                        "&com_data=Linux Downtime-Script" .
                        "&trigger=0" .
                        "&start_time=" . $start .
                        "&end_time=" . $ende .
                        "&fixed=1" .
                        "&btnSubmit=Commit";
 
                if($debug == 1) {
                        print "HTTP-GET: " . $url;
                }
        }
 
        # Setzen der Benutzerdaten
        $browser->credentials($nagiosWebServer.':80', $nagiosAuthName, $nagiosUser => $nagiosUserPw);
 
        $response = $browser->get($url);
 
        if($debug == 1) {
                print "HTTP-Response: " . $response->content;
        }
}
$p->close();
 
# Normales Ende des Programms
# #############################################################
 
 
# ###
# Subroutinen
# ###
 
sub about {
        print "Nagios Downtime Script by Lars Michelsen <larsi\@nagios-wiki.de>\n" .
         "Usage:        nagios_downtime.pl [-H] [-S] [-T] [-h]\n" .
         "      -H      -       Hostname, like in Nagios\n" .
         "      -S      -       Servicename, like in Nagios\n" .
         "      -T      -       Downtime in minutes\n" .
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
        $year += 1900;
        $month += 1;
        return "$mday\-$month\-$year $hour:$min:$sec";
}
 
# #############################################################
# EOF
# #############################################################
