; v0.8

#NoEnv
#NoTrayIcon
#Include settings.ahk
#Include %A_ScriptDir%\functions.ahk
#SingleInstance, off

SetKeyDelay, 0

global MSG_RESET := 0x04E20

global pid := A_Args[1]
global logFile := A_Args[2]
global idleFile := A_Args[3]
global holdFile := A_Args[4]
global previewFile := A_Args[5]
global resetKey := A_Args[6]

global state := "unknown"

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
  SendLog(LOG_LEVEL_INFO, "Starting reset")
  while (True) {
    preview := False
    numLines := 0
    Loop, Read, %logFile%
      numLines += 1
    Loop, Read, %logFile%
    {
      if ((numLines - A_Index) < 1)
      {
        if (InStr(A_LoopReadLine, "Starting Preview")) {
          state := "preview"
          SendLog(LOG_LEVEL_INFO, "Found preview")
          break
        }
      }
      if (A_TickCount - start > 2000 && (numLines - A_Index) < 5)
      {
        SendLog(LOG_LEVEL_INFO, Format("Current line dump: {1}", A_LoopReadLine))
        if (InStr(A_LoopReadLine, "Starting Preview")) {
          state := "preview"
          SendLog(LOG_LEVEL_INFO, "Found preview")
          break
        } else if (InStr(A_LoopReadLine, "Loaded 0") || (InStr(A_LoopReadLine, "Saving chunks for level 'ServerLevel") && InStr(A_LoopReadLine, "minecraft:the_end"))) {
          ControlSend,, {Blind}{%resetKey%}, ahk_pid %pid%
          SendLog(LOG_LEVEL_WARNING, "Found save while looking for preview. Overriding preview check")
          break
        }
      }
    }
    if (state == "preview")
      break
    sleep, 50
  }

  FileDelete, %holdFile%
  FileAppend, %A_TickCount%, %previewFile%
  ControlSend,, {Blind}{F3 down}{Esc}{F3 up}, ahk_pid %pid%

  while (True) {
    if (state == "resetting")
      return
    WinGetTitle, title, ahk_pid %pid%
    if (InStr(title, " - "))
      break
    sleep, 50
  }

  while (True) {
    if (state == "resetting")
      return
    numLines := 0
    Loop, Read, %logFile%
      numLines += 1
    saved := False
    Loop, Read, %logFile%
    {
      if ((numLines - A_Index) < 5)
      {
        SendLog(LOG_LEVEL_INFO, Format("Current line dump: {1}", A_LoopReadLine))
        if (InStr(A_LoopReadLine, "Loaded 0") || (InStr(A_LoopReadLine, "Saving chunks for level 'ServerLevel") && InStr(A_LoopReadLine, "minecraft:the_end"))) {
          state := "idle"
          SendLog(LOG_LEVEL_INFO, "Found save")
          break
        }
      }
    }
    if (state == "idle")
      break
    sleep, 50
  }

  sleep, %beforePauseDelay%
  ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
  if (performanceMethod == "F")
    sleep, %beforeFreezeDelay%
  FileAppend, %A_TickCount%, %idleFile%
  return
}