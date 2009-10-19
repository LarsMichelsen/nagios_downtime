' *********************************************************
' VERSION:      0.6
' CREATED:      11.07.05
' LAST UPDATED: 22.03.06
' AUTHOR:       Lars Michelsen
' DECRIPTION:   Beim Ausführen des Scriptes wird eine 
'               Nachricht an den Nagios Server geschickt.
'               Durch diese Nachricht wird innerhalb der
'               nächsten x Minuten für diesen Service keine
'               Benachrichtigung generiert
' PARAMS:       /H: Hostname (Wie im Nagios)
'               /S: Servicename (Wie im Nagios)
'               /T: Downtime von jetzt, in Minuten
'               /D: Debug
'               /?: Help
' *********************************************************

Dim i
Dim WinHttpReq
Dim hostname
Dim dienst
Dim typ
Dim downtime
Dim start
Dim endzeit
Dim ende
Dim debug

Dim nagiosServer
Dim nagiosUser
Dim nagiosUserPw

i = 0
hostname = ""
dienst = ""
' Typ (1: Host Downtime, 2: Service Downtime)
typ = 1
' Default-Donwtime in Minuten
downtime = 10
' Debugmode off
debug = 0

nagiosServer = "nagios.domain.de"
nagiosWebServer = "nagios.domain.de"
nagiosCgiPath = "/nagios/cgi-bin/"
nagiosUser = "nagiosadmin"
nagiosUserPw = "test"

' Alle parameter auslesen
Do While i < Wscript.Arguments.Count
	' Hostname
	If Ucase(WScript.Arguments(i)) = "/H" or Ucase(WScript.Arguments(i)) = "-H" then
		i = i + 1
		hostname = WScript.Arguments(i)
	' Servicename
	ElseIf Ucase(WScript.Arguments(i)) = "/S" or Ucase(WScript.Arguments(i)) = "-S" then
		i = i + 1
		dienst = WScript.Arguments(i)
		typ = 2
	' Downtime
	ElseIf WScript.Arguments(i) = "/T" or WScript.Arguments(i) = "-T" Then
		i = i + 1
		downtime = WScript.Arguments(i)
	ElseIf WScript.Arguments(i) = "/D" or WScript.Arguments(i) = "-D" Then
		debug = 1
	ElseIf WScript.Arguments(i) = "/?" or WScript.Arguments(i) = "-?" Then
		Call About()
		WScript.Quit(1)
	Else
		' ....
	End If
	
	i = i+1
Loop

If hostname = "" Then
	' Auslesen des Hostnamens
	Set WshNetwork = WScript.CreateObject("WScript.Network")
	hostname = LCase(WshNetwork.ComputerName)
End If

' Festlegen der Startzeit
start = Day(Now) & "-" & Month(Now) & "-" & Year(Now) & " " & Hour(Now) & ":" & Minute(Now) & ":" & Second(Now)

' In 5 Minuten sollte der Neustart durch sein
endzeit = DateAdd("n",downtime,now)

' Festlegen der Endzeit
ende = Day(endzeit) & "-" & Month(endzeit) & "-" & Year(endzeit) & " " & Hour(endzeit) & ":" & Minute(endzeit) & ":" & Second(endzeit)

' Wenn der Nagios Server nicht erreichbar ist, Script beenden
If Not PingTest(nagiosServer) Then
	If debug = 1 Then
		MsgBox nagiosServer & " not reachable via ping!"
	End If
	WScript.Quit(1)
Else
	Set WinHttpReq = CreateObject("WinHttp.WinHttpRequest.5.1")
	
	If typ = 1 Then
		' Schedule Host Downtime
		WinHttpReq.Open "GET", "http://" & nagiosWebServer & nagiosCgiPath & "cmd.cgi?" & _
			"cmd_typ=55" & _
		    "&cmd_mod=2" & _
		    "&host=" & hostname & _
		    "&com_author=" & nagiosUser & _
		    "&com_data=Windows Downtime-Script (Group Policy)" & _
		    "&trigger=0" & _
		    "&start_time=" & start & _
		    "&end_time=" & ende & _
		    "&fixed=1" & _
		    "&childoptions=1" & _
		    "&btnSubmit=Commit", False
		
		If debug = 1 Then
			MsgBox "HTTP-GET: http://" & nagiosWebServer & nagiosCgiPath & "cmd.cgi?" & _
			"cmd_typ=55" & _
		    "&cmd_mod=2" & _
		    "&host=" & hostname & _
		    "&com_author=" & nagiosUser & _
		    "&com_data=Windows Downtime-Script (Group Policy)" & _
		    "&trigger=0" & _
		    "&start_time=" & start & _
		    "&end_time=" & ende & _
		    "&fixed=1" & _
		    "&childoptions=1" & _
		    "&btnSubmit=Commit"
		End If
	Else
		' Schedule Service Downtime
		WinHttpReq.Open "GET", "http://" & nagiosWebServer & nagiosCgiPath & "cmd.cgi?" & _
			"cmd_typ=56" & _
		    "&cmd_mod=2" & _
			"&host=" & hostname & _
			"&service=" & dienst & _
			"&com_author=" & nagiosUser & _
			"&com_data=Windows Downtime-Script" & _
			"&trigger=0" & _
			"&start_time=" & start & _
		    "&end_time=" & ende & _
		    "&fixed=1" & _
			"&btnSubmit=Commit", False
			
		If debug = 1 Then
			MsgBox "HTTP-GET: http://" & nagiosWebServer & nagiosCgiPath & "cmd.cgi?" & _
			"cmd_typ=56" & _
		    "&cmd_mod=2" & _
			"&host=" & hostname & _
			"&service=" & dienst & _
			"&com_author=" & nagiosUser & _
			"&com_data=Windows Downtime-Script" & _
			"&trigger=0" & _
			"&start_time=" & start & _
		    "&end_time=" & ende & _
		    "&fixed=1" & _
			"&btnSubmit=Commit"
		End If
	End If
	
	' Setzen des Logins (Die 0 steht für die Server-Authetication / 1 wäre Proxy-Authentication)
	WinHttpReq.SetCredentials nagiosUser, nagiosUserPw, 0
	
	' Absenden des HTTP Requests
	WinHttpReq.Send
	
	If debug = 1 Then
		MsgBox "HTTP-Response: " & WinHttpReq.ResponseText
	End If
End If


' Reguläres Ende des Scriptes
' *********************************************************

Function About
	WScript.Echo "Nagios Downtime Script by Lars Michelsen <larsi@nagios-wiki.de>" & vbLF & vbLF & _
	 "Usage:	nagios_downtime.vbs [/H] [/S] [/T] [/?]" & vbLF & _
	 "	/H	-	Hostname, like in Nagios" & vbLF & _
	 "	/S	-	Servicename, like in Nagios" & vbLF & _
	 "	/T	-	Downtime in minutes" & vbLF & _
	 "	/D	-	Debug" & vbLF & _
	 "	/?	-	This message"
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

