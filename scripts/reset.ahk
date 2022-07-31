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
global resetKey := A_Args[6]
global lpKey := A_Args[7]
global idx := A_Args[8]
global highBitMask := A_Args[9]
global midBitMask := A_Args[10]
global lowBitMask := A_Args[11]
global superLowBitMask := A_Args[12]

global state := "unknown"
global lastImportantLine := GetLineCount(logFile)

SendLog(LOG_LEVEL_INFO, Format("Inst {1} reset manager started", idx))

OnMessage(MSG_RESET, "Reset")

Reset() {
  if (state == "resetting" || state == "kill")
    return
  state := "kill"
  lastImportantLine := GetLineCount(logFile)
  SetTimer, ManageReset, -200
  if FileExist("data/instance.txt")
    FileRead, activeInstance, data/instance.txt
  if (affinity) {
    if (activeInstance)
      SetAffinity(pid, lowBitMask)
    else
      SetAffinity(pid, midBitMask)
  }
  FileAppend,, %holdFile%
  FileDelete, %idleFile%
  if (resetSounds)
    SoundPlay, A_ScriptDir\..\media\reset.wav
}

ManageReset() {
  start := A_TickCount
  state := "resetting"
  SendLog(LOG_LEVEL_INFO, Format("Inst {1} starting reset management", idx))
  while (True) {
    if (state == "kill")
      return
    sleep, 70
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
        SendLog(LOG_LEVEL_INFO, Format("Inst {1} found preview on log line: {2}", idx, A_Index))
        if FileExist("data/instance.txt")
          FileRead, activeInstance, data/instance.txt
        Continue 2
      } else if (state != "idle" && InStr(A_LoopReadLine, "Loaded 0 advancements")) {
        sleep, %beforePauseDelay%
        ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
        lastImportantLine := GetLineCount(logFile)
        if (performanceMethod == "F")
          sleep, %beforeFreezeDelay%
        FileDelete, %holdFile%
        if !FileExist(previewFile)
          FileAppend, %A_TickCount%, %previewFile%
        if !FileExist(idleFile)
          FileAppend, %A_TickCount%, %idleFile%
        if (state == "resetting") {
          SendLog(LOG_LEVEL_INFO, Format("Inst {1} line dump: {2}", idx, A_LoopReadLine))
          SendLog(LOG_LEVEL_WARNING, Format("Inst {1} found save while looking for preview, restarting reset management. (No World Preview/resetting too fast/lag)", idx))
          state := "unknown"
          Reset()
        } else {
          SendLog(LOG_LEVEL_INFO, Format("Inst {1} found save on log line: {2}", idx, A_Index))
          state := "idle"
        }
        if FileExist("data/instance.txt")
          FileRead, activeInstance, data/instance.txt
        if (affinity) {
          if (activeInstance)
            SetAffinity(pid, superLowBitMask)
          else
            SetAffinity(pid, lowBitMask)
        }
        return
      }
    }
    if (A_TickCount - start > 25000) {
      SendLog(LOG_LEVEL_ERROR, Format("Inst {1} 25 second timeout reached, ending reset management. May have left instance unpaused. (Lag/resetting too fast)", idx))
      state := "unknown"
      lastImportantLine := GetLineCount(logFile)
      FileDelete, %holdFile%
      if !FileExist(previewFile)
        FileAppend, %A_TickCount%, %previewFile%
      if !FileExist(idleFile)
        FileAppend, %A_TickCount%, %idleFile%
      return
    }
  }
}