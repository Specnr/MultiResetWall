#NoEnv
SetKeyDelay, 10

Sleep, 100
ControlSend, ahk_parent, {Blind}{Esc}, ahk_pid %1%
Sleep, 100
ControlSend, ahk_parent, {Blind}{Shift down}{Tab 3}{Enter}{Tab}{Shift up}{Enter}{Tab}{Enter}{F3 down}n{F3 up}/, ahk_pid %1%
Sleep, 100
ControlSend, ahk_parent, {Blind}{Text}summon slime ~ ~ ~ {Size:100`,NoAI:1}, ahk_pid %1% ;size can be adjusted depending on your pc
ControlSend, ahk_parent, {Enter}/, ahk_pid %1%
Sleep, 400 ; these later delays can be adjusted depending on your pc
ControlSend, ahk_parent, {Blind}{Text}spectate @e[type=slime`,sort=nearest`,limit=1], ahk_pid %1%
ControlSend, ahk_parent, {Blind}{Enter}{Esc}, ahk_pid %1%
Sleep, 500
ControlSend, ahk_parent, {Blind}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %1%
Sleep, 100
while (True) {
  WinGetTitle, title, ahk_pid %1%
  if (InStr(title, " - "))
    break
}

while (True) {
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
      if (InStr(A_LoopReadLine, "Loaded 0") || (InStr(A_LoopReadLine, "Saving chunks for level 'ServerLevel") && InStr(A_LoopReadLine, "minecraft:the_end"))) {
        saved := True
        break
      }
    }
  }
  if (saved || A_Index > %3%)
    break
}
sleep, 50
ControlSend, ahk_parent, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
sleep, %4%
FileAppend,, %5%
ExitApp
