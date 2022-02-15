; A Wall-Style Multi-Instance macro for Minecraft
; By Specnr
; v0.4.6

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

if (performanceMethod == "F") {
  UnsuspendAll()
  sleep, %restartDelay%
}
GetAllPIDs()
SetTitles()
FileDelete, log.log
FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Starting Wall`n, log.log
FileDelete, ATTEMPTS_DAY.txt

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
    newHeight := Floor(A_ScreenHeight / 2.5)
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

#Persistent
SetTimer, CheckScripts, 20
return

CheckScripts:
  Critical
  if (useSingleSceneOBS && needBgCheck && A_NowUTC - lastChecked > tinderCheckBuffer) {
    newBg := GetFirstBgInstance()
    if (newBg != -1) {
      FileAppend, idle found %newBg%`n, log.log
      cmd := Format("python.exe """ . A_ScriptDir . "\scripts\tinder.py"" {1} {2}", -1, newBg)
      Run, %cmd%,, Hide
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