; A Wall-Style Multi-Instance macro for Minecraft
; By Specnr and Machliah

#NoEnv
#Persistent
#SingleInstance Force
#Include %A_ScriptDir%\scripts\functions.ahk
#Include %A_ScriptDir%\scripts\Instance.ahk
#Include %A_ScriptDir%\scripts\GlobalConstants.ahk
#Include settings.ahk

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2
SetBatchLines, -1
Thread, NoTimers , True

global playThreads := playThreadsOverride > 0 ? playThreadsOverride : THREAD_COUNT ; total threads unless override
global lockThreads := lockThreadsOverride > 0 ? lockThreadsOverride : THREAD_COUNT ; total threads unless override
global highThreads := highThreadsOverride > 0 ? highThreadsOverride : affinityType != "N" ? Ceil(THREAD_COUNT * 0.95) : THREAD_COUNT ; 95% or 2 less than max threads, whichever is higher unless override or none
global midThreads := midThreadsOverride > 0 ? midThreadsOverride : affinityType == "A" ? Ceil(THREAD_COUNT * 0.8) : highThreads ; 80% if advanced otherwise high unless override
global lowThreads := lowThreadsOverride > 0 ? lowThreadsOverride : affinityType != "N" ? Ceil(THREAD_COUNT * 0.7) : THREAD_COUNT ; 70% if advanced otherwise high unless override
global bgLoadThreads := bgLoadThreadsOverride > 0 ? bgLoadThreadsOverride : affinityType != "N" ? Ceil(THREAD_COUNT * 0.4) : THREAD_COUNT ; 40% unless override or none

global playBitMask := GetBitMask(playThreads)
global lockBitMask := GetBitMask(lockThreads)
global highBitMask := GetBitMask(highThreads)
global midBitMask := GetBitMask(midThreads)
global lowBitMask := GetBitMask(lowThreads)
global bgLoadBitMask := GetBitMask(bgLoadThreads)

global instances := []
global mainPID := GetScriptPID()

FileDelete, data/log.log

SendLog(LOG_LEVEL_INFO, "Starting MultiResetWall v1.2")

OnMessage(MSG_CONFIRM_RM, "ConfirmRM")
OnMessage(MSG_ASSIGN_RMPID, "AssignResetManagerPID")

CheckAHKVersion()

CreateInstanceArray()

SetTheme(theme)

CheckOBSPython()

UnlockAll(false)

CheckLaunchAudioGUI()

CheckOBSRunLevel()

BindTrayIconFunctions()

SendOBSCmd(GetCoverTypeObsCmd("Cover",false, instances))

ToWall(0)

FileAppend,,data/macro.reload
SendLog(LOG_LEVEL_INFO, "Wall setup done")
if (!disableTTS)
  ComObjCreate("SAPI.SpVoice").Speak(readyTTS)

OnExit("Shutdown")

#Include hotkeys.ahk