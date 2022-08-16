; v0.8

SendObsCmd(cmd) {
  FileAppend, %cmd%`n, %obsFile%
}

SendLog(lvlText, msg) {
  FileAppend, [%A_TickCount%] [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] [SYS-%lvlText%] %msg%`n, data/log.log
}

CheckOptionsForHotkey(file, optionsCheck, defaultKey) {
  Loop, Read, %file%
  {
    if (InStr(A_LoopReadLine, optionsCheck)) {
      split := StrSplit(A_LoopReadLine, ":")
      if (split.MaxIndex() == 2)
        return keyArray[split[2]]
      SendLog(LOG_LEVEL_ERROR, Format("Couldn't parse options correctly, defaulting to '{1}'. Line: {2}", defaultKey, A_LoopReadLine))
      return defaultKey
    }
  }
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

FindBypassInstance() {
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

TinderMotion(swipeLeft) {
  ; left = reset, right = keep
  if (obsControl != "S")
    return
  if (swipeLeft)
    ResetInstance(currBg)
  else
    LockInstance(currBg)
  newBg := GetFirstBgInstance(currBg)
  SendLog(LOG_LEVEL_INFO, Format("Tinder motion occurred with old instance {1} and new instance {2}", currBg, newBg))
  SendOBSCmd("tm" . " " . currBg . " " . newBg)
  currBg := newBg
}

GetFirstBgInstance(toSkip := -1, skip := false) {
  if obsControl != "S"
    return 0
  if skip
    return -1
  activeNum := GetActiveInstanceNum()
  for i, mcdir in McDirectories {
    hold := mcdir . "hold.tmp"
    if (i != activeNum && i != toSkip && !FileExist(hold) && !locked[i]) {
      FileDelete,data/bg.txt
      FileAppend,%i%,data/bg.txt
      return i
    }
  }
  needBgCheck := true
  return -1
}

MousePosToInstNumber() {
  MouseGetPos, mX, mY
  return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
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
  SendLog(LOG_LEVEL_INFO, Format("Getting mcdir from pid: {1}", pid))
  command := Format("powershell.exe $x = Get-WmiObject Win32_Process -Filter \""ProcessId = {1}\""; $x.CommandLine", pid)
  rawOut := RunHide(command)
  if (InStr(rawOut, "--gameDir")) {
    strStart := RegExMatch(rawOut, "P)--gameDir (?:""(.+?)""|([^\s]+))", strLen, 1)
    return SubStr(rawOut, strStart+10, strLen-10) . "\"
  } else {
    strStart := RegExMatch(rawOut, "P)(?:-Djava\.library\.path=(.+?) )|(?:\""-Djava\.library.path=(.+?)\"")", strLen, 1)
    if (SubStr(rawOut, strStart+20, 1) == "=") {
      strLen -= 1
      strStart += 1
    }
    return StrReplace(SubStr(rawOut, strStart+20, strLen-28) . ".minecraft\", "/", "\")
  }
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
  SendLog(LOG_LEVEL_INFO, Format("Getting PID from mcdir: {1}", mcdir))
  for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath like ""%jdk%javaw.exe%""") {
    if ((pid := CheckOnePIDFromMcDir(proc, mcdir)) != -1)
      return pid
  }
  ; Broader search if some people use java.exe or some other edge cases
  for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath like ""%java%""") {
    if ((pid := CheckOnePIDFromMcDir(proc, mcdir)) != -1)
      return pid
  }
  return -1
}

GetInstanceTotal() {
  SendLog(LOG_LEVEL_INFO, "Getting instance total")
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

GetInstanceNumberFromMcDir(mcdir) {
  SendLog(LOG_LEVEL_INFO, Format("Getting instance number from mcdir: {1}", mcdir))
  numFile := mcdir . "instanceNumber.txt"
  num := -1
  if (mcdir == "" || mcdir == ".minecraft" || mcdir == ".minecraft\" || mcdir == ".minecraft/") { ; Misread something
    FileDelete, data/mcdirs.txt
    Reload
  }
  if (!FileExist(numFile)) {
    InputBox, num, Missing instanceNumber.txt, Missing instanceNumber.txt in:`n%mcdir%`nplease type the instance number and select "OK"
    FileAppend, %num%, %numFile%
    SendLog(LOG_LEVEL_WARNING, Format("Instance {1} instanceNumber.txt was missing but was corrected by user", num))
  } else {
    FileRead, num, %numFile%
    if (!num || num > instances) {
      InputBox, num, Bad instanceNumber.txt, Error in instanceNumber.txt in:`n%mcdir%`nplease type the instance number and select "OK"
      FileDelete, %numFile%
      FileAppend, %num%, %numFile%
      SendLog(LOG_LEVEL_WARNING, Format("Instance {1} instanceNumber.txt contained either a number too high or nothing but was corrected by user", num))
    }
  }
  return num
}

GetMcDirFromFile(idx) {
  SendLog(LOG_LEVEL_INFO, Format("Getting mcdir from cache for {1}", idx))
  Loop, Read, data/mcdirs.txt
  {
    split := StrSplit(A_LoopReadLine,"~")
    if (idx == split[1]) {
      mcdir := split[2]
      StringReplace,mcdir,mcdir,`n,,A
      return mcdir
    }
  }
}

GetAllPIDs()
{
  SendLog(LOG_LEVEL_INFO, "Getting all PIDs")
  instances := GetInstanceTotal()
  SendLog(LOG_LEVEL_INFO, Format("Instance total is {1}", instances))
  ; If there are more/less instances than usual, rebuild cache
  if hasMcDirCache && GetLineCount("data/mcdirs.txt") != instances {
    FileDelete,data/mcdirs.txt
    hasMcDirCache := False
  }
  ; Generate mcdir and order PIDs
  Loop, %instances% {
    if hasMcDirCache
      mcdir := GetMcDirFromFile(A_Index)
    else
      mcdir := GetMcDir(rawPIDs[A_Index])
    if (num := GetInstanceNumberFromMcDir(mcdir)) == -1
      ExitApp
    if !hasMcDirCache {
      FileAppend,%num%~%mcdir%`n,data/mcdirs.txt
      PIDs[num] := rawPIDs[A_Index]
    } else {
      PIDs[num] := GetPIDFromMcDir(mcdir)
    }
    McDirectories[num] := mcdir
  }
}

SetAffinities(idx:=0) {
  for i, mcdir in McDirectories {
    pid := PIDs[i]
    idle := mcdir . "idle.tmp"
    hold := mcdir . "hold.tmp"
    preview := mcdir . "preview.tmp"
    if (idx == i) { ; this is active instance
      SetAffinity(pid, superHighBitMask)
    } else if idx { ; there is another active instance
      if !FileExist(idle)
        SetAffinity(pid, bgLoadBitMask)
      else
        SetAffinity(pid, lowBitMask)
    } else { ; there is no active instance
      if FileExist(idle)
        SetAffinity(pid, lowBitMask)
      else if locked[i]
        SetAffinity(pid, superHighBitMask)
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

SwitchInstance(idx, skipBg:=false, from:=-1)
{
  idleFile := McDirectories[idx] . "idle.tmp"
  if (idx <= instances && (FileExist(idleFile) || mode == "C")) {
    holdFile := McDirectories[idx] . "hold.tmp"
    FileAppend,,%holdFile%
    killFile := McDirectories[idx] . "kill.tmp"
    FileAppend,,%killFile%
    FileDelete,data/instance.txt
    FileAppend,%idx%,data/instance.txt
    if (obsControl == "S") {
      prevBg := currBg
      currBg := GetFirstBgInstance(idx, skipBg)
      if (prevBg == currBg) {
        hideMini := -1
        showMini := -1
      } else {
        hideMini := prevBg
        showMini := currBg
      }
      SendOBSCmd("ss-si" . " " . from . " " . idx . " " . hideMini . " " . showMini)
    }
    pid := PIDs[idx]
    SetAffinities(idx)
    if !locked[idx]
      LockInstance(idx, False, False)
    ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    if f1States[idx]
      ControlSend,, {Blind}{F1}, ahk_pid %pid%
    if (widthMultiplier)
      WinMaximize, ahk_pid %pid%
    WinSet, AlwaysOnTop, On, ahk_pid %pid%
    WinSet, AlwaysOnTop, Off, ahk_pid %pid%
    WinMinimize, Fullscreen Projector
    if (windowMode == "F") {
      fsKey := fsKeys[idx]
      ControlSend,, {Blind}{%fsKey%}, ahk_pid %pid%
      sleep, %fullScreenDelay%
    }
    if (coop)
      ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, ahk_pid %pid%
    Send {LButton} ; Make sure the window is activated
    if (obsControl == "H") {
      if (obsSceneControlType == "N")
        obsKey := "Numpad" . idx
      else if (obsSceneControlType == "F")
        obsKey := "F" . (idx+12)
      Send {%obsKey% down}
      Sleep, %obsDelay%
      Send {%obsKey% up}
    }
  } else {
    if !locked[idx]
      LockInstance(idx, False)
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

ExitWorld()
{
  idx := GetActiveInstanceNum()
  pid := PIDs[idx]
  if (windowMode == "F") {
    fsKey := fsKeys[idx]
    ControlSend,, {Blind}{%fsKey%}, ahk_pid %pid%
    sleep, %fullScreenDelay%
  }
  if (idx > 0)
  {
    holdFile := McDirectories[idx] . "hold.tmp"
    killFile := McDirectories[idx] . "kill.tmp"
    FileDelete,%holdFile%
    FileDelete, %killFile%
    if (widthMultiplier) {
      WinRestore, ahk_pid %pid%
      WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
    }
    ControlSend,, {Blind}{F3}, ahk_pid %pid%
    nextInst := -1
    if (mode == "C") {
      nextInst := Mod(idx, instances) + 1
    } else if (mode == "B" || mode == "M")
    nextInst := FindBypassInstance()
    if (nextInst > 0)
      SwitchInstance(nextInst, false, idx)
    else
      ToWall(idx)
    SetAffinities()
    ResetInstance(idx)
    isWide := False
  }
}

ResetInstance(idx, bypassLock:=true) {
  holdFile := McDirectories[idx] . "hold.tmp"
  previewFile := McDirectories[idx] . "preview.tmp"
  FileRead, previewTime, %previewFile%
  if (idx > 0 && idx <= instances && !FileExist(holdFile) && (spawnProtection + previewTime) < A_TickCount && ((!bypassLock && !locked[idx]) || bypassLock)) {
    SendLog(LOG_LEVEL_INFO, Format("Instance {1} valid reset triggered", idx))
    pid := PIDs[idx]
    rmpid := RM_PIDs[idx]
    resetKey := resetKeys[idx]
    lpKey := lpKeys[idx]
    ControlSend, ahk_parent, {Blind}{%lpKey%}{%resetKey%}, ahk_pid %pid%
    DetectHiddenWindows, On
    PostMessage, MSG_RESET,,,, ahk_pid %rmpid%
    DetectHiddenWindows, Off
    if locked[idx]
      UnlockInstance(idx, false)
    resets++
  }
}

SetTitles() {
  for i, pid in PIDs {
    name := StrReplace(minecraftWindowNaming, "#", i)
    WinSetTitle, ahk_pid %pid%, , %name%
  }
}

ToWall(comingFrom) {
  FileDelete,data/instance.txt
  FileAppend,0,data/instance.txt
  WinMaximize, Fullscreen Projector
  WinActivate, Fullscreen Projector
  if (obsControl == "S")
    SendOBSCmd("ss-tw" . " " . comingFrom)
  else if (obsControl == "H") {
    send {%obsWallSceneKey% down}
    sleep, %obsDelay%
    send {%obsWallSceneKey% up}
  }
}

FocusReset(focusInstance, bypassLock:=false) {
  if bypassLock
    UnlockAll(false)
  SwitchInstance(focusInstance, true)
  loop, %instances% {
    if (A_Index = focusInstance || locked[A_Index])
      Continue
    ResetInstance(A_Index)
  }
  if !locked[focusInstance]
    LockInstance(focusInstance, false)
  needBgCheck := true
}

; Reset all instances
ResetAll(bypassLock:=false) {
  if bypassLock
    UnlockAll(false)
  loop, %instances% {
    if locked[A_Index]
      Continue
    ResetInstance(A_Index)
  }
}

LockInstance(idx, sound:=true, affinityChange:=true) {
  if (!idx || (idx > rows * cols))
    return
  locked[idx] := true
  lockDest := McDirectories[idx] . "lock.png"
  FileCopy, A_ScriptDir\..\media\lock.png, %lockDest%, 1
  FileSetTime,,%lockDest%,M
  lockDest := McDirectories[idx] . "lock.tmp"
  FileAppend,, %lockDest%
  if (lockSounds && sound) {
    SoundPlay, A_ScriptDir\..\media\lock.wav
    if obsLockMediaKey {
      send {%obsLockMediaKey% down}
      sleep, %obsDelay%
      send {%obsLockMediaKey% up}
    }
  }
  if affinityChange {
    pid := PIDs[idx]
    SetAffinity(pid, superHighBitMask)
  }
}

UnlockInstance(idx, sound:=true) {
  if (!idx || (idx > rows * cols))
    return
  locked[idx] := false
  lockDest := McDirectories[idx] . "lock.png"
  FileCopy, A_ScriptDir\..\media\unlock.png, %lockDest%, 1
  FileSetTime,,%lockDest%,M
  lockDest := McDirectories[idx] . "lock.tmp"
  FileDelete, %lockDest%
  if (lockSounds && sound) {
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
  if (lockSounds && sound) {
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
  if (lockSounds && sound) {
    SoundPlay, A_ScriptDir\..\media\unlock.wav
    if obsUnlockMediaKey {
      send {%obsUnlockMediaKey% down}
      sleep, %obsDelay%
      send {%obsUnlockMediaKey% up}
    }
  }
}

PlayNextLock(focusReset:=false, bypassLock:=false) {
  loop, %instances% {
    if (locked[A_Index] && FileExist(McDirectories[A_Index] . "idle.tmp")) {
      if focusReset
        FocusReset(A_Index, bypassLock)
      else
        SwitchInstance(A_Index)
      return
    }
  }
}

WorldBop() {
  MsgBox, 4, Delete Worlds?, Are you sure you want to delete all of your worlds?
  IfMsgBox No
  Return
  cmd := "python.exe """ . A_ScriptDir . "\scripts\worldBopper9000x.py"""
  RunWait,%cmd%,,Hide
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

GetLineCount(file) {
  lineNum := 0
  Loop, Read, %file%
    lineNum := A_Index
  return lineNum
}

SetTheme(theme) {
  SendLog(LOG_LEVEL_INFO, Format("Setting macro theme to {1}", theme))
  Loop, Files, %A_ScriptDir%\themes\%theme%\*
  {
    fileDest := A_ScriptDir . "\media\" . A_LoopFileName
    FileCopy, %A_LoopFileFullPath%, %fileDest%, 1
    FileSetTime,,%fileDest%,M
    SendLog(LOG_LEVEL_INFO, Format("Copying file {1} to {2}", A_LoopFileFullPath, fileDest))
  }
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
  SendLog(LOG_LEVEL_INFO, Format("Starting instance verification for directory: {1}", mcdir))
  FileRead, settings, %optionsFile%
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
    SendLog(LOG_LEVEL_ERROR, Format("Directory {1} missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases", moddir))
    MsgBox, Directory %moddir% missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases
  }
  if !wp {
    SendLog(LOG_LEVEL_ERROR, Format("Directory {1} missing recommended mod: World Preview. Macro will likely not work. Download: https://github.com/VoidXWalker/WorldPreview/releases", moddir))
    MsgBox, Directory %moddir% missing recommended mod: World Preview. Macro will likely not work. Download: https://github.com/VoidXWalker/WorldPreview/releases
  }
  if !standardSettings {
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing highly recommended mod standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases", moddir))
    MsgBox, Directory %moddir% missing highly recommended mod: standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases
    if InStr(settings, "pauseOnLostFocus:true") {
      MsgBox, Instance %idx% has required disabled setting pauseOnLostFocus enabled. Please disable it with f3+p and THEN press OK to continue
      SendLog(LOG_LEVEL_WARNING, Format("File {1} had pauseOnLostFocus set true, macro requires it false. User was informed", optionsFile))
    }
    if (InStr(settings, "key_Create New World:key.keyboard.unknown") && atum) {
      MsgBox, Instance %idx% missing required hotkey: Create New World. Please set it in your hotkeys and THEN press OK to continue
      SendLog(LOG_LEVEL_ERROR, Format("File {1} had no Create New World key set. User was informed", optionsFile))
      resetKey := CheckOptionsForHotkey(optionsFile, "key_Create New World", "F6")
      SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
    } else if (atum) {
      resetKey := CheckOptionsForHotkey(optionsFile, "key_Create New World", "F6")
      SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
      resetKeys[idx] := resetKey
    }
    if (InStr(settings, "key_Leave Preview:key.keyboard.unknown") && wp) {
      MsgBox, Instance %idx% missing highly recommended hotkey: Leave Preview. Please set it in your hotkeys and THEN press OK to continue
      SendLog(LOG_LEVEL_WARNING, Format("File {1} had no Leave Preview key set. User was informed", optionsFile))
      lpKey := CheckOptionsForHotkey(optionsFile, "key_Leave Preview", "h")
      SendLog(LOG_LEVEL_INFO, Format("Found leave preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
      lpkeys[idx] := lpKey
    } else if (wp) {
      lpKey := CheckOptionsForHotkey(optionsFile, "key_Leave Preview", "h")
      SendLog(LOG_LEVEL_INFO, Format("Found leave preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
      lpkeys[idx] := lpKey
    }
    if (InStr(settings, "key_key.fullscreen:key.keyboard.unknown") && windowMode == "F") {
      MsgBox, Instance %idx% missing required hotkey for fullscreen mode: Fullscreen. Please set it in your hotkeys and THEN press OK to continue
        SendLog(LOG_LEVEL_ERROR, Format("File {1} had no Fullscreen key set. User was informed", optionsFile))
      fsKey := CheckOptionsForHotkey(optionsFile, "key_key.fullscreen", "F11")
      SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2} from {3}", fsKey, idx, optionsFile))
      fsKeys[idx] := fsKey
    } else if (windowMode == "F") {
      fsKey := CheckOptionsForHotkey(optionsFile, "key_key.fullscreen", "F11")
      SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2} from {3}", fsKey, idx, optionsFile))
      fsKeys[idx] := fsKey
    }
    f1States[idx] := false
  } else {
    standardSettingsFile := mcdir . "config\standardoptions.txt"
    FileRead, ssettings, %standardSettingsFile%
    if (RegExMatch(ssettings, "[A-Z]\w{0}:(\/|\\).+.txt")) {
      standardSettingsFile := ssettings
      SendLog(LOG_LEVEL_INFO, Format("Global standard options file detected, rereading standard options from {1}", standardSettingsFile))
      FileRead, ssettings, %standardSettingsFile%
    }
    if InStr(ssettings, "fullscreen:true") {
      ssettings := StrReplace(ssettings, "fullscreen:true", "fullscreen:false")
      FileDelete, %standardSettingsFile%
      FileAppend, %ssettings%, %standardSettingsFile%
      SendLog(LOG_LEVEL_WARNING, Format("File {1} had fullscreen set true, macro requires it false. Automatically fixed", standardSettingsFile))
    }
    if InStr(ssettings, "pauseOnLostFocus:true") {
      ssettings := StrReplace(ssettings, "pauseOnLostFocus:true", "pauseOnLostFocus:false")
      FileDelete, %standardSettingsFile%
      FileAppend, %ssettings%, %standardSettingsFile%
      SendLog(LOG_LEVEL_WARNING, Format("File {1} had pauseOnLostFocus set true, macro requires it false. Automatically fixed", standardSettingsFile))
    }
    if InStr(ssettings, "f1:true") {
      SendLog(LOG_LEVEL_INFO, Format("Instance {1} using f1 toggle found in file {2}", idx, standardSettingsFile))
      f1States[idx] := true
    } else {
      f1States[idx] := false
    }
    Loop, 1 {
      if (InStr(ssettings, "key_Create New World:key.keyboard.unknown") && atum) {
        Loop, 1 {
          MsgBox, 4, Create New World Key, File %standardSettingsFile% has no Create New World hotkey set. Would you like to set this back to default (F6)?
          IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_Create New World:key.keyboard.unknown", "key_Create New World:key.keyboard.f6")
          FileDelete, %standardSettingsFile%
          FileAppend, %ssettings%, %standardSettingsFile%
          resetKeys[idx] := "F6"
          SendLog(LOG_LEVEL_WARNING, Format("File {1} had no Create New World key set and chose to let it be automatically set to f6", standardSettingsFile))
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("File {1} has no Create New World key set", standardSettingsFile))
      } else if (InStr(settings, "key_Create New World:key.keyboard.unknown") && atum) {
        Loop, 1 {
          MsgBox, Instance %idx% has no required hotkey set for Create New World. Please set it in your hotkeys and THEN press OK to continue
            SendLog(LOG_LEVEL_ERROR, Format("File {1} had no Create New World key set. User was informed", optionsFile))
          resetKey := CheckOptionsForHotkey(optionsFile, "key_Create New World", "F6")
          SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
          resetKeys[idx] := resetKey
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("File {1} has no Create New World key set", optionsFile))
      } else if (InStr(ssettings, "key_Create New World:") && atum) {
        resetKey := CheckOptionsForHotkey(standardSettingsFile, "key_Create New World", "F6")
        if resetKey {
          SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, standardSettingsFile))
          resetKeys[idx] := resetKey
          break
        } else {
          SendLog(LOG_LEVEL_WARNING, Format("Failed to read reset key from {1} instance {2}, trying to read from options.txt", standardSettingsFile, idx))
          resetKey := CheckOptionsForHotkey(optionsFile, "key_Create New World", "F6")
          if resetKey {
            SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
            resetKeys[idx] := resetKey
            break
          } else {
            SendLog(LOG_LEVEL_ERROR, Format("Failed find reset key in {1} and {2}, falling back to 'F6'", standardSettingsFile, optionsFile))
            resetKeys[idx] := "F6"
            break
          }
        }
      } else if (InStr(settings, "key_Create New World:") && atum) {
        resetKey := CheckOptionsForHotkey(optionsFile, "key_Create New World", "F6")
        if resetKey {
          SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
          resetKeys[idx] := resetKey
          break
        } else {
          SendLog(LOG_LEVEL_ERROR, Format("Failed find reset key in {1}, falling back to 'F6'", optionsFile))
          resetKeys[idx] := "F6"
          break
        }
      } else if (atum) {
        MsgBox, No Create New World hotkey found even though you have the mod, you likely have an outdated version. Please update to version 1.1.0+
        SendLog(LOG_LEVEL_ERROR, Format("No Create New World hotkey found for instance {1} even though mod is installed. Using 'f6' to avoid reset manager errors", idx))
        resetKeys[idx] := "F6"
        break
      } else {
        SendLog(LOG_LEVEL_ERROR, Format("No required atum mod in instance {1}. Using 'f6' to avoid reset manager errors", idx))
        resetKeys[idx] := "F6"
        break
      }
    }
    Loop, 1 {
      if (InStr(ssettings, "key_Leave Preview:key.keyboard.unknown") && wp) {
        Loop, 1 {
          MsgBox, 4, Leave Preview Key, File %standardSettingsFile% has no Leave Preview hotkey set. Would you like to set this back to default (h)?
          IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_Leave Preview:key.keyboard.unknown", "key_Leave Preview:key.keyboard.h")
          FileDelete, %standardSettingsFile%
          FileAppend, %ssettings%, %standardSettingsFile%
          lpKeys[idx] := "h"
          SendLog(LOG_LEVEL_WARNING, Format("File {1} had no Leave Preview key set and chose to let it be automatically set to 'h'", standardSettingsFile))
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("File {1} has no Leave Preview key set", standardSettingsFile))
      } else if (InStr(settings, "key_Leave Preview:key.keyboard.unknown") && wp) {
        Loop, 1 {
          MsgBox, Instance %idx% has no recommended hotkey set for Leave Preview. Please set it in your hotkeys and THEN press OK to continue
            SendLog(LOG_LEVEL_ERROR, Format("File {1} had no Leave Preview key set. User was informed", optionsFile))
          lpKey := CheckOptionsForHotkey(optionsFile, "key_Leave Preview", "h")
          SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
          lpKeys[idx] := lpKey
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("File {1} has no Leave Preview key set", optionsFile))
      } else if (InStr(ssettings, "key_Leave Preview:") && wp) {
        lpKey := CheckOptionsForHotkey(standardSettingsFile, "key_Leave Preview", "h")
        if lpKey {
          SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, standardSettingsFile))
          lpKeys[idx] := lpKey
          break
        } else {
          SendLog(LOG_LEVEL_WARNING, Format("Failed to read Leave Preview key from {1} instance {2}, trying to read from options.txt", standardSettingsFile, idx))
          lpKey := CheckOptionsForHotkey(optionsFile, "key_Leave Preview", "h")
          if lpKey {
            SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
            lpKeys[idx] := lpKey
            break
          } else {
            SendLog(LOG_LEVEL_ERROR, Format("Failed find Leave Preview key in {1} and {2}, falling back to 'h'", standardSettingsFile, optionsFile))
            lpKeys[idx] := "h"
            break
          }
        }
      } else if (InStr(settings, "key_Leave Preview:") && wp) {
        lpKey := CheckOptionsForHotkey(optionsFile, "key_Leave Preview", "h")
        if lpKey {
          SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
          lpKeys[idx] := lpKey
          break
        } else {
          SendLog(LOG_LEVEL_ERROR, Format("Failed find Leave Preview key in {1}, falling back to 'h'", optionsFile))
          lpKeys[idx] := "h"
          break
        }
      } else if (wp) {
        MsgBox, No Leave Preview hotkey found even though you have the mod, something went wrong trying to find the key.
        SendLog(LOG_LEVEL_ERROR, Format("No Leave Preview hotkey found for instance {1} even though mod is installed. Using 'h' to avoid reset manager errors", idx))
        lpKeys[idx] := "h"
        break
      } else {
        SendLog(LOG_LEVEL_ERROR, Format("No recommended World Preview mod in instance {1}. Using 'h' to avoid reset manager errors", idx))
        lpKeys[idx] := "h"
        break
      }
    }
    Loop, 1 {
      if (InStr(ssettings, "key_key.fullscreen:key.keyboard.unknown") && windowMode == "F") {
        Loop, 1 {
          MsgBox, 4, Fullscreen Key, File %standardSettingsFile% missing required hotkey for fullscreen mode: Fullscreen. Would you like to set this back to default (f11)?
            IfMsgBox No
          break
          ssettings := StrReplace(ssettings, "key_key.fullscreen:key.keyboard.unknown", "key_key.fullscreen:key.keyboard.f11")
          FileDelete, %standardSettingsFile%
          FileAppend, %ssettings%, %standardSettingsFile%
          fsKeys[idx] := "F11"
          SendLog(LOG_LEVEL_WARNING, Format("File {1} had no Fullscreen key set and chose to let it be automatically set to 'f11'", standardSettingsFile))
          break 2
        }
        SendLog(LOG_LEVEL_ERROR, Format("File {1} has no Fullscreen key set", standardSettingsFile))
      } else {
        fsKey := CheckOptionsForHotkey(standardSettingsFile, "key_key.fullscreen", "F11")
        SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2}", fsKey, idx))
        fsKeys[idx] := fsKey
        break
      }
    }
  }
  if !fastReset
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod fast-reset. Download: https://github.com/jan-leila/FastReset/releases", moddir))
  if !sleepBg
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod sleepbackground. Download: https://github.com/RedLime/SleepBackground/releases", moddir))
  if !sodium
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod sodium. Download: https://github.com/jan-leila/sodium-fabric/releases", moddir))
  if !srigt
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod SpeedRunIGT. Download: https://redlime.github.io/SpeedRunIGT/", moddir))
  FileRead, options, %optionsFile%
  if InStr(options, "fullscreen:true")
    ControlSend,, {Blind}{F11}, ahk_pid %pid%
  SendLog(LOG_LEVEL_INFO, Format("Finished instance verification for directory: {1}", mcdir))
}

WideHardo() {
  idx := GetActiveInstanceNum()
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
  Send, {Esc}
  Send, {ShiftDown}{Tab 3}{Enter}{Tab}{ShiftUp}
  Send, {Enter}{Tab}{Enter}
  Send, {/}
  Sleep, 100
  Send, gamemode
  Send, {Space}
  Send, creative
  Send, {Enter}
}

GoToNether() {
  Send, {/}
  Sleep, 100
  Send, setblock
  Send, {Space}{~}{Space}{~}{Space}{~}{Space}
  Send, minecraft:nether_portal
  Send, {Enter}
}

OpenToLANAndGoToNether() {
  OpenToLAN()
  GoToNether()
}

CheckFor(struct, x := "", z := "") {
  Send, {/}
  Sleep, 100
  if (z != "" && x != "") {
    Send, execute
    Send, {Space}
    Send, positioned
    Send, {Space}
    Send, %x%
    Send, {Space}{0}{Space}
    Send, %z%
    Send, {Space}
    Send, run
    Send, {Space}
  }
  Send, locate
  Send, {Space}
  Send, %struct%
  Send, {Enter}
}

CheckFourQuadrants(struct) {
  CheckFor(struct, "1", "1")
  CheckFor(struct, "-1", "1")
  CheckFor(struct, "1", "-1")
  CheckFor(struct, "-1", "-1")
}

; Shoutout peej
global keyArray := Object("key.keyboard.f1", "F1"
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