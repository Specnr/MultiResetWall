; v0.8

SendObsCmd(cmd) {
  FileAppend, %cmd%`n, %obsFile%
}

SendLog(lvlText, msg) {
  FileAppend, [%A_TickCount%] [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] [SYS-%lvlText%] %msg%`n, data/log.log
}

CheckOptionsForHotkey(mcdir, optionsCheck, defaultKey) {
  optionsFile := mcdir . "options.txt"
  Loop, Read, %optionsFile%
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

CountAttempts(attemptType) {
  file := "data/" . attemptType . ".txt"
  FileRead, WorldNumber, %file%
  if (ErrorLevel)
    WorldNumber = 0
  else
    FileDelete, %file%
  WorldNumber += 1
  FileAppend, %WorldNumber%, %file%
}

FindBypassInstance() {
  activeNum := GetActiveInstanceNum()
  for i, isLocked in locked {
    idle := McDirectories[i] . "idle.tmp"
    if (FileExist(idle) && isLocked && i != activeNum)
      return i
  }
  if (multiMode) {
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
  if (!useSingleSceneOBS)
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
  if !useSingleSceneOBS
    return 0
  if skip
    return -1
  activeNum := GetActiveInstanceNum()
  for i, mcdir in McDirectories {
    hold := mcdir . "hold.tmp"
    if (i != activeNum && i != toSkip && !FileExist(hold) && !locked[i]) {
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
  numFile := mcdir . "instanceNumber.txt"
  num := -1
  if (mcdir == "" || mcdir == ".minecraft" || mcdir == ".minecraft\" || mcdir == ".minecraft/") ; Misread something
    Reload
  if (!FileExist(numFile))
    MsgBox, Missing instanceNumber.txt in %mcdir%
  else
    FileRead, num, %numFile%
  return num
}

GetMcDirFromFile(idx) {
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
  instances := GetInstanceTotal()
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

SetAffinities(bg:=false, play:=0) {
  for i, mcdir in McDirectories {
    pid := PIDs[i]
    idle := mcdir . "idle.tmp"
    hold := mcdir . "hold.tmp"
    preview := mcdir . "preview.tmp"
    if (i == play) {
      SetAffinity(pid, playBitMask)
    } else if bg {
      if FileExist(idle)
        SetAffinity(pid, superLowBitMask)
      else
        SetAffinity(pid, lowBitMask)
    } else {
      if FileExist(idle)
        SetAffinity(pid, lowBitMask)
      else if locked[i]
        SetAffinity(pid, highBitMask)
      else if FileExist(hold)
        SetAffinity(pid, highBitMask)
      else if FileExist(preview)
        SetAffinity(pid, midBitMask)
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
  if (idx <= instances && FileExist(idleFile)) {
    holdFile := McDirectories[idx] . "hold.tmp"
    FileAppend,,%holdFile%
    if (useObsWebsocket) {
      prevBg := currBg
      currBg := GetFirstBgInstance(idx, skipBg)
      if (prevBg == currBg) {
        hideMini := -1
        showMini := -1
      } else {
        hideMini := prevBg
        showMini := currBg
      }
      if (useSingleSceneOBS)
        SendOBSCmd("ss-si" . " " . from . " " . idx . " " . hideMini . " " . showMini)
      Else
        SendOBSCmd("si " . idx)
    }
    FileDelete,data/instance.txt
    FileAppend,%idx%,data/instance.txt
    pid := PIDs[idx]
    SetAffinities(true, idx)
    if !locked[idx]
      LockInstance(idx, False, False)
    ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    if doF1
      ControlSend,, {Blind}{F1}, ahk_pid %pid%
    WinSet, AlwaysOnTop, On, ahk_pid %pid%
    WinSet, AlwaysOnTop, Off, ahk_pid %pid%
    WinMinimize, Fullscreen Projector
    if (widthMultiplier)
      WinMaximize, ahk_pid %pid%
    if (windowMode == "F") {
      ControlSend,, {Blind}{F11}, ahk_pid %pid%
      sleep, %fullScreenDelay%
    }
    if (coop)
      ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, ahk_pid %pid%
    Send {LButton} ; Make sure the window is activated
    if (!useObsWebsocket) {
      send {Numpad%idx% down}
      sleep, %obsDelay%
      send {Numpad%idx% up}
    }
  }
}

GetActiveInstanceNum() {
  WinGet, pid, PID, A
  WinGetTitle, title, ahk_pid %pid%
  if (InStr(title, " - ")) {
    for i, tmppid in PIDs {
      if (tmppid == pid)
        return i
    }
  }
  return -1
}

ExitWorld()
{
  if (windowMode == "F") {
    send {F11}
    sleep, %fullScreenDelay%
  }
  if (idx := GetActiveInstanceNum()) > 0
  {
    pid := PIDs[idx]
    if (widthMultiplier) {
      WinRestore, ahk_pid %pid%
      WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
    }
    nextInst := -1
    if (wallBypass || multiMode)
      nextInst := FindBypassInstance()
    if (nextInst > 0)
      SwitchInstance(nextInst, false, idx)
    else
      ToWall(idx)
    holdFile := McDirectories[idx] . "hold.tmp"
    FileDelete,%holdFile%
    if doF1
      ControlSend,, {Blind}{F1}, ahk_pid %pid%
    ResetInstance(idx)
    SetAffinities()
    isWide := False
  }
}

ResetInstance(idx) {
  holdFile := McDirectories[idx] . "hold.tmp"
  previewFile := McDirectories[idx] . "preview.tmp"
  if FileExist(previewFile)
    FileRead, previewTime, %previewFile%
  if (idx > 0 && idx <= instances && !FileExist(holdFile) && (spawnProtection + previewTime) < A_TickCount) {
    SendLog(LOG_LEVEL_INFO, Format("Inst {1} valid reset triggered", idx))
    FileAppend,,%holdFile%
    FileDelete, %previewFile%
    pid := PIDs[idx]
    rmpid := RM_PIDs[idx]
    resetKey := resetkeys[idx]
    lpKey := lpKeys[idx]
    ; Reset
    ControlSend, ahk_parent, {Blind}{%lpKey%}{%resetKey%}, ahk_pid %pid%
    DetectHiddenWindows, On
    PostMessage, MSG_RESET,,,, ahk_pid %rmpid%
    DetectHiddenWindows, Off
    if locked[idx]
      UnlockInstance(idx, false)
    ; Count Attempts
    if (countAttempts)
    {
      CountAttempts("ATTEMPTS")
      CountAttempts("ATTEMPTS_DAY")
    }
  }
}

SetTitles() {
  for i, pid in PIDs {
    WinSetTitle, ahk_pid %pid%, , Minecraft* - Instance %i%
  }
}

ToWall(comingFrom) {
  WinMaximize, Fullscreen Projector
  WinActivate, Fullscreen Projector
  if (useObsWebsocket) {
    if (useSingleSceneOBS)
      SendOBSCmd("ss-tw" . " " . comingFrom)
    Else
      SendOBSCmd("tw")
  }
  else {
    send {F12 down}
    sleep, %obsDelay%
    send {F12 up}
  }
  FileDelete,data/instance.txt
  FileAppend,0,data/instance.txt
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
  locked[idx] := true
  lockDest := McDirectories[idx] . "lock.png"
  FileCopy, A_ScriptDir\..\media\lock.png, %lockDest%, 1
  FileSetTime,,%lockDest%,M
  if (lockSounds && sound)
    SoundPlay, A_ScriptDir\..\media\lock.wav
  if (affinityChange) {
    pid := PIDs[idx]
    SetAffinity(pid, highBitMask)
  }
}

UnlockInstance(idx, sound:=true) {
  locked[idx] := false
  lockDest := McDirectories[idx] . "lock.png"
  FileCopy, A_ScriptDir\..\media\unlock.png, %lockDest%, 1
  FileSetTime,,%lockDest%,M
  if (lockSounds && sound)
    SoundPlay, A_ScriptDir\..\media\unlock.wav
}

LockAll(sound:=true) {
  loop, %instances% {
    LockInstance(A_Index, false)
  }
  if (lockSounds && sound)
    SoundPlay, A_ScriptDir\..\media\lock.wav
}

UnlockAll(sound:=true) {
  loop, %instances% {
    UnlockInstance(A_Index, false)
  }
  if (lockSounds && sound)
    SoundPlay, A_ScriptDir\..\media\unlock.wav
}

PlayNextLock(focusReset:=false, bypassLock:=false) {
  loop, %instances% {
    if locked[A_Index] {
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
  if (SubStr(RunHide("python.exe --version"), 1, 6) == "Python") {
    cmd := "python.exe """ . A_ScriptDir . "\scripts\worldBopper9000x.py"""
    RunWait,%cmd%,,Hide
    MsgBox, Completed World Bopping!
  } else {
    MsgBox, Missing Python installation. Try again after installing
  }
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

VerifyInstance(mcdir, pid) {
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
  Loop, Files, %moddir%*.jar
  {
    if InStr(A_LoopFileName, "atum")
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
    else if InStr(A_LoopFileName, "krypton") {
      SendLog(LOG_LEVEL_ERROR, Format("Directory {1} includes incompatible mod: Krypton", moddir))
      MsgBox, 4, Krypton Detected, Directory %moddir% includes incompatible mod: Krypton. Would you like to disable it and restart the instance?
      IfMsgBox No
      Continue
      FileMove, %A_LoopFileFullPath%, %A_LoopFileFullPath%.disabled
      WinClose, ahk_pid %pid%
      SendLog(LOG_LEVEL_INFO, Format("Directory {1} included incompatible mod: Krypton. Macro disabled and killed instance.", moddir))
    }
  }
  if !atum {
    SendLog(LOG_LEVEL_ERROR, Format("Directory {1} missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases", moddir))
    MsgBox, Directory %moddir% missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases
  }
  if !wp {
    SendLog(LOG_LEVEL_ERROR, Format("Directory {1} missing required mod: World Preview. Macro will likely not work. Download: https://github.com/VoidXWalker/WorldPreview/releases", moddir))
    MsgBox, Directory %moddir% missing required mod: World Preview. Macro will likely not work. Download: https://github.com/VoidXWalker/WorldPreview/releases
  }
  if !standardSettings {
    SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing highly recommended mod standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases", moddir))
    MsgBox, Directory %moddir% missing highly recommended mod: standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases
  } else {
    standardSettingsFile := mcdir . "config\standardoptions.txt"
    FileRead, ssettings, %standardSettingsFile%
    if InStr(standardSettingsFile, "fullscreen:true") {
      ssettings := StrReplace(ssettings, "fullscreen:true", "fullscreen:false")
      FileDelete, %standardSettingsFile%
      FileAppend, ssettings, %standardSettingsFile%
      SendLog(LOG_LEVEL_WARNING, Format("File {1} had fullscreen set true, macro requires it false. Automatically fixed", standardSettingsFile))
    }
    if InStr(standardSettingsFile, "pauseOnLostFocus:true") {
      ssettings := StrReplace(ssettings, "pauseOnLostFocus:true", "pauseOnLostFocus:false")
      FileDelete, %standardSettingsFile%
      FileAppend, ssettings, %standardSettingsFile%
      SendLog(LOG_LEVEL_WARNING, Format("File {1} had pauseOnLostFocus set true, macro requires it false. Automatically fixed", standardSettingsFile))
    }
    if (InStr(standardSettingsFile, "key_Create New World:key.keyboard.unknown") && atum) {
      Loop, 1 {
        MsgBox, 4, Create New World Key, File %standardSettingsFile% missing required hotkey: Create New World. Would you like to set this back to default?
        IfMsgBox No
        break
        ssettings := StrReplace(ssettings, "key_Create New World:key.keyboard.unknown", "key_Create New World:key.keyboard.f6")
        FileDelete, %standardSettingsFile%
        FileAppend, ssettings, %standardSettingsFile%
        SendLog(LOG_LEVEL_WARNING, Format("File {1} had no Create New World key set and chose to let it be automatically set to F6", standardSettingsFile))
      }
      SendLog(LOG_LEVEL_ERROR, Format("File {1} has no Create New World key set", standardSettingsFile))
    }
    if (InStr(standardSettingsFile, "key_Leave Preview:key.keyboard.unknown") && atum) {
      Loop, 1 {
        MsgBox, 4, Leave Preview Key, File %standardSettingsFile% missing recommended hotkey: Leave Preview. Would you like to set this back to default?
        IfMsgBox No
        break
        ssettings := StrReplace(ssettings, "key_Leave Preview:key.keyboard.unknown", "key_Leave Preview:key.keyboard.h")
        FileDelete, %standardSettingsFile%
        FileAppend, ssettings, %standardSettingsFile%
        SendLog(LOG_LEVEL_WARNING, Format("File {1} had no Leave Preview key set and chose to let it be automatically set to 'h'", standardSettingsFile))
      }
      SendLog(LOG_LEVEL_WARNING, Format("File {1} has no Leave Preview key set", standardSettingsFile))
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
