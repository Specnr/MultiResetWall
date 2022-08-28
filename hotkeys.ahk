; v1.0
RAlt::Suspend ; Pause all macros
RCtrl:: ; Reload if macro locks up
  Reload
return
#If WinActive("Minecraft") && (WinActive("ahk_exe javaw.exe") || WinActive("ahk_exe java.exe"))
  {
    *F5:: ExitWorld() ; Reset
  }
return

#IfWinActive, Fullscreen Projector
  {
    *F Up::ResetInstance(MousePosToInstNumber())
    *F::ResetInstance(MousePosToInstNumber(), false)
    *1::ResetInstance(MousePosToInstNumber())
    *^LButton::ResetInstance(MousePosToInstNumber())

    *W::SwitchInstance(MousePosToInstNumber())
    *2::SwitchInstance(MousePosToInstNumber())
    *!RButton::SwitchInstance(MousePosToInstNumber())

    *T::FocusReset(MousePosToInstNumber())
    *!T::FocusReset(MousePosToInstNumber(), true)
    *MButton::FocusReset(MousePosToInstNumber())
    *^RButton::FocusReset(MousePosToInstNumber())

    *WheelUp::LockInstance(MousePosToInstNumber())
    *+LButton::LockInstance(MousePosToInstNumber()) ; lock an instance so the above "blanket reset" functions don't reset it
    
    *WheelDown::UnlockInstance(MousePosToInstNumber())
    *+RButton::UnlockInstance(MousePosToInstNumber()) ; unlock instance

    *G::ResetAll()
    *!G::ResetAll(true)
    *5::ResetAll()
    
    *+G::LockAll()
    *^G::UnlockAll()

    *R::PlayNextLock(true)
  }