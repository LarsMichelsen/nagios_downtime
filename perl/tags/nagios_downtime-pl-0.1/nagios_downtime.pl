#!/usr/bin/perl
# *********************************************************
# VERSION:      0.1
# CREATED:      27.03.06
# LAST UPDATED: 27.03.06
# AUTHOR:       Lars Michelsen
# DECRIPTION:   Portiert von nagios_downtime.vbs
#				Beim Ausführen des Scriptes wird eine 
#               Nachricht an den Nagios Server geschickt.
#               Durch diese Nachricht wird innerhalb der
#               nächsten x Minuten für diesen Service keine
#               Benachrichtigung generiert
# PARAMS:       /H: Hostname (Wie im Nagios)
#               /S: Servicename (Wie im Nagios)
#               /T: Downtime von jetzt, in Minuten
#               /D: Debug
#               /?: Help
# *********************************************************

use strict;
use warnings;
# Ping Befehl
use Net::Ping;
# Browser
use LWP 5.64;
use Sys::Hostname;

# Deklarieren der Variablen
my $arg;
my $p;
my $i = 0;
my $browser;
my $response;
my $hostname = "";
my $dienst = "";
# Typ (1: Host Downtime, 2: Service Downtime)
my $typ = 1;
# Default-Donwtime in Minuten
my $downtime = 10;
my $start;
my $ende;
# Debugmode off
my $debug = 0;
my $url = "";

my $nagiosServer = "sdmsysmon1.sdm.de";
my $nagiosWebServer = "sdmsysmon1.sdm.de";
my $nagiosCgiPath = "/org/ti-sysmon/nagios/cgi-bin/";
my $nagiosUser = "sysmon";
my $nagiosUserPw = "BigBrother";

# Alle parameter auslesen
foreach $arg (@ARGV) {
	# Hostname
	if(uc $arg eq "/H" or uc $arg eq "-H") {
		$i += 1;
		$hostname = $ARGV[$i];
	} else {
		# Servicename
		if(uc $arg eq "/S" or uc $arg eq "-S") {
			$i += 1;
			$dienst = $ARGV[$i];
			$typ = 2;
		} else {
			# Downtime
			if(uc $arg eq "/T" or uc $arg eq "-T") {
				$i += 1;
				$downtime = $ARGV[$i];
			} else {
				# Debug
				if(uc $arg eq "/D" or uc $arg eq "-d") {
					$debug = 1;
				} else {
					# Help
					if(uc $arg eq "/?" or uc $arg eq "-?") {
						# About & Quit
						about();
						exit;
					}
				}
			}
		}
	}
	$i += 1;
}

# Hostnamen ermitteln, sofern keiner gesetzt
if($hostname eq "") {
	$hostname = hostname;
}

# Festlegen der Startzeit
$start = gettime();

# Festlegen der Endzeit
$ende = gettime(time+$downtime*60);

# Wenn der Nagios Server nicht erreichbar ist, Script beenden
# Prüfen, ob der Helpdesk-Server erreichbar ist
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
	$browser->credentials($nagiosWebServer.':80', 'Sysmon Portal', $nagiosUser => $nagiosUserPw);
	
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
	 "Usage:	nagios_downtime.vbs [/H] [/S] [/T] [/?]\n" .
	 "	/H	-	Hostname, like in Nagios\n" .
	 "	/S	-	Servicename, like in Nagios\n" .
	 "	/T	-	Downtime in minutes\n" .
	 "	/D	-	Debug\n" .
	 "	/?	-	This message\n";
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
