
%ADD_BUF  = 100

'------------------------------------------------------------------------------
FUNCTION Exist(BYVAL fileOrFolder AS STRING) AS LONG
    LOCAL Dummy&
    Dummy& = GETATTR(fileOrFolder)
    FUNCTION = (ERRCLEAR = 0)
END FUNCTION
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
FUNCTION Execute (Program AS STRING, Arguments AS STRING, nShow AS LONG) AS DWORD
'   Advanced Shell. Example of how to use :
'   Local PID As Dword
'   PID = Execute( Environ$("COMSPEC"), "/C dir " & $Dq & folderName & $Dq & " /ad /s /b > tmp.txt", 0 )
'   WaitForSingleObject PID, %INFINITE    ' activate this line if you want synchronous shell
'   CloseHandle PID
    LOCAL ShellInfo AS SHELLEXECUTEINFO
    ShellInfo.cbSize = SIZEOF(ShellInfo)
    ShellInfo.fMask = %SEE_MASK_FLAG_NO_UI OR %SEE_MASK_NOCLOSEPROCESS
    ShellInfo.lpFile = STRPTR(Program)
    ShellInfo.lpParameters = STRPTR(Arguments)
    ShellInfo.nShow = nShow
    IF ShellExecuteEx(ShellInfo) THEN FUNCTION = ShellInfo.hProcess
END FUNCTION
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
SUB WaitForThread(BYREF TID AS DWORD) ' deadline in second
    LOCAL lRes AS LONG
    DO ' Wait for the thread to finish
        SLEEP 0
        lRes = WaitForSingleObject(TID, 100)
    LOOP UNTIL lRes <> %WAIT_TIMEOUT
    KillThread TID
END SUB
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
SUB KillThread(BYREF TID AS DWORD)
    LOCAL lRes AS LONG
    THREAD SUSPEND TID TO lRes
    CloseHandle TID
    THREAD CLOSE TID TO lRes
    TID = 0
END SUB
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
MACRO MakeSureTempToolExist(tool) = KILL TempPath + tool : FILECOPY EXE.PATH$ + tool, TempPath + tool
'------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION IP_STR(ip AS LONG) AS STRING
    LOCAL p AS BYTE PTR
    p = VARPTR(ip)
    FUNCTION = USING$("#_.#_.#_.#", @p, @p[1], @p[2], @p[3])
END FUNCTION
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
'FUNCTION IP_LNG(ip AS STRING) AS LONG
'    FUNCTION = 256^3 * VAL(PARSE$(ip, ".", 4)) _
'             + 256^2 * VAL(PARSE$(ip, ".", 3)) _
'             + 256^1 * VAL(PARSE$(ip, ".", 2)) _
'             + 256^0 * VAL(PARSE$(ip, ".", 1))
'END FUNCTION
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION FName(BYVAL strFileName AS STRING) AS STRING
  LOCAL sfn AS STRING
  sfn =  strFileName
  REPLACE "/" WITH "\" IN sfn
  FUNCTION = MID$(sfn, INSTR(-1, sfn, "\") + 1)
END FUNCTION
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION LookForBASICinRfopath(adbhost AS STRING, rfopath AS STRING) AS LONG
    ' Returns -1 if device offline
    ' Returns +1 if RFO-BASIC! found in requested folder
    ' Returns  0 otherwise
    LOCAL e AS STRING
    STDOUT "Looking for " + rfopath + "rfo-basic"
    STDOUT "on device " + adbhost
    e = DUMP_CMD("adb -s " + adbhost + " shell ls " + rfopath)
    IF INSTR(e, "offline") > 0 THEN FUNCTION = -1
    IF INSTR(e, "rfo-basic") > 0 THEN FUNCTION = 1
END FUNCTION
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
SUB TCP_RECV(sktNum AS LONG, buf AS STRING)
    LOCAL e AS STRING
    RESET buf
    DO
        TCP RECV #sktNum, 1024, e
        buf += e
    LOOP WHILE LEN(e) AND ISFALSE ERR
END SUB
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION RUN_CMD(BYVAL cmdLine AS STRING, OPTIONAL BYVAL folder AS STRING) AS LONG
    LOCAL rep AS STRING
    LOCAL ff AS LONG
    LOCAL PID AS DWORD

    IF folder <> "" THEN rep = folder ELSE rep = ENVIRON$("TEMP") + "\"
    rep = RTRIM$(rep, "\") + "\"

    IF %DEBUG THEN
        STDOUT "RUN_CMD: " + cmdLine
        STDOUT "in " + rep
    END IF

    ff = FREEFILE
    OPEN rep + "temp.bat" FOR OUTPUT AS #ff
        PRINT #ff, "@echo off"
        PRINT #ff, LEFT$(rep, 2)
        PRINT #ff, "cd " + $DQ + rep + $DQ
        PRINT #ff, cmdLine
    CLOSE

    PID = Execute(rep + "temp.bat", "", 0)
    WaitForThread PID ' Wait for the script to finish

    KILL rep + "temp.bat"
END FUNCTION
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION DUMP_CMD(BYVAL cmdLine AS STRING, OPTIONAL BYVAL folder AS STRING) AS STRING
    LOCAL rep, e AS STRING
    LOCAL ff AS LONG
    LOCAL PID AS DWORD

    IF folder <> "" THEN rep = folder ELSE rep = ENVIRON$("TEMP") + "\"
    rep = RTRIM$(rep, "\") + "\"

    IF %DEBUG THEN
        STDOUT "DUMP_CMD: " + cmdLine
        STDOUT "in " + rep
    END IF

    ff = FREEFILE
    OPEN rep + "temp.bat" FOR OUTPUT AS #ff
        PRINT #ff, "@echo off"
        PRINT #ff, LEFT$(rep, 2)
        PRINT #ff, "cd " + $DQ + rep + $DQ
        PRINT #ff, cmdLine + " > dump.txt 2>&1"
    CLOSE

    PID = Execute(rep + "temp.bat", "", 0)
    WaitForThread PID ' Wait for the script to finish

    KILL rep + "temp.bat"

    ff = FREEFILE
    OPEN rep + "dump.txt" FOR BINARY AS #ff
        GET$ #ff, LOF(#ff), e
    CLOSE
    e = RTRIM$(e, ANY $CRLF)

    KILL rep + "dump.txt"
    FUNCTION = e

    IF %DEBUG THEN
        REPLACE $CRLF WITH "[CRLF]" + $CRLF IN e
        STDOUT "returned: " + $DQ + e + $DQ
    END IF
END FUNCTION
'--------------------------------------------------------------------------------
