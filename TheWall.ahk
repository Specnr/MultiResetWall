; A Wall-Style Multi-Instance macro for Minecraft
; By Specnr
; v0.8

#NoEnv
#SingleInstance Force
#Include %A_ScriptDir%\scripts\functions.ahk
#Include settings.ahk

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2

; Don't configure these
EnvGet, threadCount, NUMBER_OF_PROCESSORS
global McDirectories := []
global instances := 0
global rawPIDs := []
global PIDs := []
global RM_PIDs := []
global resetScriptTime := []
global resetIdx := []
global locked := []
global needBgCheck := False
global currBg := GetFirstBgInstance()
global lastChecked := A_NowUTC
global resetKeys := []
global highBitMask := (2 ** threadCount) - 1
global lowBitMask := (2 ** Ceil(threadCount * lowBitmaskMultiplier)) - 1
global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)

global MSG_RESET := 0x04E20
global LOG_LEVEL_INFO = "INFO"
global LOG_LEVEL_WARNING = "WARN"
global LOG_LEVEL_ERROR = "ERR"
global obsFile := A_ScriptDir . "/scripts/obs.ops"

if (performanceMethod == "F") {
  UnsuspendAll()
  sleep, %restartDelay%
}
GetAllPIDs()
SetTitles()
FileDelete, log.log
FileDelete, %obsFile%
FileDelete, ATTEMPTS_DAY.txt
SendLog(LOG_LEVEL_INFO, "Starting Wall")

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
  pid := PIDs[i]
  logs := mcdir . "logs\latest.log"
  idle := mcdir . "idle.tmp"
  hold := mcdir . "hold.tmp"
  preview := mcdir . "preview.tmp"
  resetKey := CheckOptionsForHotkey(mcdir, "key_Create New World", "F6")
  SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2}", resetKey, i))
  resetkeys[i] := resetKey
  Run, %A_ScriptDir%\scripts\reset.ahk %pid% %logs% %idle% %hold% %preview% %resetKey%, %A_ScriptDir%,, rmpid
  DetectHiddenWindows, On
  WinWait, ahk_pid %rmpid%
  DetectHiddenWindows, Off
  RM_PIDs[i] := rmpid
  UnlockInstance(i, False)
  if (!FileExist(idle))
    FileAppend,,%idle%
  if FileExist(hold)
    FileDelete, %hold%
  if FileExist(preview)
    FileDelete, %preview%
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

#Persistent
OnExit, ExitSub
SetTimer, CheckScripts, 20
return

ExitSub:
  if A_ExitReason not in Logoff,Shutdown
  {
    FileAppend, xx, %obsFile%
    DetectHiddenWindows, On
    rms := RM_PIDs.MaxIndex()
    loop, %rms% {
      pid := RM_PIDs[A_Index]
      WinClose, ahk_pid %pid%
    }
    DetectHiddenWindows, Off
  }
ExitApp

CheckScripts:
  Critical
  if (useSingleSceneOBS && needBgCheck && A_NowUTC - lastChecked > tinderCheckBuffer) {
    newBg := GetFirstBgInstance()
    if (newBg != -1) {
      SendLog(LOG_LEVEL_INFO, Format("Instance {1} was found and will be used with tinder", newBg))
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