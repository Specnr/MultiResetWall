#Include, %A_ScriptDir%\..\scripts\functions.ahk
#SingleInstance, Force
#NoEnv

path := A_ScriptDir . "\..\data\mcdirs.txt"
if !FileExist(path) {
  MsgBox, Missing cache, you need to run TheWall.ahk with all instances open at least once before using this script.
  ExitApp
}

Loop, Read, %path%
{
  savesDir := StrSplit(A_LoopReadLine, "~")[2] . "saves\"
  Loop, %savesDir%*.*, 2 {
    if (InStr(A_LoopFileName, "New World") || InStr(A_LoopFileName, "Speedrun #"))
      FileRemoveDir, %A_LoopFileLongPath%, 1
  }
}