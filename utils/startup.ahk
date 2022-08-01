#SingleInstance, Force
#NoEnv

if !WinExist("MultiMC") {
  MsgBox, Open MultiMC and try again
  ExitApp
}

path := A_ScriptDir . "\..\data\mmc.txt"
Loop, Read, %path%
{
  mmc := A_LoopReadLine
}

path := A_ScriptDir . "\..\data\mcdirs.txt"
Loop, Read, %path%
{
  instName := StrSplit(StrSplit(A_LoopReadLine, "instances\")[2], "\.minecraft")[1]
  cmd := mmc . "MultiMC.exe -l " . instName
  Run,%cmd%,,Hide
}
