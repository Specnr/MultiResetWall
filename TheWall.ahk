; A Wall-Style Multi-Instance macro for Minecraft
; By Specnr
; v0.5

#NoEnv
#SingleInstance Force
#Include %A_ScriptDir%\scripts\functions.ahk
#Include settings.ahk

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2

; Don't configure these
EnvGet, threadCount, NUMBER_OF_PROCESSORS
global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global McDirectories := []
global instances := 0
global rawPIDs := []
global PIDs := []
global resetScriptTime := []
global resetIdx := []
global locked := []
global highBitMask := (2 ** threadCount) - 1
global lowBitMask := (2 ** Ceil(threadCount * lowBitmaskMultiplier)) - 1
global needBgCheck := False
global currBg := GetFirstBgInstance()
global lastChecked := A_NowUTC
global obsFile := A_ScriptDir . "/scripts/obs.ops"
global liFile := A_ScriptDir . "/scripts/li.ops"

if (performanceMethod == "F") {
  UnsuspendAll()
  sleep, %restartDelay%
}
GetAllPIDs()
SetTitles()
FileDelete, log.log
FileDelete, %obsFile%
if lockIndicators
  FileDelete, %liFile%
FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Starting Wall`n, log.log
FileDelete, ATTEMPTS_DAY.txt

if (useObsWebsocket) {
  if (useSingleSceneOBS) {
    lastInst := -1
    if FileExist("instance.txt")
      FileRead, lastInst, instance.txt
    FileAppend, ss-tw %lastInst%`n, %obsFile%
  }
  else
    FileAppend, tw`n, %obsFile%
  cmd := "python.exe """ . A_ScriptDir . "\scripts\obsListener.py"" " . instances
  Run, %cmd%,, Hide
}

for i, mcdir in McDirectories {
  idle := mcdir . "idle.tmp"
  hold := mcdir . "hold.tmp"
  kill := mcdir . "kill.tmp"
  locked[i] := False
  if (!FileExist(idle))
    FileAppend,,%idle%
  if FileExist(hold)
    FileDelete, %hold%
  if FileExist(kill)
    FileDelete, %kill%
  if (wideResets) {
    pid := PIDs[i]
    WinRestore, ahk_pid %pid%
    WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%A_ScreenHeight%
    newHeight := Floor(A_ScreenHeight / widthMultiplier)
    WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
  }
  WinSet, AlwaysOnTop, Off, ahk_pid %pid%
}

if (affinity) {
  for i, tmppid in PIDs {
    SetAffinity(tmppid, highBitMask)
  }
}

if (!disableTTS)
  ComObjCreate("SAPI.SpVoice").Speak("Ready")

if audioGui {
  Gui, New
  Gui, Show,, The Wall Audio
}

if (lockIndicators && useObsWebsocket) {
  FileAppend, li u a`n, %liFile%
}

#Persistent
OnExit, ExitSub
SetTimer, CheckScripts, 20
return

ExitSub:
  if A_ExitReason not in Logoff,Shutdown
  {
    FileAppend, xx, %obsFile%
  }
ExitApp

CheckScripts:
  Critical
  if (useSingleSceneOBS && needBgCheck && A_NowUTC - lastChecked > tinderCheckBuffer) {
    newBg := GetFirstBgInstance()
    if (newBg != -1) {
      FileAppend, idle found %newBg%`n, log.log
      FileAppend, tm -1 %newBg%`n, %obsFile%
      needBgCheck := False
      currBg := newBg
    }
    lastChecked := A_NowUTC
  }
  if (performanceMethod == "F") {
    toRemove := []
    for i, rIdx in resetIdx {
      idleCheck := McDirectories[rIdx] . "idle.tmp"
      if (FileExist(idleCheck)) {
        if (performanceMethod == "F" && A_TickCount - resetScriptTime[i] > scriptBootDelay) {
          SuspendInstance(PIDs[rIdx])
          toRemove.Push(resetScriptTime[i])
        }
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
  }
return

#Include hotkeys.ahk