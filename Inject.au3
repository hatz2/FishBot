;######################################################
;~>          <~;
;~>  AutoIt Version: 3.3.6.1      <~;
;~>  Author:        Shaggi    <~;
;~>          <~;
;~>  Script Function:      <~;
;~>  Inject custom DLLs into a selected Process <~;
;~>          <~;
;~>  Credits:        <~;
;~>  Rain and asp for openSecureProcess   <~;
;~>          <~;
;~>  Darawk for Inject() function in C++   <~;
;~>          <~;
;######################################################
;##################################
;~> Directories
;##################################
#AutoIt3Wrapper_UseX64=n
;##################################
;~> Includes
;##################################
#include <WinApi.au3>
#include <Memory.au3>
#include <GuiConstants.au3>
#include <Windowsconstants.au3>
#include <Array.au3>
#include <Constants.au3>
;##################################
;~> General Variables
;##################################
Global  $Version     = "1.0"
Global  $DLL_Array_List[20][2]
        $DLL_Array_List[0][0]  = 0
Global  $searchparameters
;##################################
;~> General Windows variables
;##################################
Global $Create_Thread_Access      = BitOR($PROCESS_CREATE_THREAD, $PROCESS_QUERY_INFORMATION, $PROCESS_VM_OPERATION, $PROCESS_VM_WRITE, $PROCESS_VM_READ)
Global $MAX_PATH         = 0x00000104
Global $SE_KERNEL_OBJECT       = 6
Global $DACL_SECURITY_INFORMATION    = 0x00000004
Global $ERROR_SUCCESS       = 0
;Global $WRITE_DAC        = 0x00040000
Global $UNPROTECTED_DACL_SECURITY_INFORMATION  = 0x20000000
;Global $READ_CONTROL        = 0x00020000

Func Inject($Pid, Const $DLL_NAME)
    Local $Proc
    Local $hLib
    Local $RemoteString
    Local $LoadLibAddy
    Local $iWritten
    Local $DLL_BUFFER
    Local $thread
    ;##################################
    If Not ProcessExists($Pid) Then
        print("Invalid process ID: " & $Pid, True, 48)
        Return
    EndIf
    ;##################################
    $Proc = _WinAPI_OpenProcess($CREATE_THREAD_ACCESS, False, $Pid, True)
    If Not $Proc Then
        print("OpenProcess() failed: " & _WinAPI_GetLastError() & @CRLF & _WinAPI_GetLastErrorMessage() & @CRLF & "Continuing with openSecureProcess()", True, 16)
        $Proc = openSecureProcess($Pid, $PROCESS_ALL_ACCESS)
        If Not $Proc Then
            print("openSecureProcess() failed: " & _WinAPI_GetLastError() & @CRLF & _WinAPI_GetLastErrorMessage(), True, 16)
            Return False
        EndIf
    EndIf
    ;##################################
    $LoadLibAddy = GetProcAddress(_WinAPI_GetModuleHandle("kernel32.dll"), "LoadLibraryA")
    If Not $LoadLibAddy Then
        print("GetProcAddress() failed: " & _WinAPI_GetLastError() & @CRLF & _WinAPI_GetLastErrorMessage(), True, 16)
        _WinAPI_CloseHandle($Proc)
        Return False
    EndIf
    ;##################################
    ;Allocate space in the process for our DLL
    ;##################################
    $RemoteString = _MemVirtualAllocEx($Proc, 0, StringLen($DLL_NAME), BitOR($MEM_RESERVE, $MEM_COMMIT), $PAGE_READWRITE)
    print($RemoteString)
    If Not $RemoteString Then
        print("_MemVirtualAllocEx() failed: " & _WinAPI_GetLastError() & @CRLF & _WinAPI_GetLastErrorMessage(), True, 16)
        _WinAPI_CloseHandle($Proc)
        Return False
    EndIf
    ;##################################
    ;Create a buffer which holds the string name
    ;##################################
    $DLL_BUFFER = DllStructCreate("char[" & BinaryLen($DLL_NAME) & "]")
    DllStructSetData($DLL_BUFFER, 1, $DLL_NAME)
    $iWritten = BinaryLen($DLL_NAME)
    ;Write the string name of our DLL in the memory allocated
    If Not _WinAPI_WriteProcessMemory($Proc, $RemoteString, DllStructGetPtr($DLL_BUFFER), BinaryLen($DLL_NAME), $iWritten) Then
        print("WriteProcessMemory() failed: " & _WinAPI_GetLastError() & @CRLF & _WinAPI_GetLastErrorMessage(), True, 16)
        _WinAPI_CloseHandle($Proc)
        Return False
    EndIf
    ;##################################
    ; Create a thread which should inject our dll,
    ; and pass the pointer which holds the DLL path
    ; as an argument to the LoadLibraryA function
    ;##################################
    $thread = CreateRemoteThread($Proc, 0, 0, $LoadLibAddy, $RemoteString, 0, 0)
    If Not $thread Then
        print("CreateRemoteThread() failed: " & _WinAPI_GetLastError() & @CRLF & _WinAPI_GetLastErrorMessage(), True, 16)
        _WinAPI_CloseHandle($Proc)
        Return False
    EndIf
    ;##################################
    ;Clean up
    ;##################################
    _WinAPI_WaitForSingleObject($thread, 0xFFFFFFFF)
    _MemVirtualFreeEx($Proc,$RemoteString, 0, $MEM_RELEASE)
    _WinAPI_CloseHandle($thread)
    _WinAPI_CloseHandle($Proc)
    _WinAPI_FreeLibrary("kernel32.dll")
    Return True
EndFunc   ;==>Inject
;##################################
;~> CreateRemoteThread()
;~> Creates a thread in another process'
;~> virtual memory space
;##################################
Func CreateRemoteThread($hProcess, $lpThreadAttributes, $dwStackSize, $lpStartAddress, $lpParameter, $dwCreationFlags, $lpThreadId)
    Local $call = DllCall("Kernel32.dll", "ptr", "CreateRemoteThread", _
            "ptr", $hProcess, _
            "ptr", $lpThreadAttributes, _
            "uint", $dwStackSize, _
            "ptr", $lpStartAddress, _
            "ptr", $lpParameter, _
            "dword", $dwCreationFlags, _
            "ptr", $lpThreadId)
    Return $call[0]
EndFunc   ;==>CreateRemoteThread
;##################################
;~> GetProcAddress()
;~> Gets a function address in a loaded DLL
;##################################
Func GetProcAddress($hModule, $lpProcName)
    Local $call = DllCall("Kernel32.dll", "ptr", "GetProcAddress", _
            "handle", $hModule, _
            "str", $lpProcName)
    Return $call[0]
EndFunc   ;==>GetProcAddress
;##################################
;~> print()
;~> Writes a message to the STDOUT-stream,
;~> and optionally opens a MessageBox
;##################################
Func print($msg = @CRLF, $msgbox = False, $id = 0)
    If $msg = "" Then Return
    ConsoleWrite($msg & @CRLF)
    If $msgbox Then
        MsgBox($id, "AutoInject " & $Version, $msg, 0)
    EndIf
EndFunc   ;==>print
;##################################
;/** openSecureProcess()
;* Opens a process. Overwrite the DACL of target process
;* as a fallback if the process has dropped rights. Doesn't
;* require the user to be logged in with system or admin
;* rights.
;*
;* Edited by Shaggi:
;* Tries with debug privilege first, then overwrites dacl,
;* and resets it back to original state.
;*
;* @author asp
;* @param wndclass Name of windowclass.
;* @param rights The process access rights you want.
;* @return 0 on failure. Otherwise handle to process.
;*/
;~ Credits to Rain for converting it to AutoIt.
;##################################
Func openSecureProcess($Pid, $Rights)
    If NOT ProcessExists($pid) Then Return False
    ; Try to open the process with the requested rights.
    $process = _WinAPI_OpenProcess($Rights, False, $Pid, True);
    If $process Then
        Return $process
    EndIf
    ;Okay, didnt work, even with debug privilege.
    ;Going to mirror our SID to target process,
    ;open a handle, and reset SID
    Local $process
    Local $dacl = DllStructCreate("ptr")
    Local $secdesc = DllStructCreate("ptr")
    Local $dacl_target = DllStructCreate("ptr")
    Local $secdesc_target = DllStructCreate("ptr")
    ; Get the DACL of this process since we know we have
    ; all rights in it. This really can't fail.
    If(getSecurityInfo(_WinAPI_GetCurrentProcess(), _
            $SE_KERNEL_OBJECT, _
            $DACL_SECURITY_INFORMATION, _
            0, _
            0, _
            DllStructGetPtr($dacl, 1), _
            0, _
            DllStructGetPtr($secdesc, 1)) <> $ERROR_SUCCESS) Then
        Return False
    EndIf
    ; Open it with WRITE_DAC || READ_CONTROL access,
    ; so that we can read and write to the DACL.
    $process = _WinAPI_OpenProcess(BitOR($WRITE_DAC, $READ_CONTROL), 0, $Pid)
    If NOT $process Then
        _WinAPI_LocalFree($secdesc)
        Return False
    EndIf
    ; Get the DACL of target process and store it,
    ; so we can reset it later
    If(getSecurityInfo($process, _
            $SE_KERNEL_OBJECT, _
            $DACL_SECURITY_INFORMATION, _
            0, _
            0, _
            DllStructGetPtr($dacl_target, 1), _
            0, _
            DllStructGetPtr($secdesc_target, 1)) <> $ERROR_SUCCESS) Then
        Return False
    EndIf
    ;Overwrite the Dacl with our own
    If(setSecurityInfo($process, _
            $SE_KERNEL_OBJECT, _
            BitOR($DACL_SECURITY_INFORMATION, $UNPROTECTED_DACL_SECURITY_INFORMATION), _
            0, _
            0, _
            DllStructGetData($dacl, 1), _
            0) <> $ERROR_SUCCESS) Then
        _WinAPI_LocalFree($secdesc)
        Return False
    EndIf
    ; The DACL is overwritten with our own DACL. We
    ; should be able to open it with the requested
    ; privileges now.
    _WinAPI_LocalFree($secdesc)
    _WinAPI_CloseHandle($process)
    $hProc = _WinAPI_OpenProcess($Rights, False, $Pid, True)
    If NOT $hProc Then
        Return False
    EndIf
    ;Assuming we got the process. Proceeding to revert the patch, and return the enabled process handle
    If(setSecurityInfo($hProc, _
            $SE_KERNEL_OBJECT, _
            BitOR($DACL_SECURITY_INFORMATION, $UNPROTECTED_DACL_SECURITY_INFORMATION), _
            0, _
            0, _
            DllStructGetData($dacl_target, 1), _
            0) <> $ERROR_SUCCESS) Then
        _WinAPI_LocalFree($secdesc_target)
        Return False
    EndIf
    _WinAPI_LocalFree($secdesc_target)
    Return $hProc
EndFunc   ;==>openSecureProcess
;##################################
;~> getSecurityInfo()
;~> Gets security information about a process
;##################################
Func getSecurityInfo($handle, $ObjectType, $SecurityInfo, $ppsidOwner, $ppsidGroup, $ppDacl, $ppSacl, $ppSecurityDescriptor)
    Local $call = DllCall("Advapi32.dll", "long", "GetSecurityInfo", _
            "ptr", $handle, _
            "int", $ObjectType, _
            "dword", $SecurityInfo, _
            "ptr", $ppsidOwner, _
            "ptr", $ppsidGroup, _
            "ptr", $ppDacl, _
            "ptr", $ppSacl, _
            "ptr", $ppSecurityDescriptor)
    Return $call[0]
EndFunc   ;==>getSecurityInfo
;##################################
;~> setSecurityInfo()
;~> Sets security information about a process
;;##################################
Func setSecurityInfo($handle, $ObjectType, $SecurityInfo, $psidOwner, $psidGroup, $pDacl, $pSacl)
    Local $call = DllCall("Advapi32.dll", "long", "SetSecurityInfo", _
            "ptr", $handle, _
            "int", $ObjectType, _
            "dword", $SecurityInfo, _
            "ptr", $psidOwner, _
            "ptr", $psidGroup, _
            "ptr", $pDacl, _
            "ptr", $pSacl)
    Return $call[0]
EndFunc   ;==>setSecurityInfo
;##################################
;~> GetFullPathName()
;~> Retrieves the full path of a filename
;##################################
Func GetFullPathName($lpFileName, $nBufferLength, $lpBuffer, $lpFilePart)
    Local $call = DllCall("Kernel32.dll", "ptr", "GetFullPathNameA", _
            "str", $lpFileName, _
            "dword", $nBufferLength, _
            "str", $lpBuffer, _
            "str", $lpFilePart)
    Return $call[0]
EndFunc   ;==>GetFullPathName
