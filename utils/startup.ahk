#SingleInstance, Force
#NoEnv

path := A_ScriptDir . "\..\data\mmc.txt"
Loop, Read, %path%
{
  mmc := A_LoopReadLine
}

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
  instName := StrSplit(StrSplit(A_LoopReadLine, "instances\")[2], "\.minecraft")[1]
  cmd := mmc . "MultiMC.exe -l " . instName
  if doOffline {
    name := names[A_Index]
    cmd .= " -o -n " . name
  }
  Run,%cmd%,,Hide
}
