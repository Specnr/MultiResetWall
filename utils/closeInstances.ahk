#SingleInstance, Force
#NoEnv

WinGet, all, list
Loop, %all%
{
  WinGet, pid, PID, % "ahk_id " all%A_Index%
  WinGetTitle, title, ahk_pid %pid%
  if (InStr(title, "Minecraft*")) {
    WinClose, ahk_pid %pid%
  }
}