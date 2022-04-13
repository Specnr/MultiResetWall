; v0.4.11
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
  FileAppend, new:%newBg% old:%currBg%`n, log.log
  obsOpsToBePushed .= "tm " . currBg . " " . newBg . "`n"
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
    x := !FileExist(hold)
    y := locked[i]
    FileAppend, idx:%i% active:%activeNum% skip:%toSkip% hold:%x% lock:%y%`n, log.log
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

GetInstanceTotal() {
  idx := 1
  global rawPIDs
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

GetAllPIDs()
{
  global McDirectories
  global PIDs
  global instances := GetInstanceTotal()
  ; Generate mcdir and order PIDs
  Loop, %instances% {
    mcdir := GetMcDir(rawPIDs[A_Index])
    if (num := GetInstanceNumberFromMcDir(mcdir)) == -1
      ExitApp
    PIDS[num] := rawPIDs[A_Index]
    McDirectories[num] := mcdir
  }
}

SetAffinity(pid, mask) {
  hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
  DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
  DllCall("CloseHandle", "Ptr", hProc)
}

FreeMemory(pid)
{
  h:=DllCall("OpenProcess", "UInt", 0x001F0FFF, "Int", 0, "Int", pid)
  DllCall("SetProcessWorkingSetSize", "UInt", h, "Int", -1, "Int", -1)
  DllCall("CloseHandle", "Int", h)
}

UnsuspendAll() {
  WinGet, all, list
  Loop, %all%
  {
    WinGet, pid, PID, % "ahk_id " all%A_Index%
    WinGetTitle, title, ahk_pid %pid%
    if (InStr(title, "Minecraft*"))
      ResumeInstance(pid)
  }
}

SuspendInstance(pid) {
  hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
  If (hProcess) {
    DllCall("ntdll.dll\NtSuspendProcess", "Int", hProcess)
    DllCall("CloseHandle", "Int", hProcess)
  }
  FreeMemory(pid)
}

ResumeInstance(pid) {
  hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
  If (hProcess) {
    sleep, %resumeDelay%
    DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
    DllCall("CloseHandle", "Int", hProcess)
  }
}

SwitchInstance(idx, skipBg:=false, from:=-1)
{
  idleFile := McDirectories[idx] . "idle.tmp"
  if (idx <= instances && FileExist(idleFile)) {
    FileDelete,instance.txt
    FileAppend,%idx%,instance.txt
    locked[idx] := true
    if (useObsWebsocket) {
      prevBg := currBg
      currBg := GetFirstBgInstance(idx, skipBg)
      FileAppend, prevBg:%prevBg% currBg:%currBg%`n, log.log
      if (prevBg == currBg) {
        hideMini := -1
        showMini := -1
      } else {
        hideMini := prevBg
        showMini := currBg
      }
      if (useSingleSceneOBS)
        obsOpsToBePushed .= "ss-si " . from . " " . idx . " " . hideMini . " " . showMini . "`n"
      Else
        obsOpsToBePushed .= "si " . idx . "`n"
    }
    pid := PIDs[idx]
    if (affinity) {
      for i, tmppid in PIDs {
        if (tmppid != pid){
          SetAffinity(tmppid, lowBitMask)
        }
      }
    }
    if (performanceMethod == "F")
      ResumeInstance(pid)
    else if (performanceMethod == "S") {
      ControlSend,, {Blind}{Esc}, ahk_pid %pid%
      sleep, %settingsDelay%
      ResetSettings(pid, renderDistance, true)
      ControlSend,, {Blind}{F3 Down}{D}{F3 Up}, ahk_pid %pid%
    }
    WinSet, AlwaysOnTop, On, ahk_pid %pid%
    WinSet, AlwaysOnTop, Off, ahk_pid %pid%
    WinMinimize, Fullscreen Projector
    if (wideResets)
      WinMaximize, ahk_pid %pid%
    if (fullscreen) {
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
  if (fullscreen) {
    send {F11}
    sleep, %fullScreenDelay%
  }
  if (idx := GetActiveInstanceNum()) > 0
  {
    pid := PIDs[idx]
    if (wideResets) {
      newHeight := Floor(A_ScreenHeight / widthMultiplier)
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
    if (performanceMethod == "S")
      ResetSettings(pid, lowRender, false)
    else
      ResetSettings(pid, renderDistance)
    ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    ResetInstance(idx)
    if (affinity) {
      for i, tmppid in PIDs {
        SetAffinity(tmppid, highBitMask)
      }
    }
  }
}

ResetInstance(idx) {
  holdFile := McDirectories[idx] . "hold.tmp"
  if (idx > 0 && idx <= instances && !FileExist(holdFile)) {
    FileAppend,,%holdFile%
    idleFile := McDirectories[idx] . "idle.tmp"
    killFile := McDirectories[idx] . "kill.tmp"
    FileAppend,,%killFile%
    locked[idx] := false
    pid := PIDs[idx]
    if (performanceMethod == "F") {
      bfd := beforeFreezeDelay
      ResumeInstance(pid)
    } else {
      bfd := 0
    }
    ControlSend,, {Blind}{Esc 2}, ahk_pid %pid%
    ; Reset
    logFile := McDirectories[idx] . "logs\latest.log"
    If (FileExist(idleFile))
      FileDelete, %idleFile%
    Run, %A_ScriptDir%\scripts\reset.ahk %pid% %logFile% %maxLoops% %bfd% %idleFile% %beforePauseDelay% %resetSounds% %killFile% %holdFile% %worldPreviewResetKey% %worldPreviewFreezeKey% %freezePreviewAfter%
    Critical, On
    resetScriptTime.Push(A_TickCount)
    resetIdx.Push(idx)
    Critical, Off
    ; Count Attempts
    if (countAttempts)
    {
      FileRead, WorldNumber, ATTEMPTS.txt
      if (ErrorLevel)
        WorldNumber = 0
      else
        FileDelete, ATTEMPTS.txt
      WorldNumber += 1
      FileAppend, %WorldNumber%, ATTEMPTS.txt
      FileRead, WorldNumber, ATTEMPTS_DAY.txt
      if (ErrorLevel)
        WorldNumber = 0
      else
        FileDelete, ATTEMPTS_DAY.txt
      WorldNumber += 1
      FileAppend, %WorldNumber%, ATTEMPTS_DAY.txt
    }
  }
}

SetTitles() {
  for i, pid in PIDs {
    WinSetTitle, ahk_pid %pid%, , Minecraft* - Instance %i%
  }
}

ToWall(comingFrom) {
  WinActivate, Fullscreen Projector
  Send, {LWin 2}
  if (useObsWebsocket) {
    if (useSingleSceneOBS)
      obsOpsToBePushed .= "ss-tw " . comingFrom . "`n"
    Else
      obsOpsToBePushed .= "tw`n"
  }
  else {
    send {F12 down}
    sleep, %obsDelay%
    send {F12 up}
  }
}

; Focus hovered instance and background reset all other instances
FocusReset(focusInstance) {
  SwitchInstance(focusInstance, true)
  loop, %instances% {
    if (A_Index != focusInstance && !locked[A_Index]) {
      ResetInstance(A_Index)
    }
  }
  needBgCheck := true
}

; Reset all instances
ResetAll() {
  loop, %instances% {
    if (!locked[A_Index])
      ResetInstance(A_Index)
  }
}

LockInstance(idx) {
  locked[idx] := true
  if (lockSounds)
    SoundPlay, A_ScriptDir\..\media\lock.wav
}

; Reset your settings to preset settings preferences
ResetSettings(pid, rd, justRD:=false)
{
  ; Find required presses to set FOV, sensitivity, and render distance
  if (rd)
  {
    RDPresses := rd-2
    ; Reset then preset render distance to custom value with f3 shortcuts
    ControlSend,, {Blind}{Shift down}{F3 down}{F 32}{F3 up}{Shift up}, ahk_pid %pid%
    ControlSend,, {Blind}{F3 down}{F %RDPresses%}{F3 up}, ahk_pid %pid%
  }
  if (FOV && !justRD)
  {
    FOVPresses := ceil((FOV-30)*1.763)
    ; Tab to FOV
    ControlSend,, {Blind}{Esc}{Tab 6}{enter}{Tab}, ahk_pid %pid%
    ; Reset then preset FOV to custom value with arrow keys
    ControlSend,, {Blind}{Left 151}, ahk_pid %pid%
    ControlSend,, {Blind}{Right %FOVPresses%}{Esc}, ahk_pid %pid%
  }
  if (mouseSensitivity && !justRD)
  {
    SensPresses := ceil(mouseSensitivity/1.408)
    ; Tab to mouse sensitivity
    ControlSend,, {Blind}{Esc}{Tab 6}{enter}{Tab 7}{enter}{tab}{enter}{tab}, ahk_pid %pid%
    ; Reset then preset mouse sensitivity to custom value with arrow keys
    ControlSend,, {Blind}{Left 146}, ahk_pid %pid%
    ControlSend,, {Blind}{Right %SensPresses%}{Esc 3}, ahk_pid %pid%
  }
}
