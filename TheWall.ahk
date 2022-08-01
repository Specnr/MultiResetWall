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
global lpKeys := []

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global playThreads := playThreadsOverride > 0 ? playThreadsOverride : threadCount
global highThreads := highThreadsOverride > 0 ? highThreadsOverride : Ceil(threadCount * (.8 / affinityStrength)) < threadCount ? Ceil(threadCount * (.8 / affinityStrength)) : threadCount
global midThreads := midThreadsOverride > 0 ? midThreadsOverride : Ceil(threadCount * (.75 / affinityStrength)) < threadCount ? Ceil(threadCount * (.75 / affinityStrength)) : threadCount
global lowThreads := lowThreadsOverride > 0 ? lowThreadsOverride : Ceil(threadCount * (.35 / affinityStrength)) < threadCount ? Ceil(threadCount * (.35 / affinityStrength)) : threadCount
global superLowThreads := superLowThreadsOverride > 0 ? superLowThreadsOverride : Ceil(threadCount * (.1 / affinityStrength)) < threadCount ? Ceil(threadCount * (.1 / affinityStrength)) : threadCount

global playBitMask := GetBitMask(playThreads)
global highBitMask := GetBitMask(highThreads)
global midBitMask := GetBitMask(midThreads)
global lowBitMask := GetBitMask(lowThreads)
global superLowBitMask := GetBitMask(superLowThreads)

global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
if (widthMultiplier)
  global newHeight := Floor(A_ScreenHeight / widthMultiplier)

global MSG_RESET := 0x04E20
global LOG_LEVEL_INFO = "INFO"
global LOG_LEVEL_WARNING = "WARN"
global LOG_LEVEL_ERROR = "ERR"
global obsFile := A_ScriptDir . "/scripts/obs.ops"

if !FileExist("data")
  FileCreateDir, data
global hasMcDirCache := FileExist("data/mcdirs.txt")

if (performanceMethod == "F") {
  UnsuspendAll()
  sleep, %restartDelay%
}
GetAllPIDs()
SetTitles()
FileDelete, %obsFile%
FileDelete, data/log.log
FileDelete, data/ATTEMPTS_DAY.txt
SendLog(LOG_LEVEL_INFO, "Starting Wall")

for i, mcdir in McDirectories {
  pid := PIDs[i]
  logs := mcdir . "logs\latest.log"
  idle := mcdir . "idle.tmp"
  hold := mcdir . "hold.tmp"
  preview := mcdir . "preview.tmp"
  VerifyInstance(mcdir, pid)
  resetKey := CheckOptionsForHotkey(mcdir, "key_Create New World", "F6")
  SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2}", resetKey, i))
  resetkeys[i] := resetKey
  lpKey := CheckOptionsForHotkey(mcdir, "key_Leave Preview", "h")
  SendLog(LOG_LEVEL_INFO, Format("Found leave preview key: {1} for instance {2}", lpKey, i))
  lpKeys[i] := lpKey
  Run, %A_ScriptDir%\scripts\reset.ahk %pid% %logs% %idle% %hold% %preview% %resetKey% %lpKey% %i% %highBitMask% %midBitMask% %lowBitMask% %superLowBitMask%, %A_ScriptDir%,, rmpid
  DetectHiddenWindows, On
  WinWait, ahk_pid %rmpid%
  DetectHiddenWindows, Off
  RM_PIDs[i] := rmpid
  UnlockInstance(i, False)
  if (!FileExist(idle))
    FileAppend, %A_TickCount%, %idle%
  if FileExist(hold)
    FileDelete, %hold%
  if FileExist(preview)
    FileDelete, %preview%
  if (windowMode == "B") {
    WinSet, Style, -0xC00000, ahk_pid %pid%
    WinSet, Style, -0x40000, ahk_pid %pid%
    WinSet, ExStyle, -0x00000200, ahk_pid %pid%
  }
  if (widthMultiplier) {
    pid := PIDs[i]
    WinRestore, ahk_pid %pid%
    WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
  }
  WinSet, AlwaysOnTop, Off, ahk_pid %pid%
}

if affinity {
  for i, tmppid in PIDs {
    SetAffinity(tmppid, highBitMask)
  }
}

if audioGui {
  Gui, New
  Gui, Show,, The Wall Audio
}

Menu, Tray, Add, Close Instances, CloseInstances

if (useObsWebsocket) {
  WinWait, OBS
  if (useSingleSceneOBS) {
    lastInst := -1
    if FileExist("data/instance.txt")
      FileRead, lastInst, data/instance.txt
    SendOBSCmd("ss-tw" . " " .lastInst)
    cmd := "python.exe """ . A_ScriptDir . "\scripts\obsListener.py"" " . instances . " " . "True"
  }
  else {
    SendOBSCmd("tw")
    cmd := "python.exe """ . A_ScriptDir . "\scripts\obsListener.py"" " . instances . " " . "False"
  }
  Run, %cmd%,, Hide
}

if (!disableTTS)
  ComObjCreate("SAPI.SpVoice").Speak("Ready")

#Persistent
OnExit, ExitSub
SetTimer, CheckScripts, 20
return

ExitSub:
  if A_ExitReason not in Logoff,Shutdown
  {
    SendOBSCmd("xx")
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
      SendOBSCmd("tm -1" . " " . newBg)
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
