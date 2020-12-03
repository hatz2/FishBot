#include <PacketLogger_API.au3>
#include <WinAPIConv.au3>
#include <WindowsConstants.au3>
#include <SendMessage.au3>
#include <authread.au3>
#include <Inject.au3>
#include <Array.au3>
#RequireAdmin

;~ ---------------------- Main body ----------------------------
_AuThread_StartUp()     ;Start authread
PacketLogger_StartUp()  ;Start packetlogger

$list = ProcessList("NostaleClientX.exe")   ;Get windows PID
$hwndlist = WinList("NosTale")              ;Get windows HWND

;Inject the packetloggers
For $i = 1 to $list[0][0]
    Inject($list[$i][1], @ScriptDir & "\PacketLogger.dll")
Next

Sleep(3000)

;Get packetlogger ports
$Ports = PacketLogger_GetPorts()

;Start bot for every client with the correct port
For $i = 0 to UBound($Ports) - 1
    _AuThread_StartThread("Bot", $Ports[$i])
Next

Sleep(1000)

;Send key 1 so the bots can get the user ID + start fishing
For $i = 1 to $hwndlist[0][0]
    _SendMessage($hwndlist[$i][1], $WM_KEYDOWN, 0x31, 1)
    _SendMessage($hwndlist[$i][1], $WM_KEYUP, 0x31, 0)
Next

;Loop till exit
While True
    Sleep(100)
WEnd

;Stop packetlogger
PacketLogger_Shutdown()

;~ ----------------------Functions ----------------------

;~ Main bot function
Func Bot()
    Opt("TrayIconHide", 1)
    PacketLogger_Startup()

    Global $Socket = 0
    Global $userID = 0
    Global $foundPort = False
    Global $foundID = False
    Global $fishing = True

    ;Wait to get the port
    While Not $foundPort
        Sleep(100)
        $msg = _AuThread_GetMessage()

        if $msg Then
            $Socket = PacketLogger_ConnectTo($msg)
            $foundPort = True
        EndIf
    WEnd

    ;Main bot loop
    While $fishing
        Sleep(10)
        PacketLogger_Handle($Socket, IncomingPacket)
    WEnd

    PacketLogger_Close($Socket)
    PacketLogger_Shutdown()
EndFunc

;~ Function that gets a packet
Func IncomingPacket($Type, $PacketSplitted, $FullPacket)
    HandleFish($PacketSplitted)
    If Not $foundID Then ;If not userID check for skill use
        HandleUserID($PacketSplitted)
    EndIf
EndFunc

;~ Function that handle fish related packets
Func HandleFish($PacketSplitted)
    $opcode = $PacketSplitted[0]
    
    if $opcode = "guri" Then
        if $PacketSplitted[1] = 6 And $PacketSplitted[2] = 1 And $PacketSplitted[3] = $userID And ($PacketSplitted[4] = 30 Or $PacketSplitted[4] = 31) Then
            Sleep(1000)
            PacketLogger_SendPacket($Socket, "u_s 2 1 " & $userID)
        EndIf

        if $PacketSplitted[1] = 6 And $PacketSplitted[2] = 1 And $PacketSplitted[3] = $userID And $PacketSplitted[4] = 0 Then
            Sleep(1000)
            PacketLogger_SendPacket($Socket, "u_s 1 1 " & $userID)
        EndIf
    EndIf
EndFunc

;~ Function that handle skill packet to get user ID
Func HandleUserID($PacketSplitted)
    $opcode = $PacketSplitted[0]

    if $opcode = "u_s" Then
        $userID = $PacketSplitted[3]
        $foundID = True
    EndIf
EndFunc
