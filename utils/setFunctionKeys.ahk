#Include, %A_ScriptDir%\..\scripts\functions.ahk
#SingleInstance, Force
#NoEnv

global instances := 0
global onIdx := 1
global shift := false

WinGet, all, list
Loop, %all%
{
  WinGet, pid, PID, % "ahk_id " all%A_Index%
  WinGetTitle, title, ahk_pid %pid%
  if (InStr(title, "Minecraft*"))
    instances++
}

MsgBox, 4, Instance Count, The script detected %instances% instances. If this is wrong press no and input how many you are running
IfMsgBox No
  InputBox, instances, How many instances, How many instances will you be running?
MsgBox, After pressing OK select the 'Switch to scene' hotkey box for instance 1 and press 'f'. Then press the '+' and press 'f' again in the newly created input box. Scroll through all your instance scenes 1 to %instances% and repeat this for all of them.

SendNextKey() {
  key := onIdx+12
  if (shift) {
    send {LShift down}
    sleep, 100
    send {Blind}{F%key% down}
    sleep, 100
    send {Blind}{F%key% up}
    sleep, 100
    send {LShift up}
    onIdx++
    shift := False
  } else {
    send {F%key% down}
    sleep, 100
    send {F%key% up}
    shift := True
  }
  if (onIdx > instances) {
    MsgBox, All done, closing script
    ExitApp
  }
}

F::SendNextKey()