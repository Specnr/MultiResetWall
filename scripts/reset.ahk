#NoEnv
SetKeyDelay, 0
; v0.4.11

; Pasrse %12% into int (yeah i know this is stupid, avg ahk)
str = %12%
Loop, Parse, str
{
  If A_LoopField in 0,1,2,3,4,5,6,7,8,9,.,+,-
    fpa = %fpa%%A_LoopField%
}

started := A_NowUTC
if (%7%)
  SoundPlay, A_ScriptDir\..\sounds\reset.wav
saved := False
FileDelete,%8%
FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Starting Reset `n, log.log

WinGetTitle, title, ahk_pid %1%
if (InStr(title, "-"))
  ControlSend,, {Blind}{Shift down}{Tab}{Shift up}{Enter}{%10%}, ahk_pid %1%
else
  ControlSend,, {Blind}{%10%}, ahk_pid %1%

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
        FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Found Preview `n, log.log
        break
      }
    }
    if (A_NowUTC - started > 2 && (numLines - A_Index) < 5)
    {
      FileAppend, %A_LoopReadLine%`n, log.log
      if (InStr(A_LoopReadLine, "Loaded 0") || (InStr(A_LoopReadLine, "Saving chunks for level 'ServerLevel") && InStr(A_LoopReadLine, "minecraft:the_end"))) {
        ControlSend,, {Blind}{Esc}{Shift down}{Tab}{Shift up}{Enter}{%10%}, ahk_pid %1%
        FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Found Save overriding preview check `n, log.log
        break
      }
    }
  }
  if (preview)
    break
}
ControlSend,, {Blind}{F3 down}{Esc}{F3 up}, ahk_pid %1%
FileDelete,%9%

frozenPreview := False
while (True) {
  FileDelete, %8%
  if (ErrorLevel == 0)
    ExitApp
  WinGetTitle, title, ahk_pid %1%
  if (InStr(title, " - "))
    break
  if (!frozenPreview && A_NowUTC - previewStarted > fpa) {
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] Freezing preview`n, log.log
    frozenPreview := True
    ControlSend,, {Blind}{%11%}, ahk_pid %1%
  }
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
      FileAppend, %A_LoopReadLine%`n, log.log
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
ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
FileDelete,%9%
sleep, %4%
FileAppend,, %5%
ExitApp
