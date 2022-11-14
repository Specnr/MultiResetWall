; v1.0

#Include, %A_ScriptDir%\..\scripts\functions.ahk
#SingleInstance, Force
#NoEnv

path := A_ScriptDir . "\..\data\mcdirs.txt"
if !FileExist(path) {
  MsgBox, Missing cache, you need to run TheWall.ahk with all instances open at least once before using this script.
  ExitApp
}

FileReadLine, dirData, %path%, 1
mmc := StrSplit(StrSplit(dirData, "instances\")[1], "~")[2]

if !WinExist("MultiMC") {
  launchMmc := mmc . "MultiMC.exe"
  Run,%launchMmc%
  Sleep, 2000
}

namesPath := A_ScriptDir . "\..\data\names.txt"
doOffline := FileExist(namesPath)
names := []
if doOffline {
  Loop, Read, %namesPath%
  {
    names.Push(A_LoopReadLine)
  }
}

path := A_ScriptDir . "\..\data\mcdirs.txt"
Loop, Read, %path%
{
  mcdir := StrSplit(A_LoopReadLine, "~")[2]
  idx := StrSplit(A_LoopReadLine, "~")[1]
  if (GetPIDFromMcDir(mcdir) != -1)
    continue
  instName := StrSplit(StrSplit(A_LoopReadLine, "instances\")[2], "\.minecraft")[1]
  cmd := mmc . "MultiMC.exe -l """ . instName . """"
  if doOffline {
    name := names[idx]
    cmd .= " -o -n """ . name . """"
  }
  Run,%cmd%,,Hide
  Sleep, 300
}