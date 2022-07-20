#NoEnv
#Include settings.ahk
#Include %A_ScriptDir%\functions.ahk
SetKeyDelay, 0
; v0.5

started := A_NowUTC
if (%resetSounds%)
  SoundPlay, A_ScriptDir\..\media\reset.wav
saved := False
FileDelete,%4%
SendLog(LOG_LEVEL_INFO, "Starting reset")

while (True) {
  numLines := 0
  Loop, Read, %2%
  {
    numLines += 1
  }
  preview := False
  Loop, Read, %2%
  {
    if ((numLines - A_Index) < 1)
    {
      if (InStr(A_LoopReadLine, "Starting Preview")) {
        preview := True
        previewStarted := A_NowUTC
        SendLog(LOG_LEVEL_INFO, "Found preview")
        break
      }
    }
    if (A_NowUTC - started > 2 && (numLines - A_Index) < 5)
    {
      SendLog(LOG_LEVEL_INFO, Format("Current line dump: {1}", A_LoopReadLine))
      if (InStr(A_LoopReadLine, "Starting Preview")) {
        preview := True
        previewStarted := A_NowUTC
        SendLog(LOG_LEVEL_INFO, "Found preview")
        break
      }
      else if (InStr(A_LoopReadLine, "Loaded 0") || (InStr(A_LoopReadLine, "Saving chunks for level 'ServerLevel") && InStr(A_LoopReadLine, "minecraft:the_end"))) {
        ControlSend,, {Blind}{%6%}, ahk_pid %1%
        SendLog(LOG_LEVEL_WARNING, "Found save while looking for preview. Overriding preview check")
        break
      }
    }
  }
  if (preview)
    break
}
ControlSend,, {Blind}{F3 down}{Esc}{F3 up}, ahk_pid %1%
FileDelete,%5%

frozenPreview := False
while (True) {
  FileDelete, %4%
  if (ErrorLevel == 0) {
    ControlSend,, {Blind}{Shift}, ahk_pid %1%
    ExitApp
  }
  WinGetTitle, title, ahk_pid %1%
  if (InStr(title, " - "))
    break
}

while (True) {
  FileDelete, %4%
  if (ErrorLevel == 0) {
    ControlSend,, {Blind}{Shift}, ahk_pid %1%
    ExitApp
  }
  numLines := 0
  Loop, Read, %2%
  {
    numLines += 1
  }
  saved := False
  Loop, Read, %2%
  {
    if ((numLines - A_Index) < 5)
    {
      SendLog(LOG_LEVEL_INFO, Format("Current line dump: {1}", A_LoopReadLine))
      if (InStr(A_LoopReadLine, "Loaded 0") || (InStr(A_LoopReadLine, "Saving chunks for level 'ServerLevel") && InStr(A_LoopReadLine, "minecraft:the_end"))) {
        saved := True
        SendLog(LOG_LEVEL_INFO, "Found save")
        break
      }
    }
  }
  if (saved || A_Index > %maxLoops%)
    break
}
FileAppend,,%5%
sleep, %beforePauseDelay%
ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
FileDelete,%5%
if (performanceMethod == "F")
  sleep, %beforeFreezeDelay%
FileAppend,, %3%
ControlSend,, {Blind}{Shift}, ahk_pid %1%
ExitApp
