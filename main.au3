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

    Global $spLevel = 1
    Global $Socket = 0
    Global $userID = 0
    Global $foundPort = False
    Global $foundID = False
    Global $fishing = True
    Global $baitSkillIsOn = True
    Global $expSkillIsOn = True
    Global $fishLineSkillIsOn = True
    Global $proBaitSkillIsOn = True
    Global $bait = True

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
    $opcode  = $PacketSplitted[0]

    If $opcode = "sayi" Then
        HandleSayi($PacketSplitted)
    ElseIf $opcode = "spk" Then
        HandleSpk($PacketSplitted)
    ElseIf $opcode = "in" Then
        HandleIn($PacketSplitted)
    ElseIf $opcode = "say" Then
        HandleSay($PacketSplitted)
    ElseIf $opcode = "sr" Then
        HandleSkillCD($PacketSplitted)
    ElseIf $opcode = "lev" Then
        HandleLevel($PacketSplitted)
    ElseIf $opcode = "guri" Then
        HandleFish($PacketSplitted)
    ElseIf $opcode = "u_s" And Not $foundID Then
        HandleUserID($PacketSplitted)
    EndIf
EndFunc

;~ Function that handle fish animation related packets
Func HandleFish($PacketSplitted)
    If UBound($PacketSplitted) > 4 Then
        ;If character fished something
        if $PacketSplitted[1] = 6 And $PacketSplitted[2] = 1 And $PacketSplitted[3] = $userID And ($PacketSplitted[4] = 30 Or $PacketSplitted[4] = 31) Then
            Sleep(1000)
            PacketLogger_SendPacket($Socket, "u_s 2 1 " & $userID)
        EndIf

        ;If character finished doing fishing animation
        if $PacketSplitted[1] = 6 And $PacketSplitted[2] = 1 And $PacketSplitted[3] = $userID And $PacketSplitted[4] = 0 And $bait Then
            Sleep(1000)
            CheckSkills()
            Fish()
        EndIf
    EndIf
EndFunc

;~ Function that handle skill packet to get user ID
Func HandleUserID($PacketSplitted)
    If UBound($PacketSplitted) > 3 Then
        $userID = $PacketSplitted[3]
        $foundID = True
    EndIf
EndFunc

;~ Function that handle sp level
Func HandleLevel($PacketSplitted)
    If UBound($PacketSplitted) > 3 Then
        If $PacketSplitted[3] <> $spLevel Then ;If sp level up
            $baitSkillIsOn = True
            $expSkillIsOn = True
            $fishLineSkillIsOn = True
            $proBaitSkillIsOn = True

            If Not $bait and $spLevel >= 3 Then
                CheckSkills()
                Fish()
            EndIf
        EndIf

        $spLevel = $PacketSplitted[3]
    EndIf
EndFunc

;~ Function that handle skill cd
Func HandleSkillCD($PacketSplitted)
    If UBound($PacketSplitted) > 1 Then
        If $PacketSplitted[1] = 8 Then
            $expSkillIsOn = True
        EndIf

        If $PacketSplitted[1] = 9 Then
            $fishLineSkillIsOn = True
        EndIf

        If $PacketSplitted[1] = 10 Then
            $proBaitSkillIsOn = True
        EndIf

        if $PacketSplitted[1] = 3 Then
            $baitSkillIsOn = True

            ;If there's no more bait use skill if is not on CD
            If Not $bait And $spLevel >= 3 Then 
                CheckSkills()
                Fish()
            EndIf
        EndIf
    EndIf
EndFunc

;~ Function that handles sayi packet
Func HandleSayi($PacketSplitted)
    If UBound($PacketSplitted) > 4 Then
        ;If there's no more bait
        if $PacketSplitted[1] = 1 And $PacketSplitted[2] = $userID And $PacketSplitted[4] = 2497 Then 
            $bait = False

            If $baitSkillIsOn Then
                CheckSkills()
                Fish()
            EndIf
        EndIf
    EndIf
EndFunc

;~ Function that handles say packets
Func HandleSay($PacketSplitted)
    If UBound($PacketSplitted) > 5 Then
        If $PacketSplitted[1] = 1 And $PacketSplitted[2] = $userID And $PacketSplitted[3] = 10 And $PacketSplitted[4] = "fish" And $PacketSplitted[5] = "data" Then
            Sleep(1000)
            CheckSkills()
            Fish()
        EndIf
    EndIf
EndFunc

;~ Function that handles in packets
Func HandleIn($PacketSplitted)
    If UBound($PacketSplitted) > 8 Then
        ;If user has GM Authority
        If $PacketSplitted[8] = 2 Then
            For $i = 0 to 5
                PacketLogger_SendPacket($Socket, "pulse 0 0")
                Sleep(1)
            Next
        EndIf
    EndIf
EndFunc

;~ Function that handles spk packets
Func HandleSpk($PacketSplitted)
    If UBound($PacketSplitted) > 3 Then
        ;If the message has GM purple color
        If $PacketSplitted[3] = 15 Then
            For $i = 1 to 10
                Beep(800, 200)
                Sleep(50)
            Next
        EndIf
    EndIf
EndFunc

;~ Function that check if skills are up
Func CheckSkills()
    ;Check if fish line skill is up
    if $spLevel >= 25 And $fishLineSkillIsOn Then
        $fishLineSkillIsOn = False
        PacketLogger_SendPacket($Socket, "u_s 9 1 " & $userID)
        Sleep(2000)
    EndIf

    ;Check if exp skill is up
    If $spLevel >= 25 And $expSkillIsOn Then
        $expSkillIsOn = False
        PacketLogger_SendPacket($Socket, "u_s 8 1 " & $userID)
        Sleep(2000)
    EndIf

    ;Check if bait skill is up
    If $spLevel >= 3 And $baitSkillIsOn Then
        $baitSkillIsOn = False
        PacketLogger_SendPacket($Socket, "u_s 3 1 " & $userID)
        Sleep(2000)
    EndIf
EndFunc

;~ Function to start fishing
Func Fish()
    ;Check if pro bait skill is up
    If $spLevel >= 45 And $proBaitSkillIsOn Then
        $proBaitSkillIsOn = False
        PacketLogger_SendPacket($Socket, "u_s 10 1 " & $userID)
    Else
        PacketLogger_SendPacket($Socket, "u_s 1 1 " & $userID)
    EndIf
EndFunc