' ##############################################################################
' nagios_downtime.vbs
'
' Copyright (c) 2005-2009 Lars Michelsen <lars@vertical-visions.de>
' http://www.vertical-visions.de
'
' Permission is hereby granted, free of charge, to any person
' obtaining a copy of this software and associated documentation
' files (the "Software"), to deal in the Software without
' restriction, including without limitation the rights to use,
' copy, modify, merge, publish, distribute, sublicense, and/or sell
' copies of the Software, and to permit persons to whom the
' Software is furnished to do so, subject to the following
' conditions:
'
' The above copyright notice and this permission notice shall be
' included in all copies or substantial portions of the Software.
'
' THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
' EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
' OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
' NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
' HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
' WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
' FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
' OTHER DEALINGS IN THE SOFTWARE.
' ##############################################################################
' SCRIPT:       nagios_downtime
' AUTHOR:       Lars Michelsen <lars@vertical-visions.de>
' DECRIPTION:   Sends a HTTP(S)-GET to the nagios web server to
'	              enter a downtime for a host or service.
' CHANGES:
' 2005-07-11 v0.1 First creation of the script
'       |
'       |
' changes not tracked in details
'       |
'       V
' 2006-03-22 v0.6 - Added basic auth support
'                 - Several doc changes
'
' 2009-10-20 v0.7 - Complete recode according to current perl script
'                 - Reworked command line parameters
'                 - Script can handle different Nagios date formats now
'                 - Script can now delete downtimes when downtime id has been
'                   saved while scheduling the downtime before
'
' 2009-11-04 v0.8 - Default http/https ports are not added to the url anymore
'                 - Added option to ignore certificate problems
'
' $Id$
' ##############################################################################

Option Explicit

Dim nagiosWebProto, nagiosServer, nagiosWebServer, nagiosWebPort, nagiosCgiPath
Dim nagiosUser, nagiosUserPw, nagiosAuthName, nagiosDateFormat, proxyAddress
Dim storeDowntimeIds, downtimePath, downtimeId, downtimeType, downtimeDuration
Dim downtimeComment, debug, version, ignoreCertProblems

' ##############################################################################
' Configuration (-> Here you have to set some values!)
' ##############################################################################

' Protocol for the GET Request, In most cases "http", "https" is also possible
nagiosWebProto = "http"
' IP or FQDN of Nagios server (example: nagios.domain.de)
nagiosServer = "localhost"
' IP or FQDN of Nagios web server. In most cases same as $nagiosServer, if
' empty automaticaly using $nagiosServer
nagiosWebServer = ""
' Port of Nagios webserver
' This option is only being recognized when it is not the default port for the
' choosen protocol in "nagiosWebProto" option
nagiosWebPort = 80
' Web path to Nagios cgi-bin (example: /nagios/cgi-bin) (NO trailing slash!)
nagiosCgiPath = "/nagios/cgi-bin"
' User to take for authentication and author to enter the downtime (example:
' nagiosadmin)
nagiosUser = "nagiosadmin"
' Password for above user
nagiosUserPw = ""
' Name of authentication realm, set in the Nagios .htaccess file 
' (example: "Nagios Access")
nagiosAuthName = "Nagios Access"
' Nagios date format (same like set in value "date_format" in nagios.cfg)
nagiosDateFormat = "us"
' When you have to use a proxy server for access to the nagios server, set the
' URL here. The proxy will be set for this script for the choosen web protocol
' When this is set to 'env', the proxy settings will be read from IE settings
' When this is set to '', the script will use a direct connection
proxyAddress = ""
' When using ssl it may be ok for you to ignore untrusted/expired certificats
' Setting this to 1 all ssl certificate related problems should be ignored
ignoreCertProblems = 0

' Enable fetching and storing the downtime ids for later downtime removal
' The downtime IDs will be stored in a defined temp directory
storeDowntimeIds = 1
' The script will generate temporary files named (<host>.txt or 
' <host>-<service>.txt). The files will contain the script internal
' downtime ids and/or the nagios downtime ids.
' These files are needed for later downtime removal
downtimePath = "%temp%"

' Some default options (Usualy no changes needed below this)

' Script internal downtime id for a new downtime
' Using the current timestamp as script internal downtime identifier
' Not important to have the real timestamp but having a uniq counter
' which increases
downtimeId = CLng(DateDiff("s", "01/01/1970 00:00:00", Now) - 3600)
' Default downtime type (1: Host Downtime, 2: Service Downtime)
downtimeType = 1
' Default Downtime duration in minutes
downtimeDuration = 10
' Default Downtime text
downtimeComment = "Perl Downtime-Script"
' Default Debugmode: off => 0 or on => 1
debug = 0
' Script version
version = "0.7"

' ##############################################################################
' Don't change anything below, except you know what you are doing.
' ##############################################################################

Dim arg, p, i, oBrowser, oResponse, hostname, service, timeStart, timeEnd, url
Dim help, timeNow, timezone, mode, oFs, oFile, oNetwork, oShell

Const HTTPREQUEST_PROXYSETTING_PRECONFIG = 0
Const HTTPREQUEST_PROXYSETTING_DIRECT    = 1
Const HTTPREQUEST_PROXYSETTING_PROXY     = 2
Const FOR_READING = 1
Const FOR_WRITING = 2
Const FOR_APPENDING = 8
Const CREATE_IF_NOT_EXISTS = True
Const HTTPREQUEST_SSLERROR_IGNORE_FLAG = 4
Const HTTPREQUEST_SECURITY_IGNORE_ALL = 13056

Set oFS = CreateObject("Scripting.FilesystemObject")
	
hostname = ""
service = ""
url = ""
timeNow = Now
timezone = "local"
mode = "add"
help = 0

' Read all params
i = 0
Do While i < Wscript.Arguments.Count
	If WScript.Arguments(i) = "/H" or WScript.Arguments(i) = "-H" or UCase(WScript.Arguments(i)) = "-HOSTNAME" or UCase(WScript.Arguments(i)) = "/HOSTNAME" then
		' Hostname: /H, /hostname, -H, -hostname
		i = i + 1
		
		If i < Wscript.Arguments.Count Then
			hostname = WScript.Arguments(i)
		Else
			WScript.echo "ERROR: No hostname given"
			WScript.quit(1)
		End If
	ElseIf WScript.Arguments(i) = "/m" or WScript.Arguments(i) = "-m" or UCase(WScript.Arguments(i) = "-MODE") or UCase(WScript.Arguments(i)) = "/MODE" then
		' Mode: /m, /mode, -m, -mode
		i = i + 1
		
		mode = WScript.Arguments(i)
	ElseIf WScript.Arguments(i) = "/S" or WScript.Arguments(i) = "-S" or UCase(WScript.Arguments(i)) = "/SERVER" or UCase(WScript.Arguments(i)) = "-SERVER" then
		' Nagios Server: /S, /server, -S, -server
		i = i + 1
		
		nagiosServer = WScript.Arguments(i)
	ElseIf WScript.Arguments(i) = "/p" or WScript.Arguments(i) = "-p" or UCase(WScript.Arguments(i)) = "/PATH" or UCase(WScript.Arguments(i)) = "-PATH" then
		' Nagios CGI Path: /p, /path, -p, -path
		i = i + 1
		
		nagiosCgiPath = WScript.Arguments(i)
	ElseIf WScript.Arguments(i) = "/u" or WScript.Arguments(i) = "-u" or UCase(WScript.Arguments(i)) = "/USER" or UCase(WScript.Arguments(i)) = "-USER" then
		' Nagios User: /u, /user, -u, -user
		i = i + 1
		
		nagiosUser = WScript.Arguments(i)
	ElseIf WScript.Arguments(i) = "/P" or WScript.Arguments(i) = "-P" or UCase(WScript.Arguments(i)) = "/PASSWORD" or UCase(WScript.Arguments(i)) = "-PASSWORD" then
		' Nagios Password: /P, /password, -P, -password
		i = i + 1
		
		nagiosUserPw = WScript.Arguments(i)
	ElseIf WScript.Arguments(i) = "/s" or WScript.Arguments(i) = "-s" or UCase(WScript.Arguments(i)) = "/SERVICE" or UCase(WScript.Arguments(i)) = "-SERVICE" then
		' Servicename: /s, /service, -s, -service
		i = i + 1
		
		service = WScript.Arguments(i)
	ElseIf WScript.Arguments(i) = "/t" or WScript.Arguments(i) = "-t" or UCase(WScript.Arguments(i)) = "/DOWNTIME" or UCase(WScript.Arguments(i)) = "-DOWNTIME" Then
		' downtime duration: /t, /downtime, -t, -downtime
		i = i + 1
		
		downtimeDuration = WScript.Arguments(i)
	ElseIf WScript.Arguments(i) = "/c" or WScript.Arguments(i) = "-c" or UCase(WScript.Arguments(i)) = "/COMMENT" or UCase(WScript.Arguments(i)) = "-COMMENT" Then
		' downtime comment: /c, /comment, -c, -comment
		i = i + 1
		
		downtimeComment = WScript.Arguments(i)
	ElseIf UCase(WScript.Arguments(i)) = "/D" or UCase(WScript.Arguments(i)) = "-D" or UCase(WScript.Arguments(i)) = "/DEBUG" or UCase(WScript.Arguments(i)) = "-DEBUG" Then
		' debug mode: /d, -d, /debug, -debug
		debug = 1
	ElseIf WScript.Arguments(i) = "/?" or WScript.Arguments(i) = "-?" or WScript.Arguments(i) = "/h" or WScript.Arguments(i) = "-h" or WScript.Arguments(i) = "-help" or WScript.Arguments(i) = "/help" Then
		' help: /?, /h, /help, -?, -h, -help
		help = 1
	Else
		' ....
	End If
	
	i = i + 1
Loop

If help = 1 Then
	Call about()
	WScript.Quit(1)
End If

' Mode can be add or del, default is "add"
If mode = "" Then
	mode = "add"
End If

' Get hostname if not set via param
If hostname = "" Then
	' Auslesen des Hostnamens
	Set oNetwork = WScript.CreateObject("WScript.Network")
	hostname = LCase(oNetwork.ComputerName)
End If

' When no nagios webserver is set the webserver and Nagios should be on the same
' host 
If nagiosWebServer = "" Then
	nagiosWebServer = nagiosServer
End If

' When a service name is set, this will be a service downtime
If service <> "" Then
	downtimeType = 2
End If

' Initialize the port to be added to the url. If default http port (80) or
' default ssl port don't add anything
If nagiosWebProto = "http" And nagiosWebPort = 80 Then
	nagiosWebPort = ""
ElseIf nagiosWebProto = "https" And nagiosWebPort <> 443 Then
	nagiosWebPort = ""
Else
	nagiosWebPort = ":" & nagiosWebPort
End If

' Append the script internal downtime id when id storing is enabled
' The downtime ID is important to identify the just scheduled downtime for
' later removal. The CGIs do not provide the downtime id right after sending
' the schedule request. So it is important to tag the downtime with this.
If storeDowntimeIds = 1 Then
	downtimeComment = downtimeComment & " (ID:" & downtimeId & ")"
End If

' Expand the environment string in downtime path
If storeDowntimeIds = 1 Then
	Set oShell = CreateObject("WScript.Shell")
	downtimePath = oShell.ExpandEnvironmentStrings(downtimePath)
	Set oShell = Nothing
End If

' Calculate the start of the downtime
timeStart = gettime(timeNow)
 
' Calculate the end of the downtime
timeEnd = gettime(DateAdd("n", downtimeDuration, timeNow))

' Check if Nagios web server is reachable via ping, if not, terminate the script
If Not PingTest(nagiosWebServer) Then
	WScript.echo "ERROR: Given Nagios web server """ & nagiosWebServer & """ not reachable via ping!"
	WScript.Quit(1)
End If

' Initialize the browser
Set oBrowser = CreateObject("WinHttp.WinHttpRequest.5.1")

' Set the proxy address depending on the configured option
If proxyAddress = "env" Then
	oBrowser.SetProxy HTTPREQUEST_PROXYSETTING_PRECONFIG
	
	If debug = 1 Then
		WScript.echo "Proxy-Mode: Env (" & HTTPREQUEST_PROXYSETTING_PRECONFIG & ")"
	End If
ElseIf proxyAddress = "" Then
	oBrowser.SetProxy HTTPREQUEST_PROXYSETTING_DIRECT
	
	If debug = 1 Then
		WScript.echo "Proxy-Mode: Direct (" & HTTPREQUEST_PROXYSETTING_DIRECT & ")"
	End If
Else
	oBrowser.SetProxy HTTPREQUEST_PROXYSETTING_PROXY, proxyAddress
	
	If debug = 1 Then
		WScript.echo "Proxy-Mode: Proxy (" & HTTPREQUEST_PROXYSETTING_PROXY & "): " & proxyAddress
	End If
End If

' When enabled ignore all certificate problems
If ignoreCertProblems = 1 Then
  oBrowser.Option(HTTPREQUEST_SSLERROR_IGNORE_FLAG) = HTTPREQUEST_SECURITY_IGNORE_ALL
End If


' Handle the given action
Select Case mode
	Case "add"
		' Add a new scheduled downtime
		' ##########################################################################
		
		If downtimeType = 1 Then
			' Schedule Host Downtime
			url = nagiosWebProto & "://" & nagiosWebServer & nagiosWebPort & _
			      nagiosCgiPath & "/cmd.cgi?cmd_typ=55&cmd_mod=2" & _
			      "&host=" & hostname & _
			      "&com_author=" & nagiosUser & "&com_data=" & downtimeComment & _
			      "&trigger=0&start_time=" & timeStart & "&end_time=" & timeEnd & _
			      "&fixed=1&childoptions=1&btnSubmit=Commit"
		Else
			' Schedule Service Downtime
			url = nagiosWebProto & "://" & nagiosWebServer & nagiosWebPort & _
			      nagiosCgiPath & "/cmd.cgi?cmd_typ=56&cmd_mod=2" & _
			      "&host=" & hostname & "&service=" & service & _
			      "&com_author=" & nagiosUser & "&com_data=" & downtimeComment & _
			      "&trigger=0&start_time=" & timeStart & "&end_time=" & timeEnd & _
			      "&fixed=1&btnSubmit=Commit"
		End If
		
		If debug = 1 Then
			wscript.echo "HTTP-GET: " & url
		End If
		
		oBrowser.Open "GET", url
		setBrowserOptions()
		oBrowser.Send
		
		If debug = 1 Then
			Wscript.echo "HTTP-Response: " & oBrowser.ResponseText
			Wscript.echo "HTTP-Response-Code: " & oBrowser.Status
		End If
		
		' Handle response code, not in detail, only first char
		Select Case Left(oBrowser.Status, 1)
			' 2xx response code is OK
			Case 2
				If InStr(oBrowser.ResponseText, "Your command request was successfully submitted to Nagios for processing") > 0 Then
					' Save the id of the just scheduled downtime
					If storeDowntimeIds = 1 Then
						saveDowntimeId()
					
						WScript.echo "OK: Downtime was submited successfully"
						WScript.Quit(0)
					ElseIf InStr(oBrowser.ResponseText, "Sorry, but you are not authorized to commit the specified command") > 0 Then
						WScript.echo "ERROR: Maybe not authorized or wrong host- or servicename"
						WScript.Quit(1)
					ElseIf InStr(oBrowser.ResponseText, "Author was not entered") > 0 Then
						WScript.echo "ERROR: No Author entered, define Author in nagiosUser var"
						WScript.Quit(1)
					Else
						WScript.echo "ERROR: Some undefined error occured, turn debug mode on to view what happened"
						WScript.Quit(1)
					End If
				End If
			Case 3
				WScript.echo "ERROR: HTTP Response code 3xx says ""moved url"" (" & oBrowser.Status & ")"
				WScript.Quit(1)
			Case 4
				WScript.echo "ERROR: HTTP Response code 4xx says ""client error"" (" & oBrowser.Status & ")"
				WScript.echo "Hint: This could be caused by wrong auth credentials and/or datetime settings in this script"
				WScript.Quit(1)
			Case 5
				WScript.echo "ERROR: HTTP Response code 5xx says ""server Error"" (" & oBrowser.Status & ")"
				WScript.Quit(1)
			Case Else
				WScript.echo "ERROR: HTTP Response code unhandled by script (" & oBrowser.Status & ")"
				WScript.Quit(1)
		End Select
	Case "del"
		' Delete the last scheduled downtime
		' ##########################################################################
		
		If storeDowntimeIds <> 1 Then
			WScript.echo "ERROR: Unable to remove a downtime. The storingDowntimeIds option is set to disabled."
			WScript.Quit(1)
		End If
		
		' Read all internal downtime ids for this host/service
		Dim aDowntimes
		aDowntimes = getDowntimeIds()
		
		' Only proceed when downtimes found
		If UBound(aDowntimes)+1 > 0 Then
			' Sort downtimes (lowest number at top)
			aDowntimes = bubblesort(aDowntimes)
			
			If debug = 1 Then
				WScript.echo "Trying to delete with internal downtime id: " & aDowntimes(0)
			End If
			
			' Get the nagios downtime id for the last scheduled downtime
			Dim nagiosDowntimeId
			nagiosDowntimeId = getNagiosDowntimeId(aDowntimes(0))
			
			If debug = 1 Then
				WScript.echo "Translated downtime id: " & aDowntimes(0) & "(internal) => " & nagiosDowntimeId & " (Nagios)"
			End If
			
			If nagiosDowntimeId <> "" Then
				deleteDowntime(nagiosDowntimeId)
				
				' Delete internal downtime id from downtime file
				' This only gets executed on successfull deleteDowntime() cause the
				' function terminates the script on any problem
				delDowntimeId(aDowntimes(0))
			Else
				WScript.echo "ERROR: Unable to remove the downtime. Nagios downtime not found. Maybe already deleted? Or not scheduled yet?"
				WScript.Quit(1)
			End If
		Else
			WScript.echo "ERROR: Unable to remove a downtime. No previously scheduled downtime found."
			WScript.Quit(1)
		End If
	Case Else
		WScript.echo "ERROR: Unknown mode was set (Available: add, del)"
		WScript.Quit(1)
End Select

Set oBrowser = Nothing
Set oFile = Nothing
Set oFS = Nothing

' Regular end of script
' ##############################################################################

' #############################################################
' Subs
' #############################################################

Sub setBrowserOptions()
	oBrowser.SetRequestHeader "User-Agent", "nagios_downtime.vbs / " & version
	
	If debug = 1 Then
		wscript.echo "User-Agent: " & "nagios_downtime.vbs / " & version
	End If
	
	' Only try to auth if auth informations are given
	If nagiosAuthName <> "" And nagiosUserPw <> "" Then
		
		If debug = 1 Then
			wscript.echo "Nagios Auth: Server auth"
			wscript.echo "Nagios User: " & nagiosUser
			wscript.echo "Nagios Password: " & nagiosUserPw
		End If
		
		' Set the login information (0: Server auth / 1: Proxy auth)
		oBrowser.SetCredentials nagiosUser, nagiosUserPw, 0
	End If
End Sub

Function bubblesort(arrSort)
	Dim i, j, arrTemp
	For i = 0 to UBound(arrSort)
		For j = i + 1 to UBound(arrSort)
			If arrSort(i) < arrSort(j) Then
				arrTemp = arrSort(i)
				arrSort(i) = arrSort(j)
				arrSort(j) = arrTemp
			End If
		Next
	Next
	bubblesort = arrSort
End Function


Sub about()
		WScript.echo "Usage:" & vbcrlf & vbcrlf & _
		             "  nagios_downtime [-m add] [-H <hostname>] [-s <service>] [-t <minutes>]" & vbcrlf & _
		             "                  [-S <webserver>] [-p <cgi-bin-path>] [-u <username>]" & vbcrlf & _
		             "                  [-p <password>] [-d]" & vbcrlf & _
		             "  nagios_downtime -m del [-H <hostname>] [-s <service>] [-S <webserver>]" & vbcrlf & _
		             "                  [-p <cgi-bin-path>] [-u <username>] [-p <password>] [-d]" & vbcrlf & _
		             "  nagios_downtime -h" & vbcrlf & _
		             "" & vbcrlf & _
		             "Nagios Downtime Script by Lars Michelsen <lars@vertical-visions.de>" & vbcrlf & _
		             "Sends a HTTP(S) request to the nagios cgis to add a downtime for a host or" & vbcrlf & _
		             "service. Since version 0.7 the script can remove downtimes too when being" & vbcrlf & _
		             "called in ""del"" mode." & vbcrlf & _
		             "" & vbcrlf & _
		             "Parameters:" & vbcrlf & _
		             " -m, --mode       Mode to run the script in (Available: add, del)" & vbcrlf & _
		             "" & vbcrlf & _
		             " -H, --hostname   Name of the host the downtime should be scheduled for." & vbcrlf & _
		             "                  Important: The name must be same as in Nagios." & vbcrlf & _
		             " -s, --service    Name of the service the downtime should be scheduled for." & vbcrlf & _
		             "                  Important: The name must be same as in Nagios. " & vbcrlf & _
		             "                  When empty or not set a host downtime is being submited." & vbcrlf & _
		             " -t, --downtime   Duration of the fixed downtime in minutes" & vbcrlf & _
		             " -c, --comment    Comment for the downtime" & vbcrlf & _
		             " " & vbcrlf & _
		             " -S, --server     Nagios Webserver address (IP or DNS)" & vbcrlf & _
		             " -p, --path       Web path to Nagios cgi-bin (Default: /nagios/cgi-bin)" & vbcrlf & _
		             " -u, --user       Usernate to be used for accessing the CGIs" & vbcrlf & _
		             " -P, --password   Password for accessing the CGIs" & vbcrlf & _
		             " " & vbcrlf & _
		             " -d, --debug      Enable debug mode" & vbcrlf & _
		             " -h, --help       Show this message" & vbcrlf & _
		             "" & vbcrlf & _
		             "If you call nagios_downtime without parameters the script takes the default options which are" & vbcrlf & _
		             "hardcoded in the script." & vbcrlf & _
		             ""
End Sub

Sub delDowntimeId(internalId)
	Dim file, aDowntimes, id
	
	file = downtimePath & "/"
	If downtimeType = 1 Then
		file = file & hostname & ".txt"
	Else
		file = file & hostname & "-" & service & ".txt"
	End If
	
	' Read all downtimes to array
	
	Set oFile = oFS.OpenTextfile(file, FOR_READING)
	Do While Not oFile.AtEndOfStream
		Push aDowntimes, oFile.Readline
	Loop
	oFile.Close
	
	' Filter downtime
	ArrayRemoveVal aDowntimes, internalId
	
	' Write downtimes back to array
	Set oFile = oFS.OpenTextfile(file, FOR_WRITING, CREATE_IF_NOT_EXISTS)
	For Each id In aDowntimes
		If debug = 1 Then
			wscript.echo "Rewriting id to file: " & id
		End If
		oFile.Writeline id
	Next
	oFile.Close
	
	Set oFile = Nothing
End Sub

Function getDowntimeIds()
	Dim file, aDowntimes, sLine, oRegex, oMatches
	aDowntimes = Array()
	
	file = downtimePath & "/"
	If downtimeType = 1 Then
		file = file & hostname & ".txt"
	Else
		file = file & hostname & "-" & service & ".txt"
	End If
	
	Set oRegex = New RegExp
	oRegex.Pattern = "[0-9]+"
	
	' Read all downtimes to array
	
	If oFS.FileExists(file) Then
		Set oFile = oFS.OpenTextfile(file, FOR_READING)
		Do While Not oFile.AtEndOfStream
			sLine = oFile.Readline
			
			' Do some validation
			If oRegex.Execute(sLine).Count > 0 Then
				Push aDowntimes, sLine
			End If
		Loop
		oFile.Close
	Else
		WScript.echo "ERROR: Could not open temporary file (" & file & ")"
		WScript.Quit(1)
	End If
	
	getDowntimeIds = aDowntimes
End Function

Sub saveDowntimeId()
	Dim file
	
	file = downtimePath & "/"
	If downtimeType = 1 Then
		file = file & hostname & ".txt"
	Else
		file = file & hostname & "-" & service & ".txt"
	End If
	
	If debug = 1 Then
		wscript.echo "Saving downtime to file: " & file
	End If
	
	Set oFile = oFS.OpenTextfile(file, FOR_APPENDING, CREATE_IF_NOT_EXISTS)
	oFile.Writeline downtimeId
	oFile.Close

	' FIXME: Error handling
	'WScript.echo "ERROR: Could not write downtime to temporary file (" & $file & ")"
	'WScript.Quit(1)
End Sub

Function getNagiosDowntimeId(internalId)
	getNagiosDowntimeId = ""
	
	Dim aDowntimes, id
	' Get all downtimes
	aDowntimes = getAllDowntimes()

	' Filter the just scheduled downtime
	For Each id In aDowntimes
		' Matching by:
		'  - internal id in comment field
		'  - triggerId: N/A
		If id("triggerId") = "N/A" And InStr(id("comment"), "(ID:" & internalId & ")") > 0 Then
			If debug = 1 Then
				WScript.echo "Found matching downtime: " & id("host")  & " " & id("service") & " " & id("entryTime") & " " & id("downtimeId")
			End If
			
			getNagiosDowntimeId = id("downtimeId")
		End If
	Next
End Function

Sub deleteDowntime(nagiosDowntimeId)
	If nagiosDowntimeId = "" Then
		WScript.echo "ERROR: Unable to delete downtime. Nagios Downtime ID not given"
		WScript.quit(1)
	End If
	
	url = nagiosWebProto & "://" & nagiosWebServer & nagiosWebPort & nagiosCgiPath & "/cmd.cgi?cmd_typ=78&cmd_mod=2&down_id=" & nagiosDowntimeId & "&btnSubmit=Commit"
	
	If debug = 1 Then
		WScript.echo "HTTP-GET: " & url
	End If
	
	oBrowser.Open "GET", url
	setBrowserOptions()
	oBrowser.Send
	
	If debug = 1 Then
		Wscript.echo "HTTP-Response: " & oBrowser.ResponseText
	End If
	
	' Handle response code, not in detail, only first char
	Select Case Left(oBrowser.Status, 1)
		' 2xx response code is OK
		Case 2
			If InStr(oBrowser.ResponseText, "Your command request was successfully submitted to Nagios for processing") > 0 Then
				WScript.echo "OK: Downtime (ID: " & nagiosDowntimeId & ") has been deleted"
			ElseIf InStr(oBrowser.ResponseText, "Sorry, but you are not authorized to commit the specified command") > 0 Then
				WScript.echo "ERROR: Maybe not authorized or wrong host- or servicename"
				WScript.Quit(1)
			ElseIf InStr(oBrowser.ResponseText, "Author was not entered") > 0 Then
				WScript.echo "ERROR: No Author entered, define Author in nagiosUser var"
				WScript.Quit(1)
			Else
				WScript.echo "ERROR: Some undefined error occured, turn debug mode on to view what happened"
				WScript.Quit(1)
			End If
		Case 3
			WScript.echo "ERROR: HTTP Response code 3xx says ""moved url"" (" & oBrowser.Status & ")"
			WScript.Quit(1)
		Case 4
			WScript.echo "ERROR: HTTP Response code 4xx says ""client error"" (" & oBrowser.Status & ")"
			WScript.echo "Hint: This could be caused by wrong auth credentials and/or datetime settings in this script"
			WScript.Quit(1)
		Case 5
			WScript.echo "ERROR: HTTP Response code 5xx says ""server Error"" (" & oBrowser.Status & ")"
			WScript.Quit(1)
		Case Else
			WScript.echo "ERROR: HTTP Response code unhandled by script (" & oBrowser.Status & ")"
			WScript.Quit(1)
	End Select
End Sub

Function getAllDowntimes()
	Dim aDowntimes, oRegex, oMatches, oDict
	aDowntimes = Array()
	
	' Url to downtime page
	url = nagiosWebProto & "://" & nagiosWebServer & nagiosWebPort & nagiosCgiPath & "/extinfo.cgi?type=6"

	If debug = 1 Then
		WScript.echo "HTTP-GET: " & url
	End If
	
	' Fetch information via HTTP-GET
  oBrowser.Open "GET", url
	setBrowserOptions()
	oBrowser.Send
	
	If debug = 1 Then
		WScript.echo "HTTP-Response: " & oBrowser.ResponseText
	End If
	
	Set oRegex = New RegExp
	oRegex.IgnoreCase = True 
	
	' Parse all downtimes to an array
	Dim lineType, sLine
	lineType = ""
	' Removed vbCrLf here
	For Each sLine In Split(oBrowser.ResponseText, vblf)
		' Filter only downtime lines
		oRegex.Pattern = "CLASS=\'downtime(Odd|Even)"
		Set oMatches = oRegex.Execute(sLine)
		
		If oMatches.Count > 0 Then
			lineType = "downtime" & oMatches(0).SubMatches(0)
			
			oRegex.Pattern = "<tr\sCLASS=\'" & lineType & "\'><td\sCLASS=\'" & lineType & _
			                 "\'><A\sHREF=\'extinfo\.cgi\?type=1&host=([^\']+)\'>[^<]+<\/A>" & _
			                 "<\/td><td\sCLASS=\'" & lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & _
			                 lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & lineType & "\'>([^<]+)" & _
			                 "<\/td><td\sCLASS=\'" & lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & _
			                 lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & lineType & "\'>([^<]+)" & _
			                 "<\/td><td\sCLASS=\'" & lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & _
			                 lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & lineType & "\'>([^<]+)<\/td>"
			Set oMatches = oRegex.Execute(sLine)
			
			If oMatches.Count > 0 Then
				' Host downtime:
				' <tr CLASS='downtimeEven'><td CLASS='downtimeEven'><A HREF='extinfo.cgi?type=1&host=dev.nagvis.org'>dev.nagvis.org</A></td><td CLASS='downtimeEven'>10-13-2009 09:15:35</td><td CLASS='downtimeEven'>Nagios Admin</td><td CLASS='downtimeEven'>Perl Downtime-Script</td><td CLASS='downtimeEven'>01-10-2010 09:15:35</td><td CLASS='downtimeEven'>01-10-2010 09:25:35</td><td CLASS='downtimeEven'>Fixed</td><td CLASS='downtimeEven'>0d 0h 10m 0s</td><td CLASS='downtimeEven'>9</td><td CLASS='downtimeEven'>N/A</td>
				
				Set oDict = CreateObject("Scripting.Dictionary")
				
				If debug = 1 Then
					WScript.echo "Found host downtime:"
					WScript.echo "Host: " & oMatches(0).SubMatches(0) & _
					             " EntryTime: " & oMatches(0).SubMatches(1) & _
					             " User: " & oMatches(0).SubMatches(2) & _
					             " Comment: " & oMatches(0).SubMatches(3) & _
					             " Start: " & oMatches(0).SubMatches(4) & _
					             " End: " & oMatches(0).SubMatches(5) & _
					             " Type: " & oMatches(0).SubMatches(6) & _
					             " Duration: " & oMatches(0).SubMatches(7) & _
					             " DowntimeID: " & oMatches(0).SubMatches(8) & _
					             " TriggerID: " & oMatches(0).SubMatches(9)
				End If
				
				oDict.Add "host", oMatches(0).SubMatches(0)
				oDict.Add "service", ""
				oDict.Add "entryTime", oMatches(0).SubMatches(1)
				oDict.Add "user", oMatches(0).SubMatches(2)
				oDict.Add "comment", oMatches(0).SubMatches(3)
				oDict.Add "start", oMatches(0).SubMatches(4)
				oDict.Add "end", oMatches(0).SubMatches(5)
				oDict.Add "type", oMatches(0).SubMatches(6)
				oDict.Add "duration", oMatches(0).SubMatches(7)
				oDict.Add "downtimeId", oMatches(0).SubMatches(8)
				oDict.Add "triggerId", oMatches(0).SubMatches(9)
				
				' Push to array
				ReDim Preserve aDowntimes(UBound(aDowntimes) + 1)
				Set aDowntimes(UBound(aDowntimes)) = oDict
			Else
				oRegex.Pattern = "<tr\sCLASS=\'" & lineType & "\'><td\sCLASS=\'" & lineType & _
				                 "\'><A\sHREF=\'extinfo\.cgi\?type=1&host=([^\']+)\'>[^<]+" & _
				                 "<\/A><\/td><td\sCLASS=\'" & lineType & "\'><A\sHREF=\'" & _
				                 "extinfo\.cgi\?type=2&host=[^\']+&service=([^\']+)\'>[^<]+" & _
				                 "<\/A><\/td><td\sCLASS=\'" & lineType & "\'>([^<]+)<\/td>" & _
				                 "<td\sCLASS=\'" & lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & _
				                 lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & lineType & "\'>" & _
				                 "([^<]+)<\/td><td\sCLASS=\'" & lineType & "\'>([^<]+)<\/td>" & _
				                 "<td\sCLASS=\'" & lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & _
				                 lineType & "\'>([^<]+)<\/td><td\sCLASS=\'" & lineType & "\'>" & _
				                 "([^<]+)<\/td><td\sCLASS=\'" & lineType & "\'>([^<]+)<\/td>"
				Set oMatches = oRegex.Execute(sLine)
				
				If oMatches.Count > 0 Then
					' Service downtime:
					' <tr CLASS='downtimeEven'><td CLASS='downtimeEven'><A HREF='extinfo.cgi?type=1&host=dev.nagvis.org'>dev.nagvis.org</A></td><td CLASS='downtimeEven'><A HREF='extinfo.cgi?type=2&host=dev.nagvis.org&service=HTTP'>HTTP</A></td><td CLASS='downtimeEven'>10-13-2009 10:28:30</td><td CLASS='downtimeEven'>Nagios Admin</td><td CLASS='downtimeEven'>test</td><td CLASS='downtimeEven'>10-13-2009 10:28:11</td><td CLASS='downtimeEven'>10-13-2009 12:28:11</td><td CLASS='downtimeEven'>Fixed</td><td CLASS='downtimeEven'>0d 2h 0m 0s</td><td CLASS='downtimeEven'>145</td><td CLASS='downtimeEven'>N/A</td>
					
					Set oDict = CreateObject("Scripting.Dictionary")
					
					If debug = 1 Then
						WScript.echo "Found service downtime:"
						WScript.echo "Host: " & oMatches(0).SubMatches(0) & _
						             " Service: " & oMatches(0).SubMatches(1) & _
						             " EntryTime: " & oMatches(0).SubMatches(2) & _
						             " User: " & oMatches(0).SubMatches(3) & _
						             " Comment: " & oMatches(0).SubMatches(4) & _
						             " Start: " & oMatches(0).SubMatches(5) & _
						             " End: " & oMatches(0).SubMatches(6) & _
						             " Type: " & oMatches(0).SubMatches(7) & _
						             " Duration: " & oMatches(0).SubMatches(8) & _
						             " DowntimeID: " & oMatches(0).SubMatches(9) & _
						             " TriggerID: " & oMatches(0).SubMatches(10)
					End If
					
					oDict.Add "host", oMatches(0).SubMatches(0)
					oDict.Add "service", oMatches(0).SubMatches(1)
					oDict.Add "entryTime", oMatches(0).SubMatches(2)
					oDict.Add "user", oMatches(0).SubMatches(3)
					oDict.Add "comment", oMatches(0).SubMatches(4)
					oDict.Add "start", oMatches(0).SubMatches(5)
					oDict.Add "end", oMatches(0).SubMatches(6)
					oDict.Add "type", oMatches(0).SubMatches(7)
					oDict.Add "duration", oMatches(0).SubMatches(8)
					oDict.Add "downtimeId", oMatches(0).SubMatches(9)
					oDict.Add "triggerId", oMatches(0).SubMatches(10)
					
					' Push to array
					ReDim Preserve aDowntimes(UBound(aDowntimes) + 1)
					Set aDowntimes(UBound(aDowntimes)) = oDict
				End If
			End If
		End If
	Next
	
	getAllDowntimes = aDowntimes
End Function

' Funktion zum Test, ob ein Rechner per Ping erreichbar ist
' Übergabeparameter: IP oder Hostname
Function PingTest(strHostOrIP)
	' Deklarieren der Variablen
	Dim objSh, strCommand, intWindowStyle, blnWaitOnReturn
	
	' Bauen des Kommandos
	strCommand = "%ComSpec% /C %SystemRoot%\system32\ping.exe -n 1 " & strHostOrIP & " | " & "%SystemRoot%\system32\find.exe /i " & Chr(34) & "TTL=" & Chr(34)
	Set objSh = WScript.CreateObject("WScript.Shell")
	
	' Ausführen des Kommandos und Füllen des Rückgabeparameters
	PingTest = Not CBool(objSh.Run(strCommand, 0, True))
	
	Set objSh = Nothing
End Function

Function gettime(dateTime)

	If dateTime = "" Then
		dateTime = Now
	End If
	
	Dim sec, min, h, mday, m, y
	sec = Second(dateTime)
	min = Minute(dateTime)
	h = Hour(dateTime)
	mday = Day(dateTime)
	m = Month(dateTime)
	y = Year(dateTime)

	' add leading 0 to values lower than 10
	If m < 10 Then
		m = "0" & m
	End If
	If mday < 10 Then
		mday = "0" & mday
	End If
	If h < 10 Then
		h = "0" & h
	End If
	If min < 10 Then
		min = "0" & min
	End If
	If sec < 10 Then
		sec = "0" & sec
	End If
	
	Select Case nagiosDateFormat
		Case "euro"
			gettime = mday & "-" & m & "-" & y & " " & h & ":" & min & ":" & sec
		Case "us"
			gettime = m & "-" & mday & "-" & y & " " & h & ":" & min & ":" & sec
		Case "iso8601"
			gettime = y & "-" & m & "-" & mday & " " & h & ":" & min & ":" & sec
		Case "strict-iso8601"
			gettime = y & "-" & m & "-" & mday & "T" & h & ":" & min & ":" & sec
		Case Else
			WScript.echo "ERROR: No valid date format given in nagiosDateFormat var"
			WScript.quit(1)
	End Select
End Function

Function Push(ByRef mArray, ByVal mValue)
	Dim mValEl
	
	If IsArray(mArray) Then
		If IsArray(mValue) Then
			For Each mValEl In mValue
				Redim Preserve mArray(UBound(mArray) + 1)
				mArray(UBound(mArray)) = mValEl
			Next
		Else
			Redim Preserve mArray(UBound(mArray) + 1)
			mArray(UBound(mArray)) = mValue
		End If
	Else
		If IsArray(mValue) Then
			mArray = mValue
		Else
			mArray = Array(mValue)
		End If
	End If
	
	Push = UBound(mArray)
End Function

Sub ArrayRemoveVal(ByRef arr, ByVal val)
	Dim i, j
	If IsArray(arr) Then
		i = 0 : j = -1
		For i = 0 To UBound(arr)
			If arr(i) <> val Then
				j = j + 1
				arr(j) = arr(i)
			End If
		Next
		ReDim Preserve arr(j)
	End If
End Sub


' #############################################################
' EOF
' #############################################################