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

global idx := GetInstanceNumberFromMcDir(GetMcDir(pid))
global state := "unknown"
global lastLineCount := 0
global lastPreview := 0

SendLog(LOG_LEVEL_INFO, Format("Inst {1} reset manager started", idx))

OnMessage(MSG_RESET, "Reset")

Reset() {
  if (state == "resetting")
    return
  state := "resetting"
  if FileExist(idleFile)
    FileDelete, %idleFile%
  if (resetSounds)
    SoundPlay, A_ScriptDir\..\media\reset.wav
  SetTimer, ManageReset, -200
}

ManageReset() {
  start := A_TickCount
  SendLog(LOG_LEVEL_INFO, Format("Inst {1} starting reset", idx))
  while (True) {
    sleep, 60
    numLines := 0
    Loop, Read, %logFile%
      numLines := A_Index
    if (lastLineCount >= numLines)
      Continue
    lastLineCount := numLines
    Loop, Read, %logFile%
    {
      if ((A_Index > lastPreview) && (numLines - A_Index) < 5)
      {
        if (InStr(A_LoopReadLine, "Starting Preview")) {
          state := "preview"
          lastPreview := A_Index
          SendLog(LOG_LEVEL_INFO, Format("Inst {1} found preview on log line: {2}", idx, A_Index))
          break 2
        }
        sleep, 20
        if (A_TickCount - start > 4000)
        {
          SendLog(LOG_LEVEL_INFO, Format("Inst {1} current line dump: {2}", idx, A_LoopReadLine))
          if (InStr(A_LoopReadLine, "Loaded 0") || (InStr(A_LoopReadLine, "Saving chunks for level 'ServerLevel") && InStr(A_LoopReadLine, "minecraft:the_end"))) {
            ControlSend,, {Blind}{%resetKey%}, ahk_pid %pid%
            SendLog(LOG_LEVEL_WARNING, Format("Inst {1} found save while looking for preview. Forcing another reset", idx))
            break
          }
          sleep, 20
        }
      }
    }
  }

  FileDelete, %holdFile%
  if FileExist(previewFile)
    FileDelete, %previewFile%
  FileAppend, %A_TickCount%, %previewFile%
  ControlSend,, {Blind}{F3 down}{Esc}{F3 up}, ahk_pid %pid%

  while (True) {
    if (state == "resetting")
      return
    WinGetTitle, title, ahk_pid %pid%
    if (InStr(title, " - "))
      break
    sleep, 60
  }

  while (True) {
    if (state == "resetting")
      return
    sleep, 80
    numLines := 0
    Loop, Read, %logFile%
      numLines := A_Index
    if (lastLineCount >= numLines)
      Continue
    lastLineCount := numLines
    Loop, Read, %logFile%
    {
      if ((numLines - A_Index) < 5)
      {
        SendLog(LOG_LEVEL_INFO, Format("Inst {1} current line dump: {2}", idx, A_LoopReadLine))
        if (InStr(A_LoopReadLine, "Loaded 0") || (InStr(A_LoopReadLine, "Saving chunks for level 'ServerLevel") && InStr(A_LoopReadLine, "minecraft:the_end"))) {
          state := "idle"
          SendLog(LOG_LEVEL_INFO, Format("Inst {1} found save on log line: {2}", idx, A_Index))
          break 2
        }
        sleep, 20
      }
    }
  }

  sleep, %beforePauseDelay%
  ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
  if (performanceMethod == "F")
    sleep, %beforeFreezeDelay%
  FileAppend, %A_TickCount%, %idleFile%
  if FileExist(holdFile)
    FileDelete, %holdFile%
  return
}