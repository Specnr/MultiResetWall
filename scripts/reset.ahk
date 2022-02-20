#NoEnv
SetKeyDelay, 0
; v0.4.8

if (%7%)
  SoundPlay, A_ScriptDir\..\sounds\reset.wav

FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Starting Reset `n, log.log
WinGetTitle, title, ahk_pid %1%
if (InStr(title, "-"))
  ControlSend, ahk_parent, {Blind}{Shift down}{Tab}{Shift up}{Enter}{%10%}, ahk_pid %1%
else
  ControlSend, ahk_parent, {Blind}{Shift down}{Tab}{Shift up}{Enter}{%10%}, ahk_pid %1%
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
        FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Found Preview `n, log.log
        break
      }
    }
  }
  if (preview)
    break
}
ControlSend, ahk_parent, {Blind}{F3 down}{Esc}{F3 up}, ahk_pid %1%
FileDelete,%9%

while (True) {
  FileDelete, %8%
  if (ErrorLevel == 0)
    ExitApp
  WinGetTitle, title, ahk_pid %1%
  if (InStr(title, " - "))
    break
}

while (True) {
  FileDelete, %8%
  if (ErrorLevel == 0)
    ExitApp
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
      FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] %A_LoopReadLine%`n, log.log
      if (InStr(A_LoopReadLine, "Loaded 0") || (InStr(A_LoopReadLine, "Saving chunks for level 'ServerLevel") && InStr(A_LoopReadLine, "minecraft:the_end"))) {
        saved := True
        FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Found Save `n, log.log
        break
      }
    }
  }
  if (saved || A_Index > %3%)
    break
}
FileAppend,,%9%
sleep, %6%
WinGet, activePID, PID, A
if (activePID != %1%) {
  ControlSend, ahk_parent, {Blind}{F3 Down}{Esc Down}, ahk_pid %1%
  sleep, 150
  ControlSend, ahk_parent, {Blind}{Esc Up}{F3 Up}, ahk_pid %1%
}
FileDelete,%9%
sleep, %4%
FileAppend,, %5%
ExitApp
