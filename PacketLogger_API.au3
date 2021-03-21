#include <Array.au3>

Dim $PacketLogger_OpenSockets[0]
Dim $PacketLogger_Started = False
Dim $PacketLogger_DisconnectedCallback = -1

Const $PacketLogger_Recv = 0
Const $PacketLogger_Send = 1

Func PacketLogger_TitleMode($Option = -1)
	If $Option = -1 Then
		Return Opt("WinTitleMatchMode")
	Else
		Return Opt("WinTitleMatchMode", $Option)
	EndIf
EndFunc

Func PacketLogger_GetPorts()
	$OldTitleMode = PacketLogger_TitleMode()
	PacketLogger_TitleMode(2)

	$Titles = WinList("[BladeTiger12] - NosTale PacketLogger - Server: 127.0.0.1")
	PacketLogger_TitleMode($OldTitleMode)

	Dim $Ports[0]

	If $Titles[0][0] > 0 Then
		For $i = 1 To $Titles[0][0]
			$Port = StringRegExp($Titles[$i][0], "127\.0\.0\.1\:(\d+)", 3)
			If IsArray($Port) Then
				_ArrayAdd($Ports, $Port[0])
			EndIf
		Next
	EndIf

	Return $Ports
EndFunc


Func PacketLogger_Startup()
	TCPStartup()
	$PacketLogger_Started = True
EndFunc

Func PacketLogger_Shutdown()
	TCPShutdown()
	$PacketLogger_Started = False
EndFunc

Func PacketLogger_ConnectTo($Port, $Ip = "127.0.0.1")
	If Not $PacketLogger_Started Then
		MsgBox(16, "PacketLogger", "First of all you have to call 'PacketLogger_Startup()'!")
		Return False
	EndIf

	$Socket = TCPConnect($Ip, $Port)
	If $Socket < 0 Then
		Return False
	EndIf

	_ArrayAdd($PacketLogger_OpenSockets, $Socket)

	Return $Socket
EndFunc

;Func PacketLogger_SetDisconnectedCallback($Callback)
;	$PacketLogger_DisconnectedCallback = $Callback
;EndFunc

Func PacketLogger_Close($Socket)
	$Index = _ArraySearch($PacketLogger_OpenSockets, $Socket)
	If $Index <> -1 Then
		_ArrayDelete($PacketLogger_OpenSockets, $Index)
	EndIf
EndFunc


Func PacketLogger_Handle($Socket, $ReceiveCallback, $MaxReceiveBytes = 8192)
	$ReceivedPacket = TCPRecv($Socket, $MaxReceiveBytes)
	If @extended = 1 Then ; Return 1 to sleep if no data were received
		Return 1
	elseIf @error <> 0 Then ;Return 2 so the "thread" for connected client can end
		Return 2
	Endif
	;If @error <> 0 Then
	;	MsgBox(0,"",@error)
	;	If IsFunc($PacketLogger_DisconnectedCallback) Then
	;		$PacketLogger_DisconnectedCallback($Socket)
	;	EndIf
	;Else
	If $ReceivedPacket <> "" Then
		$PacketsSplitted = StringSplit($ReceivedPacket, @CR, 2)
		For $i = 0 To UBound($PacketsSplitted) - 1
			If $PacketsSplitted[$i] = "" Then ContinueLoop

			$PacketSplitted = StringSplit($PacketsSplitted[$i], " ", 2)
			If UBound($PacketSplitted) > 1 Then
				$PacketType = $PacketSplitted[0]
				_ArrayDelete($PacketSplitted, 0)

				If IsFunc($ReceiveCallback) Then
					$ReceiveCallback($PacketType, $PacketSplitted, $PacketsSplitted[$i])
				EndIf
			EndIf
		Next
	EndIf
EndFunc


Func PacketLogger_SendToSocket($Socket, $Type, $Packet)
	If IsArray($Packet) Then
		For $i = 0 To UBound($Packet) - 1
			PacketLogger_SendToSocket($Socket, $Type, $Packet[$i])
		Next
	Else
		TCPSend($Socket, $Type & " " & $Packet & @CR)
	EndIf
EndFunc

Func PacketLogger_RecvPacket($Socket, $Packet)
	PacketLogger_SendToSocket($Socket, 0, $Packet)
EndFunc

Func PacketLogger_SendPacket($Socket, $Packet)
	PacketLogger_SendToSocket($Socket, 1, $Packet)
EndFunc


#cs Example:
PacketLogger_Startup()
$Ports = PacketLogger_GetPorts()
$Socket = PacketLogger_ConnectTo($Ports[0])

While True
	Sleep(10)
	PacketLogger_Handle($Socket, IncomingPacket)
WEnd

Func IncomingPacket($Type, $PacketSplitted, $FullPacket)
	; MsgBox(0,"", "Type: " & $Type & @CRLF & "PacketName: " & $PacketSplitted[0] & @CRLF & "Packet: " & $FullPacket)
	PacketLogger_RecvPacket($Socket, "gold 9999999 0")
EndFunc

PacketLogger_Close($Socket)
PacketLogger_Shutdown()
#ce
