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

MsgBox, 4, Instance Count, The script detected %instances% instances, if this is wrong press no and double check all your instances are open
IfMsgBox No
  ExitApp
MsgBox, After pressing OK scroll through your OBS hotkeys and in order from 1 to %instances% select the Switch to scene hotkey box and press 'f' for all of them.

SendNextKey() {
  key := onIdx+12
  send {F%key% down}
  sleep, 100
  send {F%key% up}
  if (onIdx == instances) {
    MsgBox, All done, closing script
    ExitApp
  }
  onIdx++
}

F::SendNextKey()