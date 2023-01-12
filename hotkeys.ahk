RAlt::Suspend ; Pause all macros
#If WinActive("Minecraft") && (WinActive("ahk_exe javaw.exe") || WinActive("ahk_exe java.exe"))
{
  *U:: ExitWorld() ; Reset

  ; Utility (Remove semicolon ';' and set a hotkey)
  ;::WideHardo()
  ;::OpenToLAN()
  ;::GoToNether()
  ;::OpenToLANAndGoToNether()
  ;::CheckFourQuadrants("fortress")
  ;::CheckFourQuadrants("bastion_remnant")
  ;::CheckFor("buried_treasure")
}
return

#If WinActive("Fullscreen Projector") || WinActive("Full-screen Projector")
{
  *E::ResetInstance(MousePosToInstNumber())
  *R::SwitchInstance(MousePosToInstNumber())
  *F::FocusReset(MousePosToInstNumber())
  *T::ResetAll()
  +LButton::LockInstance(MousePosToInstNumber()) ; lock an instance so the above "blanket reset" functions don't reset it

  ; Optional (Remove semicolon ';' and set a hotkey)
  ;::PlayNextLock()
  ;::PlayNextLock(true) ; Utilizes bypassThreshold
}