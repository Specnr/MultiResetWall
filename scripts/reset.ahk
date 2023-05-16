#NoEnv
#NoTrayIcon
#Include settings.ahk
#Include %A_ScriptDir%\functions.ahk
#Include %A_ScriptDir%\GlobalConstants.ahk
#SingleInstance, off

SetKeyDelay, 0
SetBatchLines, -1

global idx := A_Args[1]
global pid := A_Args[2]
global doubleCheckUnexpectedLoads := A_Args[3]
global mainPID := A_Args[4]
global mcDir := A_Args[5]
global rmPID := GetScriptPID()

global idleFile := Format("{1}idle.tmp", mcDir)
global holdFile := Format("{1}hold.tmp", mcDir)
global previewFile := Format("{1}preview.tmp", mcDir)
global lockFile := Format("{1}lock.tmp", mcDir)
global wpStateFile := Format("{1}wpstateout.txt", mcDir)

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

global covered := false
global state := "unknown"
global previewLoaded := true

FileDelete, %holdFile%
FileDelete, %killFile%
SendLog(LOG_LEVEL_INFO, Format("Instance {1} reset manager started: {2} {3} {4} {5} {6} {7} {8} {9} {10} {11} {12} {13}", idx, pid, idleFile, holdFile, previewFile, lockFile, playBitMask, lockBitMask, highBitMask, midBitMask, lowBitMask, bgLoadBitMask, doubleCheckUnexpectedLoads))

DetectHiddenWindows, On
; PostMessage, MSG_CONFIRM_RM, idx,,, % Format("ahk_pid {1}", mainPID)
; PostMessage, MSG_TEST, PREVIEW_FOUND, A_TickCount,, % Format("ahk_pid {1}", mainPID)
; PostMessage, MSG_TEST_RESET, StrLen(mcDir), &mcDir,, % Format("ahk_pid {1}", mainPID)
PostMessage, MSG_ASSIGN_RMPID, idx, rmPID,, % Format("ahk_pid {1}", mainPID)
DetectHiddenWindows, Off

OnMessage(MSG_KILL, "Kill")
OnMessage(MSG_RESET, "ResetSound")

SetTimer, CheckMain, 5000

Kill() {
    Critical, On
    SetAffinity(pid, GetBitMask(THREAD_COUNT))
    ExitApp
}

ResetSound() {
    if (sounds == "A" || sounds == "F" || sounds == "R") {
        SoundPlay, A_ScriptDir\..\media\reset.wav
        if obsResetMediaKey {
            send {%obsResetMediaKey% down}
            sleep, %obsDelay%
            send {%obsResetMediaKey% up}
        }
    }
}

ManageReset() {
    state := "starting"
    prevAffinityState := "starting"
    ManageThisAffinity()
    SendLog(LOG_LEVEL_INFO, Format("Instance {1} starting reset management", idx))
    while (True) {
        sleep, %resetManagementLoopDelay%
        FileRead, wpState, %wpStateFile%
        ; title
        ; waiting
        ; generating,%
        ; previewing,%
        ; inworld,unpaused/paused/gamescreenopen
        if (inStr(wpState, "previewing")) {
            if (state == "resetting") {
                SetTimer, Pause, -%beforePauseDelay%
            }
            if (covered) {
                covered := false
                SendOBSCmd(Format("Cover,0,{1}", idx))
            }

            perc := StrSplit(wpState, ",")[2]
            if (perc < previewLoadPercent) {
                state := "pre-preview"
                if (prevAffinityState != state) {
                    ManageThisAffinity()
                    prevAffinityState := state
                    FileDelete, %holdFile%
                    FileDelete, %previewFile%
                    FileAppend, %A_TickCount%, %previewFile%
                }
            } else if (state == "pre-preview") {
                state := "preview"
                if (prevAffinityState != state) {
                    ManageThisAffinity()
                    prevAffinityState := state
                }
            }
        } else if (inStr(wpState, "inworld")) {
            inworldState := StrSplit(wpState, ",")[2]
            if (state != "idle" && inworldState == "unpaused") {
                SetTimer, Pause, -%beforePauseDelay%
            }
            state := "idle"
            if (prevAffinityState != state) {
                ManageThisAffinity()
                prevAffinityState := state
                FileDelete, %holdFile%
                FileDelete, %idleFile%
                FileAppend, %A_TickCount%, %idleFile%
                if !FileExist(previewFile)
                    FileAppend, %A_TickCount%, %previewFile%
            }
        } else {
            state := "resetting"
            covered := true
            FileDelete, %previewFile%
            FileDelete, %idleFile%
            if (prevAffinityState != state) {
                ManageThisAffinity()
                prevAffinityState := state
            }
        }
    }
}

ManageThisAffinity() {
    FileRead, activeInstance, data/instance.txt
    if (idx == activeInstance) { ; this is active instance
        SetAffinity(pid, playBitMask)
    } else if activeInstance { ; there is another active instance
        if (state != "idle") { ; if loading
            SetAffinity(pid, bgLoadBitMask)
        } else {
            SetAffinity(pid, lowBitMask)
        }
    } else { ; there is no active instance
        if FileExist(lockFile) ; if locked
            SetAffinity(pid, lockBitMask)
        else if (state == "resetting") ; if resetting
            SetAffinity(pid, highBitMask)
        else if (state == "pre-preview") ; if preview gen not reached
            SetAffinity(pid, midBitMask)
        else if (state == "preview") ; if preview gen reached
            SetAffinity(pid, lowBitMask)
        else if (state == "idle") ; if idle
            SetAffinity(pid, lowBitMask)
        else
            SetAffinity(pid, highBitMask)
    }
}

Pause() {
    if (state == "resetting")
        return
    ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
}

CheckMain() {
    DetectHiddenWindows, On
    if (!WinExist(Format("ahk_pid {1}", mainPID))) {
        SendLog(LOG_LEVEL_INFO, Format("rm {1} didnt find {2}, killing", idx, mainPID))
        Kill()
    }
    DetectHiddenWindows, Off
}

SetTimer, ManageReset, -%manageResetAfter%