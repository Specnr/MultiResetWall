SendLog(logLevel, logMsg) {
    timeStamp := A_TickCount
    macroLogFile := FileOpen("data/log.log", "a -rwd")
    if (!IsObject(macroLogFile)) {
        logQueue := Func("SendLog").Bind(logLevel, logMsg, timeStamp)
        SetTimer, %logQueue%, -10
        return
    }
    macroLogFile.Write(Format("[{3}] [{4}-{5}-{6} {7}:{8}:{9}] [SYS-{2}] {1}`r`n", logMsg, logLevel, timeStamp, A_YYYY, A_MM, A_DD, A_Hour, A_Min, A_Sec))
    macroLogFile.Close()
}

Shutdown(ExitReason, ExitCode) {
    if (ExitReason == "Logoff" || ExitReason == "Shutdown") {
        return
    }

    FileDelete, data/obs.txt
    DetectHiddenWindows, On
    for i, instance in instances {
        instance.KillResetManager()
    }
    return
}

GetScriptPID() {
    DetectHiddenWindows, On
    WinGet, scriptPID, PID, %A_ScriptFullPath% - AutoHotkey v
    DetectHiddenWindows, Off
    return scriptPID
}

AssignResetManagerPID(idx, rmPID) {
    SendLog(LOG_LEVEL_INFO, Format("Set instance {1} rmPID to {2}", idx, rmPID))
    instances[idx].SetRMPID(rmPID)
    ; instances[idx].SetRMPID(rmPID)
}

ConfirmRM(idx) {
    instances[idx].rmLaunched := true
}

; File safe function to increment overallAttemptsFile and dailyAttemptsFile each by 1
CountAttempt() {
    overallFile := FileOpen(overallAttemptsFile, "rw -rw")
    dailyFile := FileOpen(dailyAttemptsFile, "rw -rw")

    if (!IsObject(overallFile) || !IsObject(dailyFile)) {
        SetTimer, CountAttempt, -100
        return
    }

    overallAttemptCount := overallFile.Read() + 1
    dailyAttemptCount := dailyFile.Read() + 1

    overallFile.Pos := 0
    dailyFile.Pos := 0

    overallFile.Write(overallAttemptCount)
    dailyFile.Write(dailyAttemptCount)

    overallFile.Close()
    dailyFile.Close()
}

GetOldestPreview() {
    idx := GetOldestInstanceIndexOutsideGrid()
    preview := McDirectories[instancePosition[idx]] . "preview.tmp"
    if (!FileExist(preview))
        return -1
    return idx
}

ReplacePreviewsInGrid() {
    if (mode != "I" || GetPassiveGridInstanceCount() == 0)
        return
    gridUsageCount := GetFocusGridInstanceCount()
    hasSwapped := False
    loop %gridUsageCount% {
        preview := McDirectories[instancePosition[A_Index]] . "preview.tmp"
        if (!FileExist(preview)) {
            foundPreview := GetOldestPreview()
            if (foundPreview > 0) {
                SwapPositions(A_Index, foundPreview)
                hasSwapped := True
            }
        }
    }
    if (hasSwapped)
        NotifyMovingController()
}

GetTotalIdleInstances() {
    totalIdle := 0
    for i, mcdir in McDirectories {
        idle := mcdir . "idle.tmp"
        if FileExist(idle)
            totalIdle++
    }
    return totalIdle
}

FindBypassInstance() {
    if (bypassThreshold != -1) {
        idles := GetTotalIdleInstances()
        if (bypassThreshold <= idles)
            return -1
    }
    activeNum := GetActiveInstanceNum()
    for i, instance in instances {
        if (instance.GetIdle() && instance.GetLocked() && instance.GetIdx() != activeNum)
            return instance.GetIdx()
    }
    if (mode == "M") {
        for i, instance in instances {
            if (instance.GetIdle() && instance.GetIdx() != activeNum)
                return instance.GetIdx()
        }
    }
    return -1
}

MoveLast(oldIdx) {
    inst := instancePosition[oldIdx]
    instancePosition.RemoveAt(oldIdx)
    instancePosition.Push(inst)
}

SwapPositions(idx1, idx2) {
    if (idx1 < 1 || idx2 < 1 || idx1 > instancePosition.MaxIndex() || idx2 > instancePosition.MaxIndex())
        return
    inst1 := instancePosition[idx1], inst2 := instancePosition[idx2]
    instancePosition[idx1] := inst2, instancePosition[idx2] := inst1
    SendLog(LOG_LEVEL_INFO, Format("Swapping instances {1} and {2}", idx1, idx2))
}

GetGridIndexFromInstanceNumber(wantedInst) {
    for i, inst in instancePosition {
        if (inst == wantedInst)
            return i
    }
    return -1
}

GetFirstPassive() {
    passiveCount := GetPassiveGridInstanceCount(), gridCount := GetFocusGridInstanceCount()
    if (passiveCount > 0)
        return gridCount + GetLockedGridInstanceCount() + 1
    return gridCount
}

GetPreviewTime(idx) {
    previewFile := McDirectories[idx] . "preview.tmp"
    FileRead, previewTime, %previewFile%
    previewTime += 0
    return previewTime
}

GetOldestInstanceIndexOutsideGrid() {
    passiveCount := GetPassiveGridInstanceCount(), gridCount := GetFocusGridInstanceCount(), lockedCount := GetLockedGridInstanceCount()
    oldestInstanceIndex := -1
    oldestPreviewTime := A_TickCount
    ; Find oldest instance based on preview time, if any
    loop, %passiveCount% {
        idx := gridCount + lockedCount + A_Index
        inst := instancePosition[idx]

        previewTime := GetPreviewTime(inst)
        if (!locked[inst] && previewTime != 0 && previewTime <= oldestPreviewTime){
            oldestPreviewTime := previewTime
            oldestInstanceIndex := idx
        }
    }
    if (oldestInstanceIndex > -1)
        return oldestInstanceIndex
    ; Find oldest instance based on when they were reset.
    oldestTickCount := A_TickCount
    loop, %passiveCount% {
        idx := gridCount + lockedCount + A_Index
        inst := instancePosition[idx]
        if (!locked[inst] && timeSinceReset[inst] <= oldestTickCount) {
            oldestTickCount := timeSinceReset[inst]
            oldestInstanceIndex := idx
        }
    }
    ; There is no passive instances to swap with, take last of grid
    if (oldestInstanceIndex < 0)
        return gridCount + 1
    return oldestInstanceIndex
}

MousePosToInstNumber() {
    MouseGetPos, mX, mY
    instWidth := Floor(A_ScreenWidth / cols)
    instHeight := Floor(A_ScreenHeight / rows)
    if (mX < 0 || mY < 0 || mX > A_ScreenWidth || mY > A_ScreenHeight)
        return -1
    if (mode != "I")
        return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1

    lockedCount := GetLockedGridInstanceCount()
    gridCount := GetFocusGridInstanceCount(), passiveCount := GetPassiveGridInstanceCount()
    ; Inside Focus Grid
    if (mx <= A_ScreenWidth * focusGridWidthPercent && my <= A_ScreenHeight * focusGridHeightPercent) {
        return instancePosition[(Floor(mY / (A_ScreenHeight * focusGridHeightPercent / rows) ) * cols) + Floor(mX / (A_ScreenWidth * focusGridWidthPercent / cols )) + 1]
    }
    ; Inside Locked Grid
    if (my >= A_ScreenHeight * focusGridHeightPercent && mx<=A_ScreenWidth * focusGridWidthPercent) {
        lockedCols := Ceil(lockedCount / maxLockedRows)
        lockedRows := Min(lockedCount, maxLockedRows)
        lockedInstWidth := (A_ScreenWidth * focusGridWidthPercent) / lockedCols
        lockedInstHeight := (A_ScreenHeight * (1 - focusGridHeightPercent)) / lockedRows
        idx := gridCount + (Floor((mY - A_ScreenHeight * focusGridHeightPercent) / lockedInstHeight) ) + Floor(mX / lockedInstWidth) * lockedRows + 1
        if (!locked[instancePosition[idx]])
            return -1
        return instancePosition[idx]
    }
    ; Inside Passive Grid
    if (mx >= A_ScreenWidth * focusGridWidthPercent) {
        idx := gridCount + lockedCount + Floor(my / (A_ScreenHeight / passiveCount)) + 1
        return instancePosition[idx]
    }
    ; Mouse is in Narnia
    return 1
}

RunHide(Command) {
    dhw := A_DetectHiddenWindows
    DetectHiddenWindows, On
    Run, %ComSpec%,, Hide, cPid
    WinWait, ahk_pid %cPid%
    DetectHiddenWindows, %dhw%
    DllCall("AttachConsole", "uint", cPid)

    Shell := ComObjCreate("WScript.Shell")
    Exec := Shell.Exec(Command)
    Result := Exec.StdOut.ReadAll()

    DllCall("FreeConsole")
    Process, Close, %cPid%
    Return Result
}

GetMcDir(pid) {
    command := Format("powershell.exe $x = Get-WmiObject Win32_Process -Filter \""ProcessId = {1}\""; $x.CommandLine", pid)
    rawOut := RunHide(command)
    if (InStr(rawOut, "--gameDir")) {
        strStart := RegExMatch(rawOut, "P)--gameDir (?:""(.+?)""|([^\s]+))", strLen, 1)
        mcdir := SubStr(rawOut, strStart+10, strLen-10) . "\"
        SendLog(LOG_LEVEL_INFO, Format("Got {1} from pid: {2}", mcdir, pid))
        return mcdir
    } else {
        strStart := RegExMatch(rawOut, "P)(?:-Djava\.library\.path=(.+?) )|(?:\""-Djava\.library.path=(.+?)\"")", strLen, 1)
        if (SubStr(rawOut, strStart+20, 1) == "=") {
            strLen -= 1
            strStart += 1
        }
        mcdir := StrReplace(SubStr(rawOut, strStart+20, strLen-28) . ".minecraft\", "/", "\")
        SendLog(LOG_LEVEL_INFO, Format("Got {1} from pid: {2}", mcdir, pid))
        return mcdir
    }
}

GetRawInstanceNumberFromMcDir(mcDir) {
    cfg := Format("{1}instance.cfg", SubStr(mcDir, 1, StrLen(mcDir) - 11))
    total := 0
    loop, Read, %cfg%
    {
        if (!InStr(A_LoopReadLine, "name=")) {
            Continue
        }

        pos := 1
        While pos := RegExMatch(A_LoopReadLine, "\d+", number, pos + StrLen(number)) {
            total += number
        }
    }
    return total
}

CheckOnePIDFromMcDir(proc, mcdir) {
    cmdLine := proc.Commandline
    if (RegExMatch(cmdLine, "-Djava\.library\.path=(?P<Dir>[^\""]+?)(?:\/|\\)natives", instDir)) {
        StringTrimRight, rawInstDir, mcdir, 1
        thisInstDir := SubStr(StrReplace(instDir, "/", "\"), 21, StrLen(instDir)-28) . "\.minecraft"
        if (rawInstDir == thisInstDir)
            return proc.ProcessId
    }
    return -1
}

GetPIDFromMcDir(mcdir) {
    for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath like ""%jdk%javaw.exe%""") {
        if ((pid := CheckOnePIDFromMcDir(proc, mcdir)) != -1) {
            SendLog(LOG_LEVEL_INFO, Format("Got PID: {1} from {2}", pid, mcdir))
            return pid
        }
    }
    ; Broader search if some people use java.exe or some other edge cases
    for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath like ""%java%""") {
        if ((pid := CheckOnePIDFromMcDir(proc, mcdir)) != -1) {
            SendLog(LOG_LEVEL_INFO, Format("Got PID: {1} using boarder search from {2}", pid, mcdir))
            return pid
        }
    }
    SendLog(LOG_LEVEL_ERROR, Format("Failed to get PID from {1}", mcdir))
    return -1
}

GetRawPIDs() {
    rawPIDs := []
    WinGet, all, list
    Loop, %all%
    {
        WinGet, pid, PID, % Format("ahk_id {1}", all%A_Index%)
        WinGetTitle, title, % Format("ahk_pid {1}", pid)
        if (InStr(title, "Minecraft*")) {
            rawPIDs.Push(pid)
        }
    }
    return rawPIDs
}

GetMcDirFromFile(idx) {
    Loop, Read, data/mcdirs.txt
    {
        split := StrSplit(A_LoopReadLine,"~")
        if (idx == split[1]) {
            mcdir := split[2]
            StringReplace,mcdir,mcdir,`n,,A
            if FileExist(mcdir) {
                SendLog(LOG_LEVEL_INFO, Format("Got {1} from cache for instance {2}", mcdir, idx))
                return mcdir
            } else {
                FileDelete, data/mcdirs.txt
                SendLog(LOG_LEVEL_ERROR, Format("Didn't find mcdir file in GetMcDirFromFile. mcdir: {1}, idx: {2}", mcdir, idx))
                MsgBox, Something went wrong, please try again or open a ticket.
                ExitApp
            }
        }
    }
}

CreateInstanceArray() {
    SendLog(LOG_LEVEL_INFO, "Populating Minecraft instance data")
    rawPIDs := GetRawPIDs()

    if (!rawPIDs.Length()) {
        LaunchInstances()
    }

    rawNumMcDirs := {}
    for i, rawPID in rawPIDs {
        mcDir := GetMcDir(rawPID)
        rawNum := GetRawInstanceNumberFromMcDir(mcDir)
        rawNumMcDirs[rawNum] := mcDir
    }

    Critical, On
    for idx, mcDir in rawNumMcDirs {
        instances.Push(new Instance(idx, GetPIDFromMcDir(mcDir), mcDir))
    }
    Critical, Off
}

getHwndForPid(pid) {
    pidStr := "ahk_pid " . pid
    WinGet, hWnd, ID, %pidStr%
    return hWnd
}

SetAffinities(idx:=0) {
    for i, instance in instances {
        if (idx == instance.GetIdx()) { ; this is active instance
            instance.window.SetAffinity(playBitMask)
        } else if (idx > 0) { ; there is another active instance
            if !instance.GetIdle()
                instance.window.SetAffinity(bgLoadBitMask)
            else
                instance.window.SetAffinity(lowBitMask)
        } else { ; there is no active instance
            if instance.GetIdle()
                instance.window.SetAffinity(lowBitMask)
            else if instance.GetLocked()
                instance.window.SetAffinity(lockBitMask)
            else if instance.GetHeld()
                instance.window.SetAffinity(highBitMask)
            else if instance.GetPreviewing()
                instance.window.SetAffinity(midBitMask)
            else
                instance.window.SetAffinity(highBitMask)
        }
    }
}

SetAffinity(pid, mask) {
    hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
    DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
    DllCall("CloseHandle", "Ptr", hProc)
}

GetBitMask(threads) {
    return ((2 ** threads) - 1)
}

; Verifies that the user is using the correct projector
VerifyProjector() {
    static haveVerifiedProjector := false
    if haveVerifiedProjector
        return
    WinGetTitle, projTitle, A
    if InStr(projTitle, "(Preview)")
        MsgBox,,, You're using a Preview projector`, please use the Scene projector of the wall scene.
    else
        haveVerifiedProjector := true
    GetProjectorID()
}

CheckAHKVersion() {
    ; Yell if wrong AHK version
    if (SubStr(A_AhkVersion, 1, 3) != "1.1") {
        SendLog(LOG_LEVEL_INFO, "Wrong AHK version detected, exiting")
        MsgBox, Wrong AHK version, get version 1.1
        ExitApp
    }
}

CheckLaunchAudioGUI() {
    if audioGui {
        Gui, New
        Gui, Show,, The Wall Audio
    }
}

BindTrayIconFunctions() {
    Menu, Tray, Add, Delete Worlds, WorldBop

    Menu, Tray, Add, Close Instances, CloseInstances

    Menu, Tray, Add, Launch Instances, LaunchInstances
}

CheckOBSRunLevel() {
    WinGet, obsPid, PID, OBS
    if IsProcessElevated(obsPid) {
        MsgBox, Your OBS was run as admin which may cause wall hotkeys to not work. If this happens restart OBS and launch it normally.
            SendLog(LOG_LEVEL_WARNING, "OBS was run as admin which may cause wall hotkeys to not work")
    }
}

GetProjectorID() {
    static projectorID := 0
    if (WinExist("ahk_id " . projectorID))
        return projectorID
    WinGet, IDs, List, ahk_exe obs64.exe
    Loop %IDs% {
        newProjectorID := IDs%A_Index%
        if (HwndIsFullscreen(newProjectorID)) {
            projectorID := newProjectorID
            return projectorID
        }
    }
    SendLog(LOG_LEVEL_WARNING, "Could not detect OBS Fullscreen Projector window. Will try again at next Wall action.")
    return -1
}

HwndIsFullscreen(hwnd) { ; ahk_id or ID is HWND
    WinGetPos,,, w, h, % Format("ahk_id {1}", hwnd)
    SendLog(LOG_LEVEL_INFO, Format("hwnd {1} size is {2}x{3}", hwnd, w, h))
    return (w == A_ScreenWidth && h == A_ScreenHeight)
}

SwitchInstance(idx, special:=False) {
    instances[idx].Switch(special)
}

GetActiveInstanceNum() {
    WinGet, pid, PID, A
    for i, instance in instances {
        if (instance.GetPID() == pid)
            return instance.GetIdx()
    }
    return -1
}

ExitWorld(nextInst:=-1) {
    instances[GetActiveInstanceNum()].Exit(nextInst)
}

GetNextInstance(idx, nextInst) {
    if (mode == "C" && nextInst == -1)
        return Mod(idx, instances.MaxIndex()) + 1
    else if ((mode == "B" || mode == "M") && nextInst == -1)
        return FindBypassInstance()
    return nextInst
}

ResetAll(bypassLock:=false, extraProt:=0) {
    resetable := GetResetableInstances(GetFocusGridInstances(), bypassLock, extraProt)
    lockedResetable := GetLockedInstances(resetable)

    if (obsControl == "C" && mode != "I") {
        SendOBSCmd(GetCoverTypeObsCmd("Cover", true, resetable))
        SendOBSCmd(GetCoverTypeObsCmd("Lock", false, lockedResetable))
    }

    for i, instance in resetable {
        instance.SendReset()
        instance.window.SetAffinity(highBitMask)
        instance.SetLocked(false)
        instance.UnlockFiles()
    }
}

GetResetableInstances(checkInstances, bypassLock:=false, extraProt:=0) {
    resetable := []
    for i, instance in checkInstances {
        if (instance.GetCanReset(bypassLock, extraProt))
            resetable.Push(instance)
    }
    return resetable
}

GetLockedInstances(checkInstances) {
    locked := []
    for i, instance in checkInstances {
        if (instance.GetLocked())
            locked.Push(instance)
    }
    return locked
}

GetCoverTypeObsCmd(type, render, selectInstances) {
    if (!selectInstances.Length()) {
        return
    }
    cmd := ""
    for i, instance in selectInstances {
        cmd .= instance.GetIdx() . ","
    }
    return Format("{1},{2},{3}", type, render, RTrim(cmd, ","))
}

ResetInstance(idx, bypassLock:=true, extraProt:=0, force:=false) {
    instances[idx].Reset(bypassLock, extraProt, force)
}

MoveResetInstance(idx) {
    if (!locked[idx])
        if (GetPassiveGridInstanceCount() > 0)
        SwapPositions(GetGridIndexFromInstanceNumber(idx), GetOldestInstanceIndexOutsideGrid())
    else
        MoveLockedResetInstance(idx)
}

MoveLockedResetInstance(idx) {
    gridUsageCount := GetFocusGridInstanceCount()
    if (gridUsageCount < rxc)
        SwapPositions(GetGridIndexFromInstanceNumber(idx), gridUsageCount + 1)
    else
        MoveLast(GetGridIndexFromInstanceNumber(idx))
}

SetTitles() {
    for i, instance in instances {
        instance.window.SetTitle()
    }
}

ToWall(comingFrom) {
    currentInstance := -1
    FileDelete,data/instance.txt
    FileAppend,0,data/instance.txt

    VerifyProjector()
    WinMaximize, % Format("ahk_id {1}", GetProjectorID())
    WinActivate, % Format("ahk_id {1}", GetProjectorID())

    if (obsControl != "C") {
        send {%obsWallSceneKey% down}
        sleep, %obsDelay%
        send {%obsWallSceneKey% up}
    } else {
        SendOBSCmd(Format("ToWall"))
    }
}

FocusReset(focusInstance, bypassLock:=false, special:=false) {
    SwitchInstance(focusInstance, special)
    ResetAll(bypassLock, spawnProtection)
}

GetLockImage() {
    static lockImages := []
    if (lockImages.MaxIndex() < 1) {
        Loop, Files, %A_ScriptDir%\media\lock*.png
        {
            lockImages.Push(A_LoopFileFullPath)
        }
        SendLog(LOG_LEVEL_INFO, Format("Theme lock count found to be {1}", lockImages.MaxIndex()))
    }

    Random, randLock, 1, % lockImages.MaxIndex()
    SendLog(LOG_LEVEL_INFO, Format("{1} being used as lock", lockImages[randLock]))

    return lockImages[randLock]
}

LockInstance(idx, sound:=true, affinityChange:=true) {
    instances[idx].Lock(sound, affinityChange)
}

UnlockInstance(idx, sound:=true) {
    instances[idx].Unlock(sound)
}

LockSound(sound) {
    if (sound && (sounds == "A" || sounds == "F" || sound == "L")) {
        SoundPlay, A_ScriptDir\..\media\lock.wav
        if obsLockMediaKey {
            send {%obsLockMediaKey% down}
            sleep, %obsDelay%
            send {%obsLockMediaKey% up}
        }
    }
}

UnlockSound(sound) {
    if (sound && (sounds == "A" || sounds == "F" || sound == "L")) {
        SoundPlay, A_ScriptDir\..\media\unlock.wav
        if obsUnlockMediaKey {
            send {%obsUnlockMediaKey% down}
            sleep, %obsDelay%
            send {%obsUnlockMediaKey% up}
        }
    }
}

GetFocusGridInstances() {
    focusGridInstances := []
    for i, instance in instances {
        if (instance.GetFocus()) {
            focusGridInstances.Push(instance)
        }
    }
    return focusGridInstances
}

LockAll(sound:=true, affinityChange:=true) {
    lockable := GetFocusGridInstances()

    SendOBSCmd(GetCoverTypeObsCmd("Lock",true, lockable))

    for i, instance in lockable {
        instance.SetLocked(true)
        instance.LockFiles()
        if affinityChange
            instance.window.SetAffinity(lockBitMask)
    }

    LockSound(sound)
}

UnlockAll(sound:=true) {
    unlockable := GetFocusGridInstances()

    SendOBSCmd(GetCoverTypeObsCmd("Lock",false, unlockable))

    for i, instance in unlockable {
        instance.SetLocked(false)
        instance.UnlockFiles()
    }

    UnlockSound(sound)
}

PlayNextLock(focusReset:=false, bypassLock:=false, special:=false) {
    if (GetActiveInstanceNum() > 0) {
        ExitWorld(FindBypassInstance())
    } else {
        if (focusReset) {
            FocusReset(FindBypassInstance(), bypassLock, special)
        } else {
            SwitchInstance(FindBypassInstance(), special)
        }
    }
}

WorldBop(confirm:=true) {
    if (confirm) {
        MsgBox, 4, Delete Worlds?, Are you sure you want to delete all of your worlds?
        IfMsgBox No
        Return
    }
    if (SubStr(RunHide("python.exe --version"), 1, 6) == "Python") {
        cmd := "python.exe """ . A_ScriptDir . "\scripts\worldBopper9000x.py"""
        SendLog(LOG_LEVEL_INFO, "Running worldBopper9000x.py to clear worlds")
        RunWait,%cmd%, %A_ScriptDir%\scripts ,Hide
    } else {
        SendLog(LOG_LEVEL_INFO, "Running slowBopper2000,ahk to clear worlds")
        RunWait, "%A_ScriptDir%\scripts\slowBopper2000.ahk", %A_ScriptDir%
    }
    MsgBox, Completed World Bopping!
}

CloseInstances(confirm:=true) {
    if (confirm) {
        MsgBox, 4, Close Instances?, Are you sure you want to close all of your instances?
        IfMsgBox No
        Return
    }
    for i, instance in instances {
        instance.CloseInstance()
    }
    instances := []
}

LaunchInstances() {
    MsgBox, 4, Launch Instances?, Launch all of your instances?
    IfMsgBox No
    Return
    Run, "%A_ScriptDir%\utils\startup.ahk", %A_ScriptDir%
}

GetLineCount(file) {
    lineNum := 0
    Loop, Read, %file%
        lineNum := A_Index
    return lineNum
}

SetTheme(theme) {
    SendLog(LOG_LEVEL_INFO, Format("Setting macro theme to {1}", theme))
    if !FileExist(A_ScriptDir . "\media\")
        FileCreateDir, %A_ScriptDir%\media\
    Loop, Files, %A_ScriptDir%\media\*
    {
        FileDelete, %A_LoopFileFullPath%
    }
    Loop, Files, %A_ScriptDir%\themes\%theme%\*
    {
        fileDest := A_ScriptDir . "\media\" . A_LoopFileName
        FileCopy, %A_LoopFileFullPath%, %fileDest%, 1
        FileSetTime,,%fileDest%,M
        SendLog(LOG_LEVEL_INFO, Format("Copying file {1} to {2}", A_LoopFileFullPath, fileDest))
    }
}

IsProcessElevated(ProcessID) {
    if !(hProcess := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", ProcessID, "ptr")) {
        SendLog(LOG_LEVEL_WARNING, "OpenProcess failed. Process not open?")
        return 0
    }
    if !(DllCall("advapi32\OpenProcessToken", "ptr", hProcess, "uint", 0x0008, "ptr*", hToken)) {
        SendLog(LOG_LEVEL_WARNING, "OpenProcessToken failed. Process not open?")
        return 0
    }
    if !(DllCall("advapi32\GetTokenInformation", "ptr", hToken, "int", 20, "uint*", IsElevated, "uint", 4, "uint*", size))
        throw Exception("GetTokenInformation failed", -1), DllCall("CloseHandle", "ptr", hToken) && DllCall("CloseHandle", "ptr", hProcess)
    return IsElevated, DllCall("CloseHandle", "ptr", hToken) && DllCall("CloseHandle", "ptr", hProcess)
}

CheckOBSPython() {
    if (obsControl != "C") {
        Return
    }

    EnvGet, userProfileDir, USERPROFILE
    obsIni = %userProfileDir%\AppData\Roaming\obs-studio\global.ini
    IniRead, pyDir, %obsIni%, Python, Path64bit, N

    if (FileExist(Format("{1}\python.exe", pyDir))) {
        Return
    }

    pyPath := RegExReplace(ComObjCreate("WScript.Shell").Exec("python -c ""import sys; print(sys.executable)""").StdOut.ReadAll(), " *(\n|\r)+","")

    if (!FileExist(pyPath)) {
        SendLog(LOG_LEVEL_WARNING, "Couldn't find Python path")
        return
    }

    SplitPath, pyPath,, pyDir
    IniWrite, %pyDir%, %obsIni%, Python, Path64bit
    SendLog(LOG_LEVEL_INFO, Format("Automatically set OBS Python install path to {1}", pyDir))
}

SendOBSCmd(cmd) {
    if (obsControl != "C" || !cmd) {
        Return
    }

    static cmdNum := 1
    static cmdDir := % "data/pycmds/" . A_TickCount
    if !FileExist("data/pycmds")
        FileCreateDir, data/pycmds/
    FileAppend, %cmd%, %cmdDir%%cmdNum%.txt
    cmdNum++
}

GetLockedGridInstanceCount() {
    lockedInstanceCount := 0
    for i, isLocked in locked {
        if isLocked
            lockedInstanceCount++
    }
    return lockedInstanceCount
}

GetPassiveGridInstanceCount() {
    passiveInstanceCount := 0
    gridCount := GetFocusGridInstanceCount()
    for i, inst in instancePosition {
        if (i > gridCount) {
            if (!locked[inst]) {
                passiveInstanceCount++
            }
        }
    }
    return passiveInstanceCount
}

GetFocusGridInstanceCount() {
    if (mode != "I")
        return instances
    gridInstanceCount := 0
    for i, instance in instances {
        if (instance.GetFocus()) {
            gridInstanceCount++
        }
    }
    return gridInstanceCount
}

NotifyMovingController() {
    output := ""
    focusGridInstanceCount := GetFocusGridInstanceCount() ; To prevent looping every time
    for idx, inst in instancePosition {
        if (output != "" )
            output := output . ","
        output := output . inst
        if (mode != "I") {
            output := output . "W"
            Continue
        }

        if (locked[inst])
            output := output . "L"

        if (!locked[inst] && idx > focusGridInstanceCount)
            output := output . "H"
    }
    FileDelete, data/obs.txt
    FileAppend, %output%, data/obs.txt
    return output
}

WideHardo() {
    idx := GetActiveInstanceNum()
    commandkey := commandkeys[idx]
    pid := PIDs[idx]
    if (isWide)
        WinMaximize, ahk_pid %pid%
    else {
        WinRestore, ahk_pid %pid%
        WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
    }
    isWide := !isWide
}

OpenToLAN() {
    idx := GetActiveInstanceNum()
    commandkey := commandkeys[idx]
    Send, {Esc}
    Send, {ShiftDown}{Tab 3}{Enter}{Tab}{ShiftUp}
    Send, {Enter}{Tab}{Enter}
    Send, {%commandkey%}
    Sleep, 100
    Send, {Text}gamemode creative
    Send, {Enter}{%commandkey%}
    Sleep, 100
    Send, {Text}gamerule doImmediateRespawn true
    Send, {Enter}

}

GoToNether() {
    idx := GetActiveInstanceNum()
    commandkey := commandkeys[idx]
    Send, {%commandkey%}
    Sleep, 100
    Send, {Text}setblock ~ ~ ~ minecraft:nether_portal
    Send, {Enter}
}

OpenToLANAndGoToNether() {
    OpenToLAN()
    GoToNether()
}

CheckFor(struct, x := "", z := "") {
    idx := GetActiveInstanceNum()
    commandkey := commandkeys[idx]
    Send, {%commandkey%}
    Sleep, 100
    if (z != "" && x != "") {
        Send, {Text}execute positioned %x% 0 %z% run%A_Space% ; %A_Space% is only required at the end because a literal space would be trimmed
    }
    Send, {Text}locate %struct%
    Send, {Enter}
}

CheckFourQuadrants(struct) {
    CheckFor(struct, "1", "1")
    CheckFor(struct, "-1", "1")
    CheckFor(struct, "1", "-1")
    CheckFor(struct, "-1", "-1")
}

; Shoutout peej
CheckOptionsForValue(file, optionsCheck, defaultValue) {
    static keyArray := Object("key.keyboard.f1", "F1"
    ,"key.keyboard.f2", "F2"
    ,"key.keyboard.f3", "F3"
    ,"key.keyboard.f4", "F4"
    ,"key.keyboard.f5", "F5"
    ,"key.keyboard.f6", "F6"
    ,"key.keyboard.f7", "F7"
    ,"key.keyboard.f8", "F8"
    ,"key.keyboard.f9", "F9"
    ,"key.keyboard.f10", "F10"
    ,"key.keyboard.f11", "F11"
    ,"key.keyboard.f12", "F12"
    ,"key.keyboard.f13", "F13"
    ,"key.keyboard.f14", "F14"
    ,"key.keyboard.f15", "F15"
    ,"key.keyboard.f16", "F16"
    ,"key.keyboard.f17", "F17"
    ,"key.keyboard.f18", "F18"
    ,"key.keyboard.f19", "F19"
    ,"key.keyboard.f20", "F20"
    ,"key.keyboard.f21", "F21"
    ,"key.keyboard.f22", "F22"
    ,"key.keyboard.f23", "F23"
    ,"key.keyboard.f24", "F24"
    ,"key.keyboard.q", "q"
    ,"key.keyboard.w", "w"
    ,"key.keyboard.e", "e"
    ,"key.keyboard.r", "r"
    ,"key.keyboard.t", "t"
    ,"key.keyboard.y", "y"
    ,"key.keyboard.u", "u"
    ,"key.keyboard.i", "i"
    ,"key.keyboard.o", "o"
    ,"key.keyboard.p", "p"
    ,"key.keyboard.a", "a"
    ,"key.keyboard.s", "s"
    ,"key.keyboard.d", "d"
    ,"key.keyboard.f", "f"
    ,"key.keyboard.g", "g"
    ,"key.keyboard.h", "h"
    ,"key.keyboard.j", "j"
    ,"key.keyboard.k", "k"
    ,"key.keyboard.l", "l"
    ,"key.keyboard.z", "z"
    ,"key.keyboard.x", "x"
    ,"key.keyboard.c", "c"
    ,"key.keyboard.v", "v"
    ,"key.keyboard.b", "b"
    ,"key.keyboard.n", "n"
    ,"key.keyboard.m", "m"
    ,"key.keyboard.1", "1"
    ,"key.keyboard.2", "2"
    ,"key.keyboard.3", "3"
    ,"key.keyboard.4", "4"
    ,"key.keyboard.5", "5"
    ,"key.keyboard.6", "6"
    ,"key.keyboard.7", "7"
    ,"key.keyboard.8", "8"
    ,"key.keyboard.9", "9"
    ,"key.keyboard.0", "0"
    ,"key.keyboard.tab", "Tab"
    ,"key.keyboard.left.bracket", "["
    ,"key.keyboard.right.bracket", "]"
    ,"key.keyboard.backspace", "Backspace"
    ,"key.keyboard.equal", "="
    ,"key.keyboard.minus", "-"
    ,"key.keyboard.grave.accent", "`"
    ,"key.keyboard.slash", "/"
    ,"key.keyboard.space", "Space"
    ,"key.keyboard.left.alt", "LAlt"
    ,"key.keyboard.right.alt", "RAlt"
    ,"key.keyboard.print.screen", "PrintScreen"
    ,"key.keyboard.insert", "Insert"
    ,"key.keyboard.scroll.lock", "ScrollLock"
    ,"key.keyboard.pause", "Pause"
    ,"key.keyboard.right.control", "RControl"
    ,"key.keyboard.left.control", "LControl"
    ,"key.keyboard.right.shift", "RShift"
    ,"key.keyboard.left.shift", "LShift"
    ,"key.keyboard.comma", ","
    ,"key.keyboard.period", "."
    ,"key.keyboard.home", "Home"
    ,"key.keyboard.end", "End"
    ,"key.keyboard.page.up", "PgUp"
    ,"key.keyboard.page.down", "PgDn"
    ,"key.keyboard.delete", "Delete"
    ,"key.keyboard.left.win", "LWin"
    ,"key.keyboard.right.win", "RWin"
    ,"key.keyboard.menu", "AppsKey"
    ,"key.keyboard.backslash", "\"
    ,"key.keyboard.caps.lock", "CapsLock"
    ,"key.keyboard.semicolon", ";"
    ,"key.keyboard.apostrophe", "'"
    ,"key.keyboard.enter", "Enter"
    ,"key.keyboard.up", "Up"
    ,"key.keyboard.down", "Down"
    ,"key.keyboard.left", "Left"
    ,"key.keyboard.right", "Right"
    ,"key.keyboard.keypad.0", "Numpad0"
    ,"key.keyboard.keypad.1", "Numpad1"
    ,"key.keyboard.keypad.2", "Numpad2"
    ,"key.keyboard.keypad.3", "Numpad3"
    ,"key.keyboard.keypad.4", "Numpad4"
    ,"key.keyboard.keypad.5", "Numpad5"
    ,"key.keyboard.keypad.6", "Numpad6"
    ,"key.keyboard.keypad.7", "Numpad7"
    ,"key.keyboard.keypad.8", "Numpad8"
    ,"key.keyboard.keypad.9", "Numpad9"
    ,"key.keyboard.keypad.decimal", "NumpadDot"
    ,"key.keyboard.keypad.enter", "NumpadEnter"
    ,"key.keyboard.keypad.add", "NumpadAdd"
    ,"key.keyboard.keypad.subtract", "NumpadSub"
    ,"key.keyboard.keypad.multiply", "NumpadMult"
    ,"key.keyboard.keypad.divide", "NumpadDiv"
    ,"key.mouse.left", "LButton"
    ,"key.mouse.right", "RButton"
    ,"key.mouse.middle", "MButton"
    ,"key.mouse.4", "XButton1"
    ,"key.mouse.5", "XButton2")
    FileRead, fileData, %file%
    if (RegExMatch(fileData, "[A-Z]:(\/|\\).+\.txt", globalPath)) {
        file := globalPath
    }
    Loop, Read, %file%
    {
        if (InStr(A_LoopReadLine, optionsCheck)) {
            split := StrSplit(A_LoopReadLine, ":")
            if (split.MaxIndex() == 2)
                if keyArray[split[2]]
                return keyArray[split[2]]
            else
                return split[2]
            SendLog(LOG_LEVEL_ERROR, Format("Couldn't parse options correctly, defaulting to '{1}'. Line: {2}", defaultKey, A_LoopReadLine))
            return defaultValue
        }
    }
}
