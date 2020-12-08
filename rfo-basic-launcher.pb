
#EXE      = "RFO-BASIC! Launcher"
#VER      = "v0.7"

#PORT     = 4349
#Debug    = 0

Global TempPath.s

;--------------------------------------------------------------------------------
Macro EXITFUNCTION
    RUN_CMD "adb kill-server"
    If Exist(GetPathPart(ProgramFilename()) + "notepad++.exe") 
        If #Debug 
            PRINT "Strike a key when ready"
            CON.WAITKEY$
        Else
            CON.CELL To i, j
            For a = 3 To 1 Step -1
                CON.CELL = i, j
                PRINT "Closing in " + TRIM$(a) + "s"
                SLEEP 1000
            Next
        EndIf
    EndIf
    EXIT FUNCTION
EndMacro
;--------------------------------------------------------------------------------

; LOCAL e, myname, buf, basFile, basFullPath, adb_host, rfopath As STRING
; LOCAL i, j, a, o, myip, ip, bip, hSocket, pNum, uwLine() As LONG
; LOCAL pz As ASCIIZ PTR
; LOCAL t0 As DOUBLE

OpenConsole()

PrintN (LSet("", 79, "-"))
PrintN (#EXE + " " + #VER)

TempPath = GetEnvironmentVariable("TEMP") + "\"

If Not Exist(GetPathPart(ProgramFilename()) + "adb.exe") Or 
   Not Exist(GetPathPart(ProgramFilename()) + "AdbWinApi.dll") Or
   Not Exist(GetPathPart(ProgramFilename()) + "AdbWinUsbApi.dll") 
    PRINT "Fatal error: ADB not present in installation folder"
    FUNCTION = -1
    EXITFUNCTION
EndIf

MakeSureTempToolExist ("adb.exe")
MakeSureTempToolExist ("AdbWinApi.dll")
MakeSureTempToolExist ("AdbWinUsbApi.dll")

If COMMAND$ = "" 
    PRINT "No argument specified"
    FUNCTION = 0
    EXITFUNCTION
Else
    basFullPath = TRIM$(COMMAND$, $DQ)
    basFile     = FName(basFullPath)
    If #Debug 
        PRINT "basFullPath = " + $DQ + basFullPath + $DQ
        PRINT "basFile     = " + $DQ + basFile + $DQ
    EndIf
EndIf

If Not Exist(basFullPath) 
    PRINT "File does not exist: " + basFullPath
    FUNCTION = 0
    EXITFUNCTION
EndIf

; Autosave the .bas file when BASIC! Launcher is called from editor
LOCAL zCaption As ASCIIZ * %MAX_PATH
GetWindowText(GetForegroundWindow, zCaption, SizeOf(zCaption)) ; Get caption of current dialog with focus
If RIGHT$(zCaption, 5) = "- Sc1"  ; launched from SciTE
    SendKeys "^s"     ; Issue Ctrl+S (save file)
    SLEEP 250         ; Let enough time for SciTE to save file before continuing
Else
    SLEEP 250         ; Wait that BASIC! Launcher console appears
    SendKeys "%{TAB}" ; Issue Alt+Tab to switch to previous (calling) dialog
    SLEEP 250         ; Let enough time for Windows to treat the Alt+Tab
    GetWindowText(GetForegroundWindow, zCaption, SizeOf(zCaption)) ; Get caption of dialog with focus
    If INSTR(zCaption, "Notepad++") > 0  ; launched from Notepad++
        SendKeys "^s" ; Issue Ctrl+S (save file)
        SLEEP 250     ; Let enough time for Notepad++ to save file before continuing
    EndIf
    SendKeys "%{TAB}" ; Issue ALT-TAB to go back to BASIC! Launcher console
EndIf

;################################################################################

VIA_WIFI:

; Get TCP/IP info about this PC
HOST NAME 0 To myname
HOST ADDR myname To myip
bip = (myip Or &HFF000000) ; broadcast IP

; Send UDP-broadcast to detect server on LAN (if any)
hSocket = FREEFILE
UDP open As #hSocket TIMEOUT 500
UDP SEND #hSocket, AT bip, #PORT, "Ping"
UDP RECV #hSocket, FROM ip, pNum, buf
UDP CLOSE #hSocket
If ERR          ; second try
    SLEEP 500
    hSocket = FREEFILE
    UDP open As #hSocket TIMEOUT 500
    UDP SEND #hSocket, AT bip, #PORT, "Ping"
    UDP RECV #hSocket, FROM ip, pNum, buf
    UDP CLOSE #hSocket
    If ERR 
        Goto VIA_USB_CABLE ; Nothing on LAN, try on USB!
    EndIf
EndIf

; Server detected - Initiate TCP transfer
TCP OPEN PORT pNum AT IP_STR(ip) As #hSocket TIMEOUT 500
TCP PRINT #hSocket, #VER        ; sending version of client (this program)
TCP_RECV   hSocket, buf         ; getting version of server (Android app)
buf = RTRIM$(buf, ANY $CRLF)
If buf <> #VER 
    PRINT "BASIC! Launcher versions don't match!"
    If #VER > buf 
        PRINT "Please install Android Launcher " + #VER
    Else
        PRINT "Please install PC Launcher " + buf
    EndIf
    FUNCTION = -2
    EXIT FUNCTION
EndIf
TCP PRINT #hSocket, myname
TCP PRINT #hSocket, basFile
SLEEP 500

i = FREEFILE
OPEN basFullPath For BINARY As #i
    GET$ #i, Lof(#i), buf
    o = Lof(#i)
CLOSE #i

t0 = TIMER
i = 1
DO
    TCP SEND #hSocket, MID$(buf, i, 1024)
    i += 1024
LOOP Until i > Len(buf) Or ISTRUE ERR
TCP CLOSE #hSocket

If ERR 
    PRINT "Error when transfering the file over LAN"
    FUNCTION = -3
Else
    t0 = TIMER - t0
    PRINT "File transfered over LAN at " + TRIM$(Int(o/(1024*t0))) + " KB/s"
    PRINT "(" + TRIM$(o) + " bytes in " + FORMAT$(t0, "#.000") + " second" + IIF$(t0 <= 1, ")", "s)")
    FUNCTION = 1
EndIf

EXITFUNCTION


; IDE Options = PureBasic 5.11 (Windows - x86)
; CursorPosition = 150
; FirstLine = 95
; Folding = -
; EnableXP