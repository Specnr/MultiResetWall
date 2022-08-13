#Include, %A_ScriptDir%\..\scripts\functions.ahk
#SingleInstance, Force
#NoEnv

global instances := 0
global onIdx := 1

WinGet, all, list
Loop, %all%
{
  WinGet, pid, PID, % "ahk_id " all%A_Index%
  WinGetTitle, title, ahk_pid %pid%
  if (InStr(title, "Minecraft*"))
    instances++
}

SendNextKey() {
  key := onIdx+12
  send {F%key% down}
  sleep, 100
  send {F%key% up}
  if (onIdx > instances)
    ExitApp
  onIdx++
}

F::SendNextKey()