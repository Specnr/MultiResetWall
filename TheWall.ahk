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
global rows := 2 ; Number of row on the wall scene
global cols := 4 ; Number of columns on the wall scene
global wideResets := True
global fullscreen := False
global disableTTS := False
global resetSounds := True ; :)
global countAttempts := True
global beforeFreezeDelay := 400 ; increase if doesnt join world
global fullScreenDelay := 100 ; increse if fullscreening issues
global obsDelay := 100 ; increase if not changing scenes in obs
global restartDelay := 200 ; increase if saying missing instanceNumber in .minecraft (and you ran setup)
global switchDelay := 85 ; increase if not switching windows
global maxLoops := 20 ; increase if macro regularly locks up
global scriptBootDelay := 6000 ; increase if instance freezes before world gen
global oldWorldsFolder := "C:\MultiInstanceMC\oldWorlds\" ; Old Worlds folder, make it whatever you want

; Don't configure these
global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global SavesDirectories := []
global instances := 0
global rawPIDs := []
global PIDs := []
global resetScriptTime := []
global resetIdx := []

UnsuspendAll()
sleep, %restartDelay%
GetAllPIDs()
SetTitles()

for i, saves in SavesDirectories {
  idle := saves . "idle.tmp"
  if (!FileExist(idle))
    FileAppend,,%idle%
  if (wideResets) {
    pid := PIDs[i]
    WinRestore, ahk_pid %pid%
    WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%A_ScreenHeight%
    newHeight := Floor(A_ScreenHeight / 2.5)
    WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
  }
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
    idleCheck := SavesDirectories[rIdx] . "idle.tmp"
    if (A_TickCount - resetScriptTime[i] > scriptBootDelay && FileExist(idleCheck)) {
      SuspendInstance(PIDs[rIdx])
      toRemove.Push(resetScriptTime[i])
    }
  }
  for i, x in toRemove {
    for j, currTime in resetScriptTime {
      if (x == currTime) {
        resetScriptTime.RemoveAt(j)
        resetIdx.RemoveAt(j)
      }
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

GetSavesDir(pid)
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

GetInstanceNumberFromSaves(saves) {
  numFile := saves . "instanceNumber.txt"
  num := -1
  if (saves == "" || saves == ".minecraft") ; Misread something
    Reload
  if (!FileExist(numFile))
    MsgBox, Missing instanceNumber.txt in %saves%
  else
    FileRead, num, %numFile%
return num
}

GetAllPIDs()
{
  global SavesDirectories
  global PIDs
  global instances := GetInstanceTotal()
  ; Generate saves and order PIDs
  Loop, %instances% {
    saves := GetSavesDir(rawPIDs[A_Index])
    if (num := GetInstanceNumberFromSaves(saves)) == -1
      ExitApp
    PIDS[num] := rawPIDs[A_Index]
    SavesDirectories[num] := saves
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

IsProcessSuspended(pid) {
  WinGetTitle, title, ahk_pid %pid%
return InStr(title, "Not Responding")
}

SwitchInstance(idx)
{
  if (idx <= instances) {
    pid := PIDs[idx]
    ResumeInstance(pid)
    WinActivate, LiveSplit
    Sleep, %switchDelay%
    WinActivate, ahk_pid %pid%
    send {Numpad%idx% down}
    sleep, %obsDelay%
    send {Numpad%idx% up}
    if (wideResets)
      WinMaximize, ahk_pid %pid%
    if (fullscreen) {
      send {F11}
      sleep, %fullScreenDelay%
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
    send, {F11}
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
  idleFile := SavesDirectories[idx] . "idle.tmp"
  if (idx <= instances && FileExist(idleFile)) {
    pid := PIDs[idx]
    ResumeInstance(pid)
    ControlSend, ahk_parent, {Blind}{Esc 2}, ahk_pid %pid%
    ; Reset
    logFile := SavesDirectories[idx] . "logs\latest.log"
    If (FileExist(idleFile))
      FileDelete, %idleFile%
    Run, reset.ahk %pid% %logFile% %maxLoops% %beforeFreezeDelay% %idleFile%
    if (resetSounds)
      SoundPlay, reset.wav
    Critical, On
    resetScriptTime.Push(A_TickCount)
    resetIdx.Push(idx)
    Critical, Off
    ; Move Worlds
    dir := SavesDirectories[idx] . "saves\"
    Loop, Files, %dir%*, D
    {
      If (InStr(A_LoopFileName, "New World") || InStr(A_LoopFileName, "Speedrun #")) {
        tmp := A_NowUTC
        FileMoveDir, %dir%%A_LoopFileName%, %dir%%A_LoopFileName%%tmp%Instance %idx%, R
        FileMoveDir, %dir%%A_LoopFileName%%tmp%Instance %idx%, %oldWorldsFolder%%A_LoopFileName%%tmp%Instance %idx%
      }
    }
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

RAlt::Suspend ; Pause all macros
LAlt:: ; Reload if macro locks up
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
    }