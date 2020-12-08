#COMPILE EXE = "rfo-basic-launcher.exe"
#DIM ALL
#RESOURCE ICON AICO, "icon2.ico"

$EXE      = "RFO-BASIC! Launcher"
$VER      = "v1.1"

%PORT     = 4349
%DEBUG    = 0

GLOBAL TempPath AS STRING

#INCLUDE ONCE "Win32API.inc"
#INCLUDE ONCE "rfo-basic-launcher.inc"


MACRO COL_DEF = COLOR  7, 0 ' Default
MACRO COL_ERR = COLOR 12, 0 ' Error
MACRO COL_OK  = COLOR 10, 0 ' Success

'--------------------------------------------------------------------------------
MACRO EXITFUNCTION
    IF ISFALSE WiFiOnly THEN RUN_CMD "adb kill-server"
'    IF Exist(EXE.PATH$ + "notepad++.exe") THEN
        IF %DEBUG THEN
            STDOUT "Strike a key when ready"
            CON.WAITKEY$
        ELSE
            CON.CELL TO i, j
            FOR a = 3 TO 1 STEP -1
                CON.CELL = i, j
                STDOUT "Closing in " + TRIM$(a) + "s"
                SLEEP 1000
            NEXT
        END IF
'    END IF
    EXIT FUNCTION
END MACRO
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION Bps(octets AS LONG, ellapsed AS DOUBLE) AS STRING
    LOCAL s AS LONG
    s = octets / ellapsed ' raw speed
    IF s >= 1024^4 THEN
        FUNCTION = TRIM$(INT(s / 1024^4)) + " TB/s."
    ELSEIF s >= 1024^3 THEN
        FUNCTION = TRIM$(INT(s / 1024^3)) + " GB/s."
    ELSEIF s >= 1024^2 THEN
        FUNCTION = TRIM$(INT(s / 1024^2)) + " MB/s."
    ELSEIF s >= 1024 THEN
        FUNCTION = TRIM$(INT(s / 1024)) + " KB/s."
    ELSE
        FUNCTION = TRIM$(INT(s)) + " B/s."
    END IF
END FUNCTION
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION PBMAIN () AS LONG
    LOCAL CMD, e, myname, buf, basFile, basFullPath, adb_host, rfopath AS STRING
    LOCAL WiFiOnly, i, j, a, o, myip, ip, bip, hSocket, pNum, uwLine() AS LONG
    LOCAL pz AS ASCIIZ PTR
    LOCAL q, t0, t1 AS QUAD


    STDOUT STRING$(79, "-")
    STDOUT $EXE + $SPC + $VER

    CMD = COMMAND$
    TempPath  = ENVIRON$("TEMP") + "\"

    IF NOT Exist(EXE.PATH$ + "adb.exe") _
    OR NOT Exist(EXE.PATH$ + "AdbWinApi.dll") _
    OR NOT Exist(EXE.PATH$ + "AdbWinUsbApi.dll") THEN
        STDOUT "No adb tool detected >> WiFi-only mode"
        WiFiOnly = 1                                    ' forces wifi only (no ADB needed/used)
    ELSE
        STDOUT "Adb tool detected"
        MakeSureTempToolExist ("adb.exe")
        MakeSureTempToolExist ("AdbWinApi.dll")
        MakeSureTempToolExist ("AdbWinUsbApi.dll")
        WiFiOnly = 0
    END IF

    IF CMD = "" THEN
        a = FREEFILE
        OPEN RTRIM$(ENVIRON$("TEMP"), "\") + "\rfo-basic-launcher.txt" FOR OUTPUT AS #a
        PRINT #a, "rfo-basic-launcher readme"
        PRINT #a, "========================="
        PRINT #a, ""
        PRINT #a, "Usage:"
        PRINT #a, "------"
        PRINT #a, ""
        PRINT #a, "If you chose to install the Notepad++ shortcut, hit Shift+F5 when editing"
        PRINT #a, "your .bas program in Notepad++ and it will be sent to your Android device."
        PRINT #a, ""
        PRINT #a, "If you use another editor, you can register a shortcut to launch "
        PRINT #a, $DQ + EXE.FULL$ + $DQ
        PRINT #a, "followed by the editor code for the current file being edited."
        PRINT #a, "Read your editor help in order to write the proper command line."
        PRINT #a, ""
        PRINT #a, "In any other case, you can drag and drop your .bas on this executable"
        PRINT #a, "or its desktop shortcut to have it transfered to your Android device."
        PRINT #a, ""
        PRINT #a, "1. WiFi mode: (recommended)"
        PRINT #a, "-------------"
        PRINT #a, ""
        PRINT #a, "- Make sure that you have RFO BASIC! installed on your Android device:"
        PRINT #a, "https://play.google.com/store/apps/details?id=com.rfo.Basic"
        PRINT #a, ""
        PRINT #a, "- Install the BASIC! Launcher (WiFi) app on your Android device:"
        PRINT #a, "https://play.google.com/store/apps/details?id=com.rfo.BASICLauncher"
        PRINT #a, ""
        PRINT #a, "- Computer and Android device need to be on the same LAN so they"
        PRINT #a, "  can autodetect each other (typically connected to the same box)"
        PRINT #a, ""
        PRINT #a, "2. USB-debugging mode:"
        PRINT #a, "----------------------"
        PRINT #a, ""
        PRINT #a, "It is also possible to transfer the file by cable between your computer"
        PRINT #a, "and the Android device. For this, you need to enable the USB-debugging"
        PRINT #a, "option on your device and have the device correctly detected by your"
        PRINT #a, "computer. This mode is harder to set up and we do not recommend it."
        PRINT #a, ""
        CLOSE #a
        ShellExecute 0, "open", RTRIM$(ENVIRON$("TEMP"), "\") + "\rfo-basic-launcher.txt" + $NUL, "", "", %SW_SHOW
        FUNCTION = 0
        EXIT FUNCTION
'        STDOUT "Usage: rfo-basic-launcher.exe my_prog.bas"
'        FUNCTION = 0
'        EXITFUNCTION
    ELSE
        basFullPath = TRIM$(TRIM$(CMD), $DQ)
        basFile     = FName(basFullPath)
        IF %DEBUG THEN
            STDOUT "basFullPath = " + $DQ + basFullPath + $DQ
            STDOUT "basFile     = " + $DQ + basFile + $DQ
        ELSE
            STDOUT "Transmitting " + $DQ + basFile + $DQ + " ..."
        END IF
    END IF

    IF NOT Exist(basFullPath) THEN
        COL_ERR
        STDOUT "(0) File does not exist: " + basFullPath
        COL_DEF
        FUNCTION = 0
        EXITFUNCTION
    END IF

'################################################################################

    VIA_WIFI:

    ' Get TCP/IP info about this PC
    HOST NAME 0 TO myname
    HOST ADDR myname TO myip
    bip = (myip OR &HFF000000) ' broadcast IP

    ' Send UDP-broadcast to detect server on LAN (if any)
    hSocket = FREEFILE
    UDP open AS #hSocket TIMEOUT 500
    UDP SEND #hSocket, AT bip, %PORT, "Ping"
    UDP RECV #hSocket, FROM ip, pNum, buf
    UDP CLOSE #hSocket
    IF ERR THEN         ' second try
        SLEEP 500
        hSocket = FREEFILE
        UDP open AS #hSocket TIMEOUT 500
        UDP SEND #hSocket, AT bip, %PORT, "Ping"
        UDP RECV #hSocket, FROM ip, pNum, buf
        UDP CLOSE #hSocket
        IF ERR THEN
            IF ISFALSE WiFiOnly THEN GOTO VIA_USB_CABLE ' Nothing on LAN, try on USB!
            IF ISTRUE  WiFiOnly THEN
                COL_ERR
                STDOUT "(-1) No Android Launcher detected on LAN"
                COL_DEF
                FUNCTION = -1
                EXITFUNCTION
            END IF
        END IF
    END IF

    ' Server detected - Initiate TCP transfer
    TCP OPEN PORT pNum AT IP_STR(ip) AS #hSocket TIMEOUT 500
    TCP PRINT #hSocket, $VER        ' sending version of client (this program)
    TCP_RECV   hSocket, buf         ' getting version of server (Android app)
    buf = RTRIM$(buf, ANY $CRLF)
    IF buf <> $VER THEN
        COL_ERR
        STDOUT "(-2) BASIC! Launcher versions do not match!"
        IF $VER > buf THEN
            STDOUT "     Please install Android Launcher " + $VER
        ELSE
            STDOUT "     Please install PC Launcher " + buf
        END IF
        COL_DEF
        FUNCTION = -2
        EXITFUNCTION
    END IF
    TCP PRINT #hSocket, myname
    TCP PRINT #hSocket, basFile
    SLEEP 500

    i = FREEFILE
    OPEN basFullPath FOR BINARY AS #i
        GET$ #i, LOF(#i), buf
        o = LOF(#i)
    CLOSE #i

    QueryPerformanceFrequency q    'clock frequency
    QueryPerformanceCounter   t0
    i = 1
    DO
        TCP SEND #hSocket, MID$(buf, i, 1024)
        i += 1024
    LOOP UNTIL i > LEN(buf) OR ISTRUE ERR
    TCP CLOSE #hSocket

    IF ERR THEN
        COL_ERR
        STDOUT "(-3) Error when transfering the file over LAN"
        COL_DEF
        FUNCTION = -3
    ELSE
        QueryPerformanceCounter   t1
        t0 = (t1 - t0) *1000 / q    ' time ellapsed in ms
        COL_OK
        STDOUT "File transfered over LAN at " + Bps(o, t0 / 1000)
        STDOUT "(" + TRIM$(o) + " bytes in " + TRIM$(t0) + " ms)"
        COL_DEF
        FUNCTION = 1
    END IF

    EXITFUNCTION

'################################################################################

    VIA_USB_CABLE:

    ENVIRON "PATH=" + EXE.PATH$
    RUN_CMD "adb kill-server" : SLEEP 500
    RUN_CMD "adb devices" : SLEEP 500
    buf = DUMP_CMD("adb devices")
    IF buf = "" THEN
        SLEEP 500
        buf = DUMP_CMD("adb devices")
    END IF
    a = TALLY(buf, $CRLF)
    IF a < 1 THEN            ' No android device connected
        COL_ERR
        STDOUT "(-1) No Android Launcher detected on LAN &"
        STDOUT "     No device found in USB debugging mode"
        COL_DEF
        FUNCTION = -1
        EXITFUNCTION
    END IF

    adb_host = PARSE$(PARSE$(buf, $CRLF, 2), $TAB, 1)
    IF %DEBUG THEN STDOUT "adb_host = " + adb_host

    rfopath = "/mnt/sdcard/"
    a = LookForBASICinRfopath(adb_host, rfopath)

    IF a = -1 THEN          ' Device offline
        COL_ERR
        STDOUT "(-1) Offline USB device " + adb_host
        COL_DEF
        FUNCTION = -1
        EXITFUNCTION
    END IF

    IF a = 0 THEN
        rfopath = "/sdcard/"
        a = LookForBASICinRfopath(adb_host, rfopath)
    END IF

    IF a = 0 THEN
        ' Continue to look in a different path...
        'a = LookForBASICinRfopath(adb_host, "/differentPath/")
    END IF

    IF a = 0 THEN
        COL_ERR
        STDOUT "(-4) RFO-BASIC! was not found on Android USB host " + adb_host
        COL_DEF
        FUNCTION = -4
        EXITFUNCTION
    END IF

    e = DUMP_CMD("adb -s " + adb_host + " shell ls " + rfopath + "rfo-basic/source/" + basFile)
    IF INSTR(e, basFile) <> 0 THEN                                   ' backup existing file!
        e = DUMP_CMD("adb -s " + adb_host + " shell mv " + rfopath + "rfo-basic/source/" + basFile _
                   + $SPC + rfopath + "rfo-basic/source/" + LEFT$(basFile, -3) + "bkp.bas")
        COL_OK
        STDOUT "Remote file found and backed up"
        COL_DEF
    END IF

    e = DUMP_CMD("adb -s " + adb_host + " push " _
               + $DQ + basFullPath + $DQ _
               + $SPC + rfopath + "rfo-basic/source/" + basFile)
    IF INSTR(e, "error") <> 0 THEN
        COL_ERR
        STDOUT "(-3) Error when transfering the file via USB to " + adb_host
        COL_DEF
        FUNCTION = -3
    ELSE
        COL_OK
        STDOUT "File transfered over USB at " + LEFT$(e, INSTR(e, "("))
        STDOUT RTRIM$(MID$(e, INSTR(e, "(")), $CRLF)
        COL_DEF
        e = DUMP_CMD("adb shell am force-stop com.rfo.basic")
        e = DUMP_CMD("adb -s " + adb_host + " shell am start" _
                   + " -n com.rfo.basic/com.rfo.basic.Basic"  _      ' component
                   + " -d " + rfopath + "rfo-basic/source/" + basFile)  ' uri
        FUNCTION = 1
    END IF

    EXITFUNCTION

END FUNCTION
'--------------------------------------------------------------------------------
