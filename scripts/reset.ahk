; v0.8

#NoEnv
#NoTrayIcon
#Include settings.ahk
#Include %A_ScriptDir%\functions.ahk
#SingleInstance, off

SetKeyDelay, 0

global MSG_RESET := 0x04E20
global LOG_LEVEL_INFO = "INFO"
global LOG_LEVEL_WARNING = "WARN"
global LOG_LEVEL_ERROR = "ERR"

global pid := A_Args[1]
global logFile := A_Args[2]
global idleFile := A_Args[3]
global holdFile := A_Args[4]
global previewFile := A_Args[5]
global lockFile := A_Args[6]
global killFile := A_Args[7]
global resetKey := A_Args[8]
global lpKey := A_Args[9]
global idx := A_Args[10]
global superHighBitMask := A_Args[11]
global highBitMask := A_Args[12]
global midBitMask := A_Args[13]
global lowBitMask := A_Args[14]
global idleBitMask := A_Args[15]
global bgLoadBitMask := A_Args[16]

global state := "unknown"
global lastImportantLine := GetLineCount(logFile)

SendLog(LOG_LEVEL_INFO, Format("Instance {1} reset manager started: {2} {3} {4} {5} {6} {7} {8} {9} {10} {11} {12} {13} {14} {15} {16}", idx, pid, logFile, idleFile, holdFile, previewFile, lockFile, killFile, resetKey, lpKey, superHighBitMask, highBitMask, midBitMask, lowBitMask, idleBitMask, bgLoadBitMask))

OnMessage(MSG_RESET, "Reset")

Reset() {
  if ((state == "resetting" && mode != "C") || state == "kill" || FileExist(killFile)) {
    SendLog(LOG_LEVEL_INFO, Format("Instance {1} discarding reset management, state: {2}", idx, state))
    return
  }
  state := "kill"
  FileAppend,, %holdFile%
  FileDelete, %previewFile%
  FileDelete, %idleFile%
  lastImportantLine := GetLineCount(logFile)
  SetTimer, ManageReset, -%manageResetAfter%
  if FileExist("data/instance.txt")
    FileRead, activeInstance, data/instance.txt
  if (activeInstance == idx)
    SetAffinity(pid, superHighBitMask) ; this is active instance?
  else if activeInstance
    SetAffinity(pid, bgLoadBitMask) ; bg instance, bg bitmask
  else
    SetAffinity(pid, highBitMask) ; on wall, high bitmask
  if resetSounds {
    SoundPlay, A_ScriptDir\..\media\reset.wav
    if obsResetMediaKey {
      send {%obsResetMediaKey% down}
      sleep, %obsDelay%
      send {%obsResetMediaKey% up}
    }
  }
}

ManageReset() {
  start := A_TickCount
  state := "resetting"
  SendLog(LOG_LEVEL_INFO, Format("Instance {1} starting reset management", idx))
  while (True) {
    if (state == "kill" || FileExist(killFile)) {
      SendLog(LOG_LEVEL_INFO, Format("Instance {1} killing reset management from loop", idx))
      FileDelete, %killFile%
      return
    }
    sleep, %resetManagementLoopDelay%
    Loop, Read, %logFile%
    {
      if (A_Index <= lastImportantLine)
        Continue
      if (state == "resetting" && InStr(A_LoopReadLine, "Starting Preview")) {
        ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
        state := "preview"
        lastImportantLine := GetLineCount(logFile)
        FileDelete, %holdFile%
        FileDelete, %previewFile%
        FileAppend, %A_TickCount%, %previewFile%
        SendLog(LOG_LEVEL_INFO, Format("Instance {1} found preview on log line: {2}", idx, A_Index))
        ; if FileExist("data/instance.txt")
        ;   FileRead, activeInstance, data/instance.txt
        ; if activeInstance
        ;   SetAffinity(pid, lowBitMask)
        ; else
        ;   SetAffinity(pid, highBitMask)
        SetTimer, PreviewBurst, -%previewBurstLength% ; turn down previewBurstLength after preview detected
        Continue 2
      } else if (state != "idle" && InStr(A_LoopReadLine, "advancements")) {
        ; ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
        SetTimer, Pause, -%beforePauseDelay%
        lastImportantLine := GetLineCount(logFile)
        FileDelete, %holdFile%
        if !FileExist(previewFile)
          FileAppend, %A_TickCount%, %previewFile%
        FileDelete, %idleFile%
        FileAppend, %A_TickCount%, %idleFile%
        if (state == "resetting") {
          SendLog(LOG_LEVEL_INFO, Format("Instance {1} line dump: {2}", idx, A_LoopReadLine))
          SendLog(LOG_LEVEL_WARNING, Format("Instance {1} found save while looking for preview, restarting reset management. (No World Preview/resetting too fast/lag)", idx))
          state := "unknown"
          Reset()
        } else {
          SendLog(LOG_LEVEL_INFO, Format("Instance {1} found save on log line: {2}", idx, A_Index))
          state := "idle"
        }
        if FileExist("data/instance.txt")
          FileRead, activeInstance, data/instance.txt
        if (activeInstance == idx)
          SetAffinity(pid, superHighBitMask) ; this is active instance?
        else if activeInstance
          SetAffinity(pid, bgLoadBitMask) ; bg instance loaded, bg bitmask
        else
          SetAffinity(pid, midBitMask) ; on wall, mid bitmask
        SetTimer, LowerLoadedAffinity, -%loadedBurstLength%
        return
      } else if (state == "preview" && InStr(A_LoopReadLine, "Preparing spawn area: ")) {
        loadPercent := StrSplit(StrSplit(A_LoopReadLine, "area: ")[2], "%")[1]
        if (loadPercent > previewLoadPercent && !FileExist(lockFile)) {
          PreviewLoaded()
        }
        lastImportantLine := GetLineCount(logFile)
        SendLog(LOG_LEVEL_INFO, Format("Instance {1} loaded {2}%", idx, loadPercent))
      }
    }
    if (A_TickCount - start > resetManagementTimeout) {
      SendLog(LOG_LEVEL_ERROR, Format("Instance {1} {2} millisecond timeout reached, ending reset management. May have left instance unpaused. (Lag/resetting too fast)", idx, resetManagementTimeout))
      state := "unknown"
      lastImportantLine := GetLineCount(logFile)
      FileDelete, %holdFile%
      FileAppend,, %previewFile%
      FileAppend,, %idleFile%
      return
    }
  }
}

PreviewBurst() {
  if (state != "preview")
    return
  if FileExist("data/instance.txt")
    FileRead, activeInstance, data/instance.txt
  if (activeInstance == idx)
    SetAffinity(pid, superHighBitMask) ; this is active instance?
  else if activeInstance
    SetAffinity(pid, bgLoadBitMask) ; bg instance, bg bitmask
  else
    SetAffinity(pid, midBitMask) ; on wall, mid bitmask
}

PreviewLoaded() {
  if (state != "preview")
    return
  if FileExist("data/instance.txt")
    FileRead, activeInstance, data/instance.txt
  if (activeInstance == idx)
    SetAffinity(pid, superHighBitMask) ; this is active instance?
  else
    SetAffinity(pid, lowBitMask) ; on wall, low bitmask
}

LowerLoadedAffinity() {
  if (state != "idle")
    return
  if FileExist("data/instance.txt")
    FileRead, activeInstance, data/instance.txt
  if (activeInstance == idx)
    SetAffinity(pid, superHighBitMask) ; this is active instance
  else if (!activeInstance && FileExist(lockFile))
    SetAffinity(pid, superHighBitMask) ; locked on wall
  else
    SetAffinity(pid, idleBitMask) ; unlocked idle on wall, idle in bg
}

Pause() {
  if (state == "kill" || state == "resetting")
    return
  ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
}