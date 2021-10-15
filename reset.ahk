#NoEnv
SetKeyDelay, 0

ControlSend, ahk_parent, {Blind}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %1%
sleep, 3000

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
  if (saved)
    break
}
sleep, 50
ControlSend, ahk_parent, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
sleep, %3%
FileAppend,, %4%
ExitApp