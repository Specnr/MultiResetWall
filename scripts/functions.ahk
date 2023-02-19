SendLog(lvlText, msg) {
  tc := A_TickCount
  file := FileOpen("data/log.log", "a -rw")
  if (!IsObject(file)) {
    logQueue := Func("SendLog").Bind(lvlText, msg, tc)
    SetTimer, %logQueue%, -10
    return
  }
  file.Close()
  FileAppend, [%tc%] [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] [SYS-%lvlText%] %msg%`n, data/log.log
}

CountAttempts() {
  file := overallAttemptsFile
  FileRead, WorldNumber, %file%
  if (ErrorLevel)
    WorldNumber := resets
  else
    FileDelete, %file%
  WorldNumber += resets
  FileAppend, %WorldNumber%, %file%
  file := dailyAttemptsFile
  FileRead, WorldNumber, %file%
  if (ErrorLevel)
    WorldNumber := resets
  else
    FileDelete, %file%
  WorldNumber += resets
  FileAppend, %WorldNumber%, %file%
  resets := 0
}

GetOldestPreview() {
  idx := GetOldestInstanceIndexOutsideGrid()
  preview := McDirectories[instancePosition[idx]] . "preview.tmp"
  if (!FileExist(preview))
    return -1
  return idx
}

ReplacePreviewsInGrid() {
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
  for i, isLocked in locked {
    idle := McDirectories[i] . "idle.tmp"
    if (FileExist(idle) && isLocked && i != activeNum)
      return i
  }
  if (mode == "M") {
    for i, mcdir in McDirectories {
      idle := mcdir . "idle.tmp"
      if (FileExist(idle) && i != activeNum)
        return i
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

RunHide(Command)
{
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

GetMcDir(pid)
{
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

GetRawInstanceNumberFromMcDir(mcdir) {
  cfg := SubStr(mcdir, 1, StrLen(mcdir) - 11) . "instance.cfg"
  loop, Read, %cfg%
  {
    if (InStr(A_LoopReadLine, "name=")) {
      Pos := 1
      total := 0
      While Pos := RegExMatch(A_LoopReadLine, "\d+", m, Pos + StrLen(m))
        total += m
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

GetInstanceTotal() {
  idx := 1
  WinGet, all, list
  Loop, %all%
  {
    WinGet, pid, PID, % "ahk_id " all%A_Index%
    WinGetTitle, title, ahk_pid %pid%
    if (InStr(title, "Minecraft*")) {
      rawPIDs[idx] := pid
      idx += 1
    }
  }
  return rawPIDs.MaxIndex()
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

GetAllPIDs()
{
  SendLog(LOG_LEVEL_INFO, "Getting all Minecraft directory and PID data")
  instances := GetInstanceTotal()
  if !instances {
    MsgBox, No open instances detected.
    SendLog(LOG_LEVEL_WARNING, "No open instances detected, and make sure that fabric is installed.")
    Return
  }
  SendLog(LOG_LEVEL_INFO, Format("{1} Instances detected", instances))
  ; If there are more/less instances than usual, rebuild cache
  if hasMcDirCache && GetLineCount("data/mcdirs.txt") != instances {
    FileDelete,data/mcdirs.txt
    hasMcDirCache := False
  }
  ; Generate mcdir and order PIDs
  if hasMcDirCache {
    Loop, %instances% {
      mcdir := GetMcDirFromFile(A_Index)
      PIDs[A_Index] := GetPIDFromMcDir(mcdir)
      ; If it already exists then theres a dupe instNum
      pastMcDir := McDirectories[A_Index]
      if (pastMcDir) {
        FileDelete,data/mcdirs.txt
        MsgBox, Instance Number %A_Index% was found twice, rename your instances correctly and relaunch.
        ExitApp
      }
      McDirectories[A_Index] := mcdir
    }
  } else {
    rawNumToMcDir := {}
    Loop, %instances% {
      mcdir := GetMcDir(rawPIDs[A_Index])
      rawNum := GetRawInstanceNumberFromMcDir(mcdir)
      ; Putting them in an object like this sorts them by rawNum
      rawNumToMcDir[rawNum] := mcdir
    }
    for i, mcdir in rawNumToMcDir {
      FileAppend,%A_Index%~%mcdir%`n,data/mcdirs.txt
      PIDs[A_Index] := GetPIDFromMcDir(mcdir)
      McDirectories[A_Index] := mcdir
    }
  }
}

getHwndForPid(pid) {
  pidStr := "ahk_pid " . pid
  WinGet, hWnd, ID, %pidStr%
  return hWnd
}

SetAffinities(idx:=0) {
  for i, mcdir in McDirectories {
    pid := PIDs[i]
    idle := mcdir . "idle.tmp"
    hold := mcdir . "hold.tmp"
    preview := mcdir . "preview.tmp"
    if (idx == i) { ; this is active instance
      SetAffinity(pid, playBitMask)
    } else if (idx > 0) { ; there is another active instance
      if !FileExist(idle)
        SetAffinity(pid, bgLoadBitMask)
      else
        SetAffinity(pid, lowBitMask)
    } else { ; there is no active instance
      if FileExist(idle)
        SetAffinity(pid, lowBitMask)
      else if locked[i]
        SetAffinity(pid, lockBitMask)
      else if FileExist(hold)
        SetAffinity(pid, highBitMask)
      else if FileExist(preview)
        SetAffinity(pid, midBitMask)
      else
        SetAffinity(pid, highBitMask)
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
  WinGetTitle, projTitle, A
  if InStr(projTitle, "(Preview)")
    MsgBox, You're using a Preview projector, please use the Scene projector of the wall scene.
  else
    haveVerifiedProjector := true
}

SwitchInstance(idx, special:=False)
{
  if (!haveVerifiedProjector) {
    VerifyProjector()
    if !haveVerifiedProjector
      return
  }
  wasLocked := locked[idx]
  if (!wasLocked)
    LockInstance(idx, False, False)
  else if (mode == "I")
    NotifyMovingController()
  idleFile := McDirectories[idx] . "idle.tmp"
  if (idx > 0 && idx <= instances && (FileExist(idleFile)) || mode == "C") {
    holdFile := McDirectories[idx] . "hold.tmp"
    FileAppend,,%holdFile%
    killFile := McDirectories[idx] . "kill.tmp"
    FileAppend,,%killFile%
    FileDelete,data/instance.txt
    FileAppend,%idx%,data/instance.txt
    hwnd := hwnds[idx]
    pid := PIDs[idx]
    FileAppend,, %sleepBgLock%
    SetAffinities(idx)
    GetProjectorID(projectorID)
    WinMinimize, ahk_id %projectorID%

    foreGroundWindow := DllCall("GetForegroundWindow")
    windowThreadProcessId := DllCall("GetWindowThreadProcessId", "uint", foreGroundWindow, "uint", 0)
    currentThreadId := DllCall("GetCurrentThreadId")
    DllCall("AttachThreadInput", "uint", windowThreadProcessId, "uint", currentThreadId, "int", 1)
    if (widthMultiplier && (windowMode == "W" || windowMode == "B"))
      DllCall("SendMessage", "uint", hwnds[idx], "uint", 0x0112, "uint", 0xF030, "int", 0) ; fast maximise
    DllCall("SetForegroundWindow", "uint", hwnds[idx]) ; Probably only important in windowed, helps application take input without a Send Click
    DllCall("BringWindowToTop", "uint", hwnds[idx])
    DllCall("AttachThreadInput", "uint", windowThreadProcessId, "uint", currentThreadId, "int", 0)

    if (windowMode == "F" && CheckOptionsForValue(McDirectories[idx] . "options.txt", "fullscreen:", "false") == "false") {
      fsKey := fsKeys[idx]
      ControlSend,, {Blind}{%fsKey%}, ahk_pid %pid%
      sleep, %fullscreenDelay%
    }

    if unpauseOnSwitch
      ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    else
      ControlSend,, {Blind}{Esc 2}, ahk_pid %pid%
    if (f1States[idx] == 2)
      ControlSend,, {Blind}{F1}, ahk_pid %pid%
    if widthMultiplier
      WinMaximize, ahk_pid %pid%

    if (coop)
      ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, ahk_pid %pid%
    if (special)
      OnJoinSettingsChange(pid)
    if (obsControl != "C") {
      if (obsControl == "N")
        obsKey := "Numpad" . idx
      else if (obsControl == "F")
        obsKey := "F" . (idx+12)
      else if (obsControl == "ARR")
        obsKey := obsCustomKeyArray[idx]
      Send {%obsKey% down}
      Sleep, %obsDelay%
      Send {%obsKey% up}
    } else {
      SendOBSCmd("Play," . idx)
    }
  } else if smartSwitch {
    nextInst := FindBypassInstance()
    if (nextInst > 0)
      SwitchInstance(nextInst)
  }
}

GetActiveInstanceNum() {
  WinGet, pid, PID, A
  for i, tmppid in PIDs {
    if (tmppid == pid)
      return i
  }
  return -1
}

ExitWorld(nextInst:=-1) {
  idx := GetActiveInstanceNum()
  if (idx > 0) {
    pid := PIDs[idx]
    if f1States[idx]
      ControlSend,, {Blind}{F1}{F3}{Esc 3}, ahk_pid %pid%
    else
      ControlSend,, {Blind}{F3}{Esc 3}, ahk_pid %pid%
    if (CheckOptionsForValue(McDirectories[idx] . "options.txt", "fullscreen:", "false") == "true") {
      fsKey := fsKeys[idx]
      ControlSend,, {Blind}{%fsKey%}, ahk_pid %pid%
      sleep, %fullscreenDelay%
    }
    holdFile := McDirectories[idx] . "hold.tmp"
    killFile := McDirectories[idx] . "kill.tmp"
    FileDelete,%holdFile%
    FileDelete, %killFile%
    WinRestore, ahk_pid %pid%
    ResetInstance(idx)
    SetAffinities(nextInst)
    if (mode == "C" && nextInst == -1)
      nextInst := Mod(idx, instances) + 1
    else if ((mode == "B" || mode == "M") && nextInst == -1)
      nextInst := FindBypassInstance()
    if (nextInst > 0)
      SwitchInstance(nextInst)
    else
      ToWall(idx)
    if widthMultiplier
      WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
    Winset, Bottom,, ahk_pid %pid%
    isWide := False
    FileDelete, %sleepBgLock%
  }
}

ResetInstance(idx, bypassLock:=true, extraProt:=0, resettingAll:=false) {
  if (!haveVerifiedProjector) {
    VerifyProjector()
    if !haveVerifiedProjector
      return
  }
  holdFile := McDirectories[idx] . "hold.tmp"
  previewTime := GetPreviewTime(idx)
  spawnProt := spawnProtection + extraProt
  if (idx > 0 && idx <= instances && !FileExist(holdFile) && (spawnProt + previewTime) < A_TickCount && ((!bypassLock && !locked[idx]) || bypassLock)) {
    if (mode == "I") {
      if (!locked[idx])
        SwapPositions(GetGridIndexFromInstanceNumber(idx), GetOldestInstanceIndexOutsideGrid())
      else {
        gridUsageCount := GetFocusGridInstanceCount()
        if (gridUsageCount < rxc)
          SwapPositions(GetGridIndexFromInstanceNumber(idx), gridUsageCount + 1)
        else
          MoveLast(GetGridIndexFromInstanceNumber(idx))
      }
    }
    FileAppend,, %holdFile%
    SendLog(LOG_LEVEL_INFO, Format("Instance {1} valid reset triggered", idx))
    pid := PIDs[idx]
    rmpid := RM_PIDs[idx]
    resetKey := resetKeys[idx]
    lpKey := lpKeys[idx]
    previewFile := McDirectories[idx] . "preview.tmp"
    FileDelete, %previewFile%
    ControlSend, ahk_parent, {Blind}{%lpKey%}{%resetKey%}, ahk_pid %pid%
    timeSinceReset[idx] := A_TickCount
    DetectHiddenWindows, On
    PostMessage, MSG_RESET,,,, ahk_pid %rmpid%
    DetectHiddenWindows, Off
    if locked[idx]
      UnlockInstance(idx, false)
    if (mode == "I" && !resettingAll)
      NotifyMovingController()
    resets++
  }
}

SetTitles() {
  for i, pid in PIDs {
    WinSetTitle, ahk_pid %pid%, , Minecraft* - Instance %i%
  }
}

HwndIsFullscreen(hwnd) { ; ahk_id or ID is HWND
  WinGetPos,,, w, h, ahk_id %hwnd%
  SendLog(LOG_LEVEL_INFO, Format("OBS Window {1} {2}", w, h))
  return (w == A_ScreenWidth && h == A_ScreenHeight)
}

GetProjectorID(ByRef projID) {
  if (WinExist("ahk_id " . projID))
    return
  WinGet, IDs, List, ahk_exe obs64.exe
  Loop %IDs%
  {
    projID := IDs%A_Index%
    if (HwndIsFullscreen(projID))
      return
  }
  projID := -1
  SendLog(LOG_LEVEL_WARNING, "Could not detect OBS Fullscreen Projector window. Will try again at next Wall action.")
}

ToWall(comingFrom) {
  FileDelete,data/instance.txt
  FileAppend,0,data/instance.txt
  GetProjectorID(projectorID)
  WinMaximize, ahk_id %projectorID%
  WinActivate, ahk_id %projectorID%
  if (obsControl != "C") {
    send {%obsWallSceneKey% down}
    sleep, %obsDelay%
    send {%obsWallSceneKey% up}
  } else {
    SendOBSCmd(Format("ToWall"))
  }
}

FocusReset(focusInstance, bypassLock:=false) {
  if (!haveVerifiedProjector) {
    VerifyProjector()
    if !haveVerifiedProjector
      return
  }
  if focusInstance < 0
    return
  if bypassLock
    UnlockAll(false)
  SwitchInstance(focusInstance)
  if (mode == "I") {
    focusCount := GetFocusGridInstanceCount()
    loop, %focusCount% {
      if (A_Index = focusInstance)
        Continue
      ResetInstance(instancePosition[A_Index],,,true)
    }
    NotifyMovingController()
  } else {
    loop, %instances% {
      if (A_Index = focusInstance || locked[A_Index])
        Continue
      ResetInstance(A_Index,, spawnProtection)
    }
  }
}

; Reset all instances
ResetAll(bypassLock:=false) {
  if (!haveVerifiedProjector) {
    VerifyProjector()
    if !haveVerifiedProjector
      return
  }
  if bypassLock
    UnlockAll(false)
  if (mode == "I") {
    focusCount := GetFocusGridInstanceCount()
    loop, %focusCount%
      ResetInstance(instancePosition[A_Index],,,true)
    NotifyMovingController()
  } else {
    loop, %instances% {
      if locked[A_Index]
        Continue
      ResetInstance(A_Index)
    }
  }
}

GetLockFile() {
  if (useRandomLocks > 1) {
    Random, randLock, 1, %useRandomLocks%
    source := A_ScriptDir . "\media\lock" . randLock . ".png"
    SendLog(LOG_LEVEL_INFO, Format("Randomly picked lock{1}.png to send as lock", randLock))
    if !FileExist(source) {
      source := A_ScriptDir . "\media\lock.png"
      SendLog(LOG_LEVEL_ERROR, Format("lock{1}.png did not exist, defaulting to lock.png", randLock))
    }
  } else {
    source := A_ScriptDir . "\media\lock.png"
  }
  return source
}

LockInstance(idx, sound:=true, affinityChange:=true) {
  if (idx > instances || idx <= 0 || locked[idx])
    return
  if (mode == "I")
    SwapPositions(GetGridIndexFromInstanceNumber(idx), GetFirstPassive())
  locked[idx] := true
  lockDest := McDirectories[idx] . "lock.png"
  lockSource := GetLockFile()
  FileCopy, %lockSource%, %lockDest%, 1
  FileSetTime,,%lockDest%,M
  if (mode == "I")
    NotifyMovingController()
  else if (obsControl == "C")
    SendOBSCmd(Format("Lock,{1},1", idx))
  lockDest := McDirectories[idx] . "lock.tmp"
  FileAppend,, %lockDest%
  if ((sounds == "A" || sounds == "F" || sound == "L") && sound) {
    SoundPlay, A_ScriptDir\..\media\lock.wav
    if obsLockMediaKey {
      send {%obsLockMediaKey% down}
      sleep, %obsDelay%
      send {%obsLockMediaKey% up}
    }
  }
  if affinityChange {
    pid := PIDs[idx]
    SetAffinity(pid, lockBitMask)
  }
}

UnlockInstance(idx, sound:=true) {
  if (idx > instances || idx <= 0)
    return
  locked[idx] := false
  if (obsControl == "C")
    SendOBSCmd(Format("Lock,{1},0", idx))
  else {
    lockDest := McDirectories[idx] . "lock.png"
    FileCopy, A_ScriptDir\..\media\unlock.png, %lockDest%, 1
    FileSetTime,,%lockDest%,M
  }
  lockDest := McDirectories[idx] . "lock.tmp"
  FileDelete, %lockDest%
  if ((sounds == "A" || sounds == "F" || sound == "L") && sound) {
    SoundPlay, A_ScriptDir\..\media\unlock.wav
    if obsUnlockMediaKey {
      send {%obsUnlockMediaKey% down}
      sleep, %obsDelay%
      send {%obsUnlockMediaKey% up}
    }
  }
}

LockAll(sound:=true) {
  loop, %instances% {
    LockInstance(A_Index, false)
  }
  if ((sounds == "A" || sounds == "F" || sound == "L") && sound) {
    SoundPlay, A_ScriptDir\..\media\lock.wav
    if obsLockMediaKey {
      send {%obsLockMediaKey% down}
      sleep, %obsDelay%
      send {%obsLockMediaKey% up}
    }
  }
}

UnlockAll(sound:=true) {
  loop, %instances% {
    UnlockInstance(A_Index, false)
  }
  if ((sounds == "A" || sounds == "F" || sound == "L") && sound) {
    SoundPlay, A_ScriptDir\..\media\unlock.wav
    if obsUnlockMediaKey {
      send {%obsUnlockMediaKey% down}
      sleep, %obsDelay%
      send {%obsUnlockMediaKey% up}
    }
  }
}

PlayNextLock(focusReset:=false, bypassLock:=false) {
  if (GetActiveInstanceNum() > 0)
    ExitWorld(FindBypassInstance())
  else {
    if focusReset {
      if ((bypass := FindBypassInstance()) != -1)
        FocusReset(bypass, bypassLock)
      else
        ResetAll(bypassLock)
    } else {
      SwitchInstance(FindBypassInstance())
    }
  }
}

WorldBop() {
  MsgBox, 4, Delete Worlds?, Are you sure you want to delete all of your worlds?
  IfMsgBox No
  Return
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

CloseInstances() {
  MsgBox, 4, Close Instances?, Are you sure you want to close all of your instances?
  IfMsgBox No
  Return
  for i, pid in PIDs {
    WinClose, ahk_pid %pid%
  }
  DetectHiddenWindows, On
  for i, rmpid in RM_PIDs {
    WinClose, ahk_pid %rmpid%
  }
  DetectHiddenWindows, Off
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
  Loop, Files, %A_ScriptDir%\media\lock*.png
  {
    useRandomLocks += 1
  }
  SendLog(LOG_LEVEL_INFO, Format("Theme lock count found to be {1}", useRandomLocks))
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

SendOBSCmd(cmd) {
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
  gridInstanceCount := 0
  for i, inst in instancePosition {
    if (locked[inst]) {
      return gridInstanceCount
    }
    gridInstanceCount++
    if (gridInstanceCount == rxc) {
      return gridInstanceCount
    }
  }
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

    if (!locked[inst] && A_Index > focusGridInstanceCount)
      output := output . "H"
  }
  FileDelete, data/obs.txt
  FileAppend, %output%, data/obs.txt
  return output
}

OnJoinSettingsChange(pid) {
  rdPresses := renderDistance - 2
  ControlSend,, {Blind}{Shift down}{F3 down}{f 30}{Shift up}{f %rdPresses%}{F3 up}, ahk_pid %pid%
  if (toggleChunkBorders)
    ControlSend,, {Blind}{F3 down}{g}{F3 up}, ahk_pid %pid%
  if (toggleHitBoxes)
    ControlSend,, {Blind}{F3 down}{b}{F3 up}, ahk_pid %pid%
  FOVPresses := ceil((110-fov)*1.7875)
  entityPresses := (5 - (entityDistance*.01)) * 143 / 4.5
  ControlSend,, {Blind}{F3 down}{d}{F3 up}{Esc}{Tab 6}{Enter}{Tab 1}{Right 150}{Left %FOVPresses%}{Tab 5}{Enter}{Tab 17}{Right 150}{Left %entityPresses%}{Esc 2}, ahk_pid %pid%
}

VerifyInstance(mcdir, pid, idx) {
  moddir := mcdir . "mods\"
  optionsFile := mcdir . "options.txt"
  atum := false
  wp := false
  standardSettings := false
  fastReset := false
  sleepBg := false
  sodium := false
  srigt := false
  f1States[idx] := 0
  SendLog(LOG_LEVEL_INFO, Format("Starting instance verification for directory: {1}", mcdir))
  ; Check for mod dependencies
  Loop, Files, %moddir%*.jar
  {
    if InStr(A_LoopFileName, ".disabled")
      continue
    else if InStr(A_LoopFileName, "atum")
      atum := true
    else if InStr(A_LoopFileName, "worldpreview")
      wp := true
    else if InStr(A_LoopFileName, "standardsettings")
      standardSettings := true
    else if InStr(A_LoopFileName, "fast-reset")
      fastReset := true
    else if InStr(A_LoopFileName, "sleepbackground")
      sleepBg := true
    else if InStr(A_LoopFileName, "sodium")
      sodium := true
    else if InStr(A_LoopFileName, "SpeedRunIGT")
      srigt := true
  }
  if !atum {
    SendLog(LOG_LEVEL_ERROR, Format("Instance {1} missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases. (In directory: {2})", idx, moddir))
    MsgBox, Instance %idx% missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases.`n(In directory: %moddir%)
  } else if unpauseOnSwitch {
    config := mcdir . "config\atum\atum.properties"
    ; Read the atum.properties and set unpauseOnSwitch to false if a seed is set
    Loop, Read, %config%
    {
      if (InStr(A_LoopReadLine, "seed=") && StrLen(A_LoopReadLine) > 5) {
        SendLog(LOG_LEVEL_INFO, "Found a set seed, setting 'unpauseOnSwitch' to False")
        unpauseOnSwitch := False
        break
      }
    }
  }
  if !wp {
    SendLog(LOG_LEVEL_WARNING, Format("Instance {1} missing recommended mod: World Preview. Macro attempted to adapt. Download: https://github.com/VoidXWalker/WorldPreview/releases. (In directory: {2})", idx, moddir))
    doubleCheckUnexpectedLoads := False
  } else {
    doubleCheckUnexpectedLoads := True
  }
  FileRead, settings, %optionsFile%
  if !standardSettings {
    SendLog(LOG_LEVEL_WARNING, Format("Instance {1} missing highly recommended mod standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases. (In directory: {2})", idx, moddir))
    MsgBox, Instance %idx% missing highly recommended mod: standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases.`n(In directory: %moddir%)
    if InStr(settings, "pauseOnLostFocus:true") {
      MsgBox, Instance %idx% has required disabled setting pauseOnLostFocus enabled. Please disable it with f3+p and THEN press OK to continue
      SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had pauseOnLostFocus set true, macro requires it false. User was informed. (In file: {2})", idx, optionsFile))
    }
    if (atum) {
      if (InStr(settings, "key_Create New World:key.keyboard.unknown")) {
        MsgBox, Instance %idx% missing required hotkey: Create New World. Please set it in your hotkeys and THEN press OK to continue
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Create New World key set. User was informed. (In file: {2})", idx, optionsFile))
      }
      resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")
      resetKeys[idx] := resetKey
      SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
    }
    if (wp) {
      if (InStr(settings, "key_Leave Preview:key.keyboard.unknown")) {
        MsgBox, Instance %idx% missing highly recommended hotkey: Leave Preview. Please set it in your hotkeys and THEN press OK to continue
        SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Leave Preview key set. User was informed. (In file: {2})", idx, optionsFile))
      }
      lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")
      lpkeys[idx] := lpKey
      SendLog(LOG_LEVEL_INFO, Format("Found leave preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
    }
    if (windowMode == "F") {
      if (InStr(settings, "key_key.fullscreen:key.keyboard.unknown")) {
        MsgBox, Instance %idx% missing required hotkey for fullscreen mode: Fullscreen. Please set it in your hotkeys and THEN press OK to continue
          SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Fullscreen key set. User was informed. (In file: {2})", idx, optionsFile))
      }
      fsKey := CheckOptionsForValue(optionsFile, "key_key.fullscreen", "F11")
      fsKeys[idx] := fsKey
      SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2} from {3}", fsKey, idx, optionsFile))
    }
  } else {
    standardSettingsFile := mcdir . "config\standardoptions.txt"
    FileRead, ssettings, %standardSettingsFile%
    if (RegExMatch(ssettings, "[A-Z]\w{0}:(\/|\\).+.txt", globalPath)) {
      standardSettingsFile := globalPath
      SendLog(LOG_LEVEL_INFO, Format("Global standard options file detected, rereading standard options from {1}", standardSettingsFile))
      FileRead, ssettings, %standardSettingsFile%
    }
    if InStr(ssettings, "fullscreen:true") {
      ssettings := StrReplace(ssettings, "fullscreen:true", "fullscreen:false")
      SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had fullscreen set true, macro requires it false. Automatically fixed. (In file: {2})", idx, standardSettingsFile))
    }
    if InStr(ssettings, "pauseOnLostFocus:true") {
      ssettings := StrReplace(ssettings, "pauseOnLostFocus:true", "pauseOnLostFocus:false")
      SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had pauseOnLostFocus set true, macro requires it false. Automatically fixed. (In file: {2})", idx, standardSettingsFile))
    }
    if (RegExMatch(ssettings, "f1:.+", f1Match)) {
      SendLog(LOG_LEVEL_INFO, Format("Instance {1} f1 state '{2}' found. This will be used for ghost pie and instance join. (In file: {3})", idx, f1Match, standardSettingsFile))
      f1States[idx] := f1Match == "f1:true" ? 2 : 1
    }
    Loop, 1 {
      if (InStr(ssettings, "key_Create New World:key.keyboard.unknown") && atum) {
        Loop, 1 {
          MsgBox, 4, Create New World Key, Instance %idx% has no Create New World hotkey set. Would you like to set this back to default (F6)?`n(In file: %standardSettingsFile%)
          IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_Create New World:key.keyboard.unknown", "key_Create New World:key.keyboard.f6")
          resetKeys[idx] := "F6"
          SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Create New World key set and chose to let it be automatically set to f6. (In file: {2})", idx, standardSettingsFile))
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Create New World key set. (In file: {2})", idx, standardSettingsFile))
      } else if (InStr(ssettings, "key_Create New World:") && atum) {
        if (resetKey := CheckOptionsForValue(standardSettingsFile, "key_Create New World", "F6")) {
          SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, standardSettingsFile))
          resetKeys[idx] := resetKey
          break
        } else {
          SendLog(LOG_LEVEL_WARNING, Format("Failed to read reset key for instance {1}, trying to read from {2} instead of {3}", idx, optionsFile, standardSettingsFile))
          if (resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")) {
            SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
            resetKeys[idx] := resetKey
            break
          }
        }
        SendLog(LOG_LEVEL_ERROR, Format("Failed to find reset key in instance {1}, falling back to 'F6'. (Checked files: {2} and {3})", idx, standardSettingsFile, optionsFile))
        resetKeys[idx] := "F6"
      } else if (InStr(settings, "key_Create New World:key.keyboard.unknown") && atum) {
        MsgBox, Instance %idx% has no required hotkey set for Create New World. Please set it in your hotkeys and THEN press OK to continue
          SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Create New World key set. User was informed. (In file: {2})", idx, optionsFile))
        if (resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")) {
          resetKeys[idx] := resetKey
          SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
        } else {
          SendLog(LOG_LEVEL_ERROR, Format("No required atum mod in instance {1}. Using 'f6' to avoid reset manager errors", idx))
          resetKeys[idx] := "F6"
        }
      } else if (InStr(settings, "key_Create New World:") && atum) {
        if (resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")) {
          SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
          resetKeys[idx] := resetKey
        } else {
          SendLog(LOG_LEVEL_ERROR, Format("Failed to find reset key in instance {1}, falling back to 'F6'. (In file: {2})", idx, optionsFile))
          resetKeys[idx] := "F6"
        }
      } else if (atum) {
        MsgBox, No Create New World hotkey found even though you have the mod, you likely have an outdated version. Please update to the latest version.
        SendLog(LOG_LEVEL_ERROR, Format("No Create New World hotkey found for instance {1} even though mod is installed. Using 'f6' to avoid reset manager errors", idx))
        resetKeys[idx] := "F6"
      } else {
        SendLog(LOG_LEVEL_ERROR, Format("No required atum mod in instance {1}. Using 'f6' to avoid reset manager errors", idx))
        resetKeys[idx] := "F6"
      }
      break
    }
    Loop, 1 {
      if (InStr(ssettings, "key_Leave Preview:key.keyboard.unknown") && wp) {
        Loop, 1 {
          MsgBox, 4, Leave Preview Key, Instance %idx% has no Leave Preview hotkey set. Would you like to set this back to default (h)?`n(In file: %standardSettingsFile%)
          IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_Leave Preview:key.keyboard.unknown", "key_Leave Preview:key.keyboard.h")
          lpKeys[idx] := "h"
          SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Leave Preview key set and chose to let it be automatically set to 'h'. (In file: {2})", idx, standardSettingsFile))
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Leave Preview key set. (In file: {2})", idx, standardSettingsFile))
      } else if (InStr(ssettings, "key_Leave Preview:") && wp) {
        if (lpKey := CheckOptionsForValue(standardSettingsFile, "key_Leave Preview", "h")) {
          SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, standardSettingsFile))
          lpKeys[idx] := lpKey
          break
        } else {
          SendLog(LOG_LEVEL_WARNING, Format("Failed to read Leave Preview key for instance {1}, trying to read from {2} instead of {3}", idx, optionsFile, standardSettingsFile))
          if (lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")) {
            SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
            lpKeys[idx] := lpKey
            break
          }
        }
        SendLog(LOG_LEVEL_ERROR, Format("Failed to find Leave Preview key in instance {1}, falling back to 'h'. (Checked files: {2} and {3})", idx, standardSettingsFile, optionsFile))
        lpKeys[idx] := "h"
      } else if (InStr(settings, "key_Leave Preview:key.keyboard.unknown") && wp) {
        MsgBox, Instance %idx% has no recommended hotkey set for Leave Preview. Please set it in your hotkeys and THEN press OK to continue
          SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Leave Preview key set. User was informed. (In file: {2})", idx, optionsFile))
        if (lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")) {
          resetKeys[idx] := resetKey
          SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
        } else {
          SendLog(LOG_LEVEL_ERROR, Format("No recommended World Preview mod in instance {1}. Using 'h' to avoid reset manager errors", idx))
          lpKeys[idx] := "h"
        }
      } else if (InStr(settings, "key_Leave Preview:") && wp) {
        if (lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")) {
          SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
          lpKeys[idx] := lpKey
        } else {
          SendLog(LOG_LEVEL_ERROR, Format("Failed to find Leave Preview key in instance {1}, falling back to 'h'. (In file: {2})", idx, optionsFile))
          lpKeys[idx] := "h"
        }
      } else if (atum) {
        MsgBox, No Leave Preview hotkey found even though you have the mod, something went wrong trying to find the key.
        SendLog(LOG_LEVEL_ERROR, Format("No Leave Preview hotkey found for instance {1} even though mod is installed. Using 'h' to avoid reset manager errors", idx))
        lpKeys[idx] := "h"
      } else {
        SendLog(LOG_LEVEL_ERROR, Format("No recommended World Preview mod in instance {1}. Using 'h' to avoid reset manager errors", idx))
        lpKeys[idx] := "h"
      }
      break
    }
    Loop, 1 {
      if (InStr(ssettings, "key_key.fullscreen:key.keyboard.unknown") && windowMode == "F") {
        Loop, 1 {
          MsgBox, 4, Fullscreen Key, Instance %idx% missing required hotkey for fullscreen mode: Fullscreen. Would you like to set this back to default (f11)?`n(In file: %standardSettingsFile%)
            IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_key.fullscreen:key.keyboard.unknown", "key_key.fullscreen:key.keyboard.f11")
          fsKeys[idx] := "F11"
          SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Fullscreen key set and chose to let it be automatically set to 'f11'. (In file: {2})", idx, standardSettingsFile))
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Fullscreen key set. (In file: {2})", idx, standardSettingsFile))
      } else {
        fsKey := CheckOptionsForValue(standardSettingsFile, "key_key.fullscreen", "F11")
        SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2} from {3}", fsKey, idx, standardSettingsFile))
        fsKeys[idx] := fsKey
        break
      }
    }
    Loop, 1 {
      if (InStr(ssettings, "key_key.command:key.keyboard.unknown")) {
        Loop, 1 {
          MsgBox, 4, Command Key, Instance %idx% missing recommended command hotkey. Would you like to set this back to default (/)?`n(In file: %standardSettingsFile%)
          IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_key.command:key.keyboard.unknown", "key_key.command:key.keyboard.slash")
          commandkeys[idx] := "/"
          SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no command key set and chose to let it be automatically set to '/'. (In file: {2})", idx, standardSettingsFile))
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no command key set. (In file: {2})", idx, standardSettingsFile))
      } else {
        commandkey := CheckOptionsForValue(standardSettingsFile, "key_key.command", "/")
        SendLog(LOG_LEVEL_INFO, Format("Found Command key: {1} for instance {2} from {3}", commandkey, idx, standardSettingsFile))
        commandkeys[idx] := commandkey
        break
      }
    }
    FileDelete, %standardSettingsFile%
    FileAppend, %ssettings%, %standardSettingsFile%
  }
  if !fastReset
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod fast-reset. Download: https://github.com/jan-leila/FastReset/releases", moddir))
  if !sleepBg
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod sleepbackground. Download: https://github.com/RedLime/SleepBackground/releases", moddir))
  if !sodium
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod sodium. Download: https://github.com/jan-leila/sodium-fabric/releases", moddir))
  if !srigt
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod SpeedRunIGT. Download: https://redlime.github.io/SpeedRunIGT/", moddir))
  FileRead, settings, %optionsFile%
  if InStr(settings, "fullscreen:true") {
    fsKey := fsKeys[idx]
    ControlSend,, {Blind}{%fsKey%}, ahk_pid %pid%
  }
  SendLog(LOG_LEVEL_INFO, Format("Finished instance verification for directory: {1}", mcdir))
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
  if (RegExMatch(fileData, "[A-Z]\w{0}:(\/|\\).+.txt", globalPath)) {
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
