; A Multi-Instance macro for Minecraft ResetInstance
; A publicly avalable version of "The Wall" made by jojoe77777
; By Specnr
;
#NoEnv
#SingleInstance Force

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2

; Variables to configure
global rows := 3 ; Number of row on the wall scene
global cols := 3 ; Number of columns on the wall scene
global wideResets := True
global fullscreen := False
global disableTTS := False
global resetSounds := True ; :)
global countAttempts := True
global beforeFreezeDelay := 400 ; increase if doesnt join world
global fullScreenDelay := 270 ; increse if fullscreening issues
global obsDelay := 100 ; increase if not changing scenes in obs
global restartDelay := 200 ; increase if saying missing instanceNumber in .minecraft (and you ran setup)
global maxLoops := 20 ; increase if macro regularly locks up
global scriptBootDelay := 6000 ; increase if instance freezes before world gen

; Don't configure these
global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global McDirectories := []
global instances := 0
global rawPIDs := []
global PIDs := []
global resetScriptTime := []
global resetIdx := []

UnsuspendAll()
sleep, %restartDelay%
GetAllPIDs()
SetTitles()

for i, mcdir in McDirectories {
  idle := mcdir . "idle.tmp"
  if (!FileExist(idle))
    FileAppend,,%idle%
  if (wideResets) {
    pid := PIDs[i]
    WinRestore, ahk_pid %pid%
    WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%A_ScreenHeight%
    newHeight := Floor(A_ScreenHeight / 2.5)
    WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
  }
  WinSet, AlwaysOnTop, Off, ahk_pid %pid%
}

IfNotExist, %oldWorldsFolder%
  FileCreateDir %oldWorldsFolder%
if (!disableTTS)
  ComObjCreate("SAPI.SpVoice").Speak("Ready")

#Persistent
SetTimer, CheckScripts, 20
return

CheckScripts:
  Critical
  toRemove := []
  for i, rIdx in resetIdx {
    idleCheck := McDirectories[rIdx] . "idle.tmp"
    if (A_TickCount - resetScriptTime[i] > scriptBootDelay && FileExist(idleCheck)) {
      SuspendInstance(PIDs[rIdx])
      toRemove.Push(resetScriptTime[i])
    }
  }
  for i, x in toRemove {
    idx := resetScriptTime.Length()
    while (idx) {
      resetTime := resetScriptTime[idx]
      if (x == resetTime) {
        resetScriptTime.RemoveAt(idx)
        resetIdx.RemoveAt(idx)
      }
      idx--
    }
  }
return

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
  if (mcdir == "" || mcdir == ".minecraft") ; Misread something
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
    DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
    DllCall("CloseHandle", "Int", hProcess)
  }
}

SwitchInstance(idx)
{
  if (idx <= instances) {
    pid := PIDs[idx]
    ResumeInstance(pid)
    WinMinimize, Fullscreen Projector
    WinSet, AlwaysOnTop, On, ahk_pid %pid%
    WinSet, AlwaysOnTop, Off, ahk_pid %pid%
    send {Numpad%idx% down}
    sleep, %obsDelay%
    send {Numpad%idx% up}
    if (wideResets)
      WinMaximize, ahk_pid %pid%
    if (fullscreen) {
      ControlSend, ahk_parent, {Blind}{F11}, ahk_pid %pid%
      sleep, %fullScreenDelay%
    }
    send {LButton} ; Make sure the window is activated
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
      newHeight := Floor(A_ScreenHeight / 2.5)
      WinRestore, ahk_pid %pid%
      WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
    }
    ControlSend, ahk_parent, {Blind}{Esc}, ahk_pid %pid%
    ToWall()
    ResetInstance(idx)
  }
}

ResetInstance(idx) {
  idleFile := McDirectories[idx] . "idle.tmp"
  if (idx <= instances && FileExist(idleFile)) {
    pid := PIDs[idx]
    ResumeInstance(pid)
    ControlSend, ahk_parent, {Blind}{Esc 2}, ahk_pid %pid%
    ; Reset
    logFile := McDirectories[idx] . "logs\latest.log"
    If (FileExist(idleFile))
      FileDelete, %idleFile%
    Run, reset.ahk %pid% %logFile% %maxLoops% %beforeFreezeDelay% %idleFile%
    if (resetSounds)
      SoundPlay, reset.wav
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
    }
  }
}

SetTitles() {
  for i, pid in PIDs {
    WinSetTitle, ahk_pid %pid%, , Minecraft* - Instance %i%
  }
}

ToWall() {
  WinActivate, Fullscreen Projector
  send {F12 down}
  sleep, %obsDelay%
  send {F12 up}
}

; Focus hovered instance and background reset all other instances
FocusReset(focusInstance) {
  SwitchInstance(focusInstance)
  loop, %instances% {
    if (A_Index != focusInstance) {
      ResetInstance(A_Index)
    }
  }
}

; Reset all instances
ResetAll() {
  loop, %instances% {
    ResetInstance(A_Index)
  }
}

RAlt::Suspend ; Pause all macros
^LAlt:: ; Reload if macro locks up
  Reload
return
#IfWinActive, Minecraft
  {
    *U:: ExitWorld() ; Reset
  }
return

#IfWinActive, Fullscreen Projector
  {
    *E::ResetInstance(MousePosToInstNumber())
    *R::SwitchInstance(MousePosToInstNumber())
    *F::FocusReset(MousePosToInstNumber())
    *T::ResetAll()

    ; Reset keys (1-9)
    *1::
      ResetInstance(1)
    return
    *2::
      ResetInstance(2)
    return
    *3::
      ResetInstance(3)
    return
    *4::
      ResetInstance(4)
    return
    *5::
      ResetInstance(5)
    return
    *6::
      ResetInstance(6)
    return
    *7::
      ResetInstance(7)
    return
    *8::
      ResetInstance(8)
    return
    *9::
      ResetInstance(9)
    return

    ; Switch to instance keys (Shift + 1-9)
    *+1::
      SwitchInstance(1)
    return
    *+2::
      SwitchInstance(2)
    return
    *+3::
      SwitchInstance(3)
    return
    *+4::
      SwitchInstance(4)
    return
    *+5::
      SwitchInstance(5)
    return
    *+6::
      SwitchInstance(6)
    return
    *+7::
      SwitchInstance(7)
    return
    *+8::
      SwitchInstance(8)
    return
    *+9::
      SwitchInstance(9)
    return
  }