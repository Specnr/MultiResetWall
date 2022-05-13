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

; Variables to configure
global rows := 3 ; Number of row on the wall scene
global cols := 3 ; Number of columns on the wall scene
global instanceFreezing := True ; Set to False to reduce crashing, but strongly increase lag
global wideResets := True
global fullscreen := False
global disableTTS := False
global resetSounds := True ; :)
global countAttempts := True
global resumeDelay := 50 ; increase if instance isnt resetting (or have to press reset twice)
global beforeFreezeDelay := 500 ; increase if doesnt join world
global fullScreenDelay := 270 ; increse if fullscreening issues
global obsDelay := 100 ; increase if not changing scenes in obs
global restartDelay := 200 ; increase if saying missing instanceNumber in .minecraft (and you ran setup)
global maxLoops := 20 ; increase if macro regularly locks up
global scriptBootDelay := 6000 ; increase if instance freezes before world gen

; Preset settings variables to configure
; If you want to reset a certain setting you can set it here. (Leaving it blank or as 0 will not affect your settings)
; Some sensitivity values may not work because of how Minecrafts settings bars work with arrow keys
global renderDistance :=
global FOV :=
global mouseSensitivity :=

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
global obsOpsToBePushed := ""
global lastCheckedObs := A_NowUTC

if (performanceMethod == "F") {
  UnsuspendAll()
  sleep, %restartDelay%
}
GetAllPIDs()
SetTitles()
FileDelete, log.log
FileDelete, obs.ops
FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Starting Wall`n, log.log
FileDelete, ATTEMPTS_DAY.txt

if (useObsWebsocket) {
  if (useSingleSceneOBS) {
    lastInst := -1
    if FileExist("instance.txt")
      FileRead, lastInst, instance.txt
    obsOpsToBePushed .= "ss-tw " . lastInst . "`n"
  }
  else
    obsOpsToBePushed .= "tw`n"
  cmd := "python.exe """ . A_ScriptDir . "\scripts\obsListener.py"""
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

#Persistent
OnExit, ExitSub
SetTimer, CheckScripts, 20
return

ExitSub:
  if A_ExitReason not in Logoff,Shutdown
  {
    FileAppend, xx, obs.ops
  }
ExitApp

CheckScripts:
  Critical
  if (useObsWebsocket && StrLen(obsOpsToBePushed) > 0 && A_NowUTC - lastCheckedObs > 0.5) {
    FileAppend, %obsOpsToBePushed%, obs.ops
    obsOpsToBePushed := ""
  }
  if (useSingleSceneOBS && needBgCheck && A_NowUTC - lastChecked > tinderCheckBuffer) {
    newBg := GetFirstBgInstance()
    if (newBg != -1) {
      FileAppend, idle found %newBg%`n, log.log
      obsOpsToBePushed .= "tm -1 " . newBg . "`n"
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
