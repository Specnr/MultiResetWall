Class Window {
    __New(idx, pid, mcDir) {
        this.idx := idx
        this.pid := pid
        this.mcDir := mcDir
        this.f1State := 0
        this.unpauseOnSwitch := true
        this.hwnd := this.GetHwnd()

        this.VerifyInstance(this.idx, this.pid, this.mcDir)

        this.PrepareWindow()
    }

    GetHwnd() {
        WinGet, hwnd, ID, % Format("ahk_pid {1}", this.pid)
        return StrReplace(hwnd, "ffffffff")
    }

    PrepareWindow() {
        WinGetTitle, winTitle, % Format("ahk_pid {1}", this.pid)
        if !InStr(winTitle, " - ") {
            ControlClick, x0 y0, % Format("ahk_pid {1}", this.pid),, RIGHT
            ControlSend,, {Blind}{Esc}, % Format("ahk_pid {1}", this.pid)
            WinMinimize, % Format("ahk_pid {1}", this.pid)
            WinRestore, % Format("ahk_pid {1}", this.pid)
        }
        if (windowMode == "B") {
            WinSet, Style, -0xC40000, % Format("ahk_pid {1}", this.pid)
        } else {
            WinSet, Style, +0xC40000, % Format("ahk_pid {1}", this.pid)
        }
        this.Widen()
        WinSet, AlwaysOnTop, Off, % Format("ahk_pid {1}", this.pid)

        this.SetTitle()
    }

    SendResetInput() {
        ControlSend, ahk_parent, % Format("{Blind}{{1}}{{2}}", this.lpKey, this.resetKey), % Format("ahk_pid {1}", this.pid)
        CountAttempt()
    }

    SwitchTo() {
        WinMinimize, % Format("ahk_id {1}", GetProjectorID())

        foreGroundWindow := DllCall("GetForegroundWindow")
        windowThreadProcessId := DllCall("GetWindowThreadProcessId", "uint", foreGroundWindow, "uint", 0)
        currentThreadId := DllCall("GetCurrentThreadId")
        DllCall("AttachThreadInput", "uint", windowThreadProcessId, "uint", currentThreadId, "int", 1)
        if (widthMultiplier && (windowMode == "W" || windowMode == "B"))
            DllCall("SendMessage", "uint", this.hwnd, "uint", 0x0112, "uint", 0xF030, "int", 0) ; fast maximize
        DllCall("SetForegroundWindow", "uint",this.hwnd) ; Probably only important in windowed, helps application take input without a Send Click
        DllCall("BringWindowToTop", "uint", this.hwnd)
        DllCall("AttachThreadInput", "uint", windowThreadProcessId, "uint", currentThreadId, "int", 0)

        if (windowMode == "F") {
            this.ToggleFullscreen(true)
        }
    }

    JoinInstance(special:=false) {
        ControlSend,, {Blind}{Esc}, % Format("ahk_pid {1}", this.pid)
        if (this.f1State == 2)
            ControlSend,, {Blind}{F1}, % Format("ahk_pid {1}", this.pid)
        if (special)
            this.OnJoinSettingsChange()
        if (coop)
            ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, % Format("ahk_pid {1}", this.pid)
        if (!this.unpauseOnSwitch)
            ControlSend,, {Blind}{Esc}, % Format("ahk_pid {1}", this.pid)
    }

    OnJoinSettingsChange() {
        rdPresses := renderDistance - 2
        ControlSend,, {Blind}{Shift down}{F3 down}{f 30}{Shift up}{f %rdPresses%}{F3 up}, % Format("ahk_pid {1}", this.pid)
        if (toggleChunkBorders)
            ControlSend,, {Blind}{F3 down}{g}{F3 up}, % Format("ahk_pid {1}", this.pid)
        if (toggleHitBoxes)
            ControlSend,, {Blind}{F3 down}{b}{F3 up}, % Format("ahk_pid {1}", this.pid)
        FOVPresses := ceil((110-fov)*1.7875)
        entityPresses := (5 - (entityDistance*.01)) * 143 / 4.5
        ControlSend,, {Blind}{F3 down}{d}{F3 up}{Esc}{Tab 6}{Enter}{Tab 1}{Right 150}{Left %FOVPresses%}{Tab 5}{Enter}{Tab 17}{Right 150}{Left %entityPresses%}{Esc 2}, % Format("ahk_pid {1}", this.pid)
    }

    GhostPie() {
        if this.f1State
            ControlSend,, {Blind}{F1}{F3}{Esc 3}, % Format("ahk_pid {1}", this.pid)
        else
            ControlSend,, {Blind}{F3}{Esc 3}, % Format("ahk_pid {1}", this.pid)
    }

    Restore() {
        WinRestore, % Format("ahk_pid {1}", this.pid)
    }

    Widen() {
        newHeight := Floor(A_ScreenHeight / widthMultiplier)
        if widthMultiplier {
            WinRestore, % Format("ahk_pid {1}", this.pid)
            WinMove, % Format("ahk_pid {1}", this.pid),,0,0,%A_ScreenWidth%,%newHeight%
        }
    }

    SendToBack() {
        Winset, Bottom,, % Format("ahk_pid {1}", this.pid)
    }

    ToggleFullscreen(switching) {
        isFs := CheckOptionsForValue(this.mcDir . "options.txt", "fullscreen:", "false") == "true"
        if (switching || (isFs && !switching)) {
            ControlSend, ahk_parent, % Format("{Blind}{{1}}", this.fsKey), % Format("ahk_pid {1}", this.pid)
            sleep, %fullscreenDelay%
        }
    }

    SetAffinity(mask) {
        hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", this.pid, "Ptr")
        DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
        DllCall("CloseHandle", "Ptr", hProc)
    }

    SetTitle() {
        WinSetTitle, % Format("ahk_pid {1}", this.pid), , % Format("Minecraft* - Instance {1}", this.idx)
    }

    VerifyInstance(idx, pid, mcDir) {
        moddir := mcDir . "mods\"
        optionsFile := mcDir . "options.txt"
        atum := false
        wp := false
        standardSettings := false
        fastReset := false
        sleepBg := false
        sodium := false
        srigt := false
        SendLog(LOG_LEVEL_INFO, Format("Starting instance verification for directory: {1}", mcDir))
        ; Check for mod dependencies
        Loop, Files, %moddir%*.jar
        {
            if InStr(A_LoopFileName, ".disabled")
                continue
            else if InStr(A_LoopFileName, "atum")
                atum := true
            else if InStr(A_LoopFileName, "worldpreview")
                wp := true
            else if InStr(A_LoopFileName, "standardsettings")
                standardSettings := true
            else if InStr(A_LoopFileName, "fast-reset")
                fastReset := true
            else if InStr(A_LoopFileName, "sleepbackground")
                sleepBg := true
            else if InStr(A_LoopFileName, "sodium")
                sodium := true
            else if InStr(A_LoopFileName, "SpeedRunIGT")
                srigt := true
        }
        if !atum {
            SendLog(LOG_LEVEL_ERROR, Format("Instance {1} missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases. (In directory: {2})", idx, moddir))
            MsgBox, Instance %idx% missing required mod: atum. Macro will not work. Download: https://github.com/VoidXWalker/Atum/releases.`n(In directory: %moddir%)
        } else if this.unpauseOnSwitch {
            config := mcDir . "config\atum\atum.properties"
            ; Read the atum.properties and set unpauseOnSwitch to false if a seed is set
            Loop, Read, %config%
            {
                if (InStr(A_LoopReadLine, "seed=") && StrLen(A_LoopReadLine) > 5) {
                    SendLog(LOG_LEVEL_INFO, "Found a set seed, setting 'unpauseOnSwitch' to False")
                    this.unpauseOnSwitch := False
                    break
                }
            }
        }
        if !wp {
            SendLog(LOG_LEVEL_WARNING, Format("Instance {1} missing recommended mod: World Preview. Macro attempted to adapt. Download: https://github.com/VoidXWalker/WorldPreview/releases. (In directory: {2})", idx, moddir))
            this.doubleCheckUnexpectedLoads := False
        } else {
            this.doubleCheckUnexpectedLoads := True
        }
        FileRead, settings, %optionsFile%
        if !standardSettings {
            SendLog(LOG_LEVEL_WARNING, Format("Instance {1} missing highly recommended mod standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases. (In directory: {2})", idx, moddir))
            MsgBox, Instance %idx% missing highly recommended mod: standardsettings. Download: https://github.com/KingContaria/StandardSettings/releases.`n(In directory: %moddir%)
            if InStr(settings, "pauseOnLostFocus:true") {
                MsgBox, Instance %idx% has required disabled setting pauseOnLostFocus enabled. Please disable it with f3+p and THEN press OK to continue
                SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had pauseOnLostFocus set true, macro requires it false. User was informed. (In file: {2})", idx, optionsFile))
            }
            if (atum) {
                if (InStr(settings, "key_Create New World:key.keyboard.unknown")) {
                    MsgBox, Instance %idx% missing required hotkey: Create New World. Please set it in your hotkeys and THEN press OK to continue
                    SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Create New World key set. User was informed. (In file: {2})", idx, optionsFile))
                }
                this.resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")
                resetKeys[idx] := resetKey
                SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
            }
            if (wp) {
                if (InStr(settings, "key_Leave Preview:key.keyboard.unknown")) {
                    MsgBox, Instance %idx% missing highly recommended hotkey: Leave Preview. Please set it in your hotkeys and THEN press OK to continue
                    SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Leave Preview key set. User was informed. (In file: {2})", idx, optionsFile))
                }
                this.lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")
                lpkeys[idx] := lpKey
                SendLog(LOG_LEVEL_INFO, Format("Found leave preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
            }
            if (windowMode == "F") {
                if (InStr(settings, "key_key.fullscreen:key.keyboard.unknown")) {
                    MsgBox, Instance %idx% missing required hotkey for fullscreen mode: Fullscreen. Please set it in your hotkeys and THEN press OK to continue
                        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Fullscreen key set. User was informed. (In file: {2})", idx, optionsFile))
                }
                this.fsKey := CheckOptionsForValue(optionsFile, "key_key.fullscreen", "F11")
                fsKeys[idx] := fsKey
                SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2} from {3}", fsKey, idx, optionsFile))
            }
        } else {
            standardSettingsFile := mcDir . "config\standardoptions.txt"
            FileRead, ssettings, %standardSettingsFile%
            if (RegExMatch(ssettings, "[A-Z]:(\/|\\).+\.txt", globalPath)) {
                standardSettingsFile := globalPath
                SendLog(LOG_LEVEL_INFO, Format("Global standard options file detected, rereading standard options from {1}", standardSettingsFile))
                FileRead, ssettings, %standardSettingsFile%
            }
            if InStr(ssettings, "fullscreen:true") {
                ssettings := StrReplace(ssettings, "fullscreen:true", "fullscreen:false")
                SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had fullscreen set true, macro requires it false. Automatically fixed. (In file: {2})", idx, standardSettingsFile))
            }
            if InStr(ssettings, "pauseOnLostFocus:true") {
                ssettings := StrReplace(ssettings, "pauseOnLostFocus:true", "pauseOnLostFocus:false")
                SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had pauseOnLostFocus set true, macro requires it false. Automatically fixed. (In file: {2})", idx, standardSettingsFile))
            }
            if (RegExMatch(ssettings, "f1:.+", f1Match)) {
                SendLog(LOG_LEVEL_INFO, Format("Instance {1} f1 state '{2}' found. This will be used for ghost pie and instance join. (In file: {3})", idx, f1Match, standardSettingsFile))
                this.f1State := f1Match == "f1:true" ? 2 : 1
            }
            Loop, 1 {
                if (InStr(ssettings, "key_Create New World:key.keyboard.unknown") && atum) {
                    Loop, 1 {
                        MsgBox, 4, Create New World Key, Instance %idx% has no Create New World hotkey set. Would you like to set this back to default (F6)?`n(In file: %standardSettingsFile%)
                        IfMsgBox No
                        break
                        ssettings := StrReplace(ssettings, "key_Create New World:key.keyboard.unknown", "key_Create New World:key.keyboard.f6")
                        resetKeys[idx] := "F6"
                        SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Create New World key set and chose to let it be automatically set to f6. (In file: {2})", idx, standardSettingsFile))
                        break 2
                    }
                    SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Create New World key set. (In file: {2})", idx, standardSettingsFile))
                } else if (InStr(ssettings, "key_Create New World:") && atum) {
                    if (this.resetKey := CheckOptionsForValue(standardSettingsFile, "key_Create New World", "F6")) {
                        SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, standardSettingsFile))
                        resetKeys[idx] := resetKey
                        break
                    } else {
                        SendLog(LOG_LEVEL_WARNING, Format("Failed to read reset key for instance {1}, trying to read from {2} instead of {3}", idx, optionsFile, standardSettingsFile))
                        if (this.resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")) {
                            SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
                            resetKeys[idx] := resetKey
                            break
                        }
                    }
                    SendLog(LOG_LEVEL_ERROR, Format("Failed to find reset key in instance {1}, falling back to 'F6'. (Checked files: {2} and {3})", idx, standardSettingsFile, optionsFile))
                    resetKeys[idx] := "F6"
                } else if (InStr(settings, "key_Create New World:key.keyboard.unknown") && atum) {
                    MsgBox, Instance %idx% has no required hotkey set for Create New World. Please set it in your hotkeys and THEN press OK to continue
                        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Create New World key set. User was informed. (In file: {2})", idx, optionsFile))
                    if (this.resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")) {
                        resetKeys[idx] := resetKey
                        SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
                    } else {
                        SendLog(LOG_LEVEL_ERROR, Format("No required atum mod in instance {1}. Using 'f6' to avoid reset manager errors", idx))
                        resetKeys[idx] := "F6"
                    }
                } else if (InStr(settings, "key_Create New World:") && atum) {
                    if (this.resetKey := CheckOptionsForValue(optionsFile, "key_Create New World", "F6")) {
                        SendLog(LOG_LEVEL_INFO, Format("Found reset key: {1} for instance {2} from {3}", resetKey, idx, optionsFile))
                        resetKeys[idx] := resetKey
                    } else {
                        SendLog(LOG_LEVEL_ERROR, Format("Failed to find reset key in instance {1}, falling back to 'F6'. (In file: {2})", idx, optionsFile))
                        resetKeys[idx] := "F6"
                    }
                } else if (atum) {
                    MsgBox, No Create New World hotkey found even though you have the mod, you likely have an outdated version. Please update to the latest version.
                    SendLog(LOG_LEVEL_ERROR, Format("No Create New World hotkey found for instance {1} even though mod is installed. Using 'f6' to avoid reset manager errors", idx))
                    resetKeys[idx] := "F6"
                } else {
                    SendLog(LOG_LEVEL_ERROR, Format("No required atum mod in instance {1}. Using 'f6' to avoid reset manager errors", idx))
                    resetKeys[idx] := "F6"
                }
                break
            }
            Loop, 1 {
                if (InStr(ssettings, "key_Leave Preview:key.keyboard.unknown") && wp) {
                    Loop, 1 {
                        MsgBox, 4, Leave Preview Key, Instance %idx% has no Leave Preview hotkey set. Would you like to set this back to default (h)?`n(In file: %standardSettingsFile%)
                        IfMsgBox No
                        break
                        ssettings := StrReplace(ssettings, "key_Leave Preview:key.keyboard.unknown", "key_Leave Preview:key.keyboard.h")
                        this.lpKeys[idx] := "h"
                        SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Leave Preview key set and chose to let it be automatically set to 'h'. (In file: {2})", idx, standardSettingsFile))
                        break 2
                    }
                    SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Leave Preview key set. (In file: {2})", idx, standardSettingsFile))
                } else if (InStr(ssettings, "key_Leave Preview:") && wp) {
                    if (this.lpKey := CheckOptionsForValue(standardSettingsFile, "key_Leave Preview", "h")) {
                        SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, standardSettingsFile))
                        lpKeys[idx] := lpKey
                        break
                    } else {
                        SendLog(LOG_LEVEL_WARNING, Format("Failed to read Leave Preview key for instance {1}, trying to read from {2} instead of {3}", idx, optionsFile, standardSettingsFile))
                        if (this.lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")) {
                            SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
                            lpKeys[idx] := lpKey
                            break
                        }
                    }
                    SendLog(LOG_LEVEL_ERROR, Format("Failed to find Leave Preview key in instance {1}, falling back to 'h'. (Checked files: {2} and {3})", idx, standardSettingsFile, optionsFile))
                    lpKeys[idx] := "h"
                } else if (InStr(settings, "key_Leave Preview:key.keyboard.unknown") && wp) {
                    MsgBox, Instance %idx% has no recommended hotkey set for Leave Preview. Please set it in your hotkeys and THEN press OK to continue
                        SendLog(LOG_LEVEL_ERROR, Format("Instance {1} had no Leave Preview key set. User was informed. (In file: {2})", idx, optionsFile))
                    if (this.lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")) {
                        resetKeys[idx] := resetKey
                        SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
                    } else {
                        SendLog(LOG_LEVEL_ERROR, Format("No recommended World Preview mod in instance {1}. Using 'h' to avoid reset manager errors", idx))
                        lpKeys[idx] := "h"
                    }
                } else if (InStr(settings, "key_Leave Preview:") && wp) {
                    if (this.lpKey := CheckOptionsForValue(optionsFile, "key_Leave Preview", "h")) {
                        SendLog(LOG_LEVEL_INFO, Format("Found Leave Preview key: {1} for instance {2} from {3}", lpKey, idx, optionsFile))
                        lpKeys[idx] := lpKey
                    } else {
                        SendLog(LOG_LEVEL_ERROR, Format("Failed to find Leave Preview key in instance {1}, falling back to 'h'. (In file: {2})", idx, optionsFile))
                        lpKeys[idx] := "h"
                    }
                } else if (atum) {
                    MsgBox, No Leave Preview hotkey found even though you have the mod, something went wrong trying to find the key.
                    SendLog(LOG_LEVEL_ERROR, Format("No Leave Preview hotkey found for instance {1} even though mod is installed. Using 'h' to avoid reset manager errors", idx))
                    lpKeys[idx] := "h"
                } else {
                    SendLog(LOG_LEVEL_ERROR, Format("No recommended World Preview mod in instance {1}. Using 'h' to avoid reset manager errors", idx))
                    lpKeys[idx] := "h"
                }
                break
            }
            Loop, 1 {
                if (InStr(ssettings, "key_key.fullscreen:key.keyboard.unknown") && windowMode == "F") {
                    Loop, 1 {
                        MsgBox, 4, Fullscreen Key, Instance %idx% missing required hotkey for fullscreen mode: Fullscreen. Would you like to set this back to default (f11)?`n(In file: %standardSettingsFile%)
                            IfMsgBox No
                        break
                        ssettings := StrReplace(ssettings, "key_key.fullscreen:key.keyboard.unknown", "key_key.fullscreen:key.keyboard.f11")
                        this.fsKey := "F11"
                        SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no Fullscreen key set and chose to let it be automatically set to 'f11'. (In file: {2})", idx, standardSettingsFile))
                        break 2
                    }
                    SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no Fullscreen key set. (In file: {2})", idx, standardSettingsFile))
                } else {
                    this.fsKey := CheckOptionsForValue(standardSettingsFile, "key_key.fullscreen", "F11")
                    SendLog(LOG_LEVEL_INFO, Format("Found Fullscreen key: {1} for instance {2} from {3}", fsKey, idx, standardSettingsFile))
                    fsKeys[idx] := fsKey
                    break
                }
            }
            Loop, 1 {
                if (InStr(ssettings, "key_key.command:key.keyboard.unknown")) {
                    Loop, 1 {
                        MsgBox, 4, Command Key, Instance %idx% missing recommended command hotkey. Would you like to set this back to default (/)?`n(In file: %standardSettingsFile%)
                        IfMsgBox No
                        break
                        ssettings := StrReplace(ssettings, "key_key.command:key.keyboard.unknown", "key_key.command:key.keyboard.slash")
                        commandkeys[idx] := "/"
                        SendLog(LOG_LEVEL_WARNING, Format("Instance {1} had no command key set and chose to let it be automatically set to '/'. (In file: {2})", idx, standardSettingsFile))
                        break 2
                    }
                    SendLog(LOG_LEVEL_ERROR, Format("Instance {1} has no command key set. (In file: {2})", idx, standardSettingsFile))
                } else {
                    commandkey := CheckOptionsForValue(standardSettingsFile, "key_key.command", "/")
                    SendLog(LOG_LEVEL_INFO, Format("Found Command key: {1} for instance {2} from {3}", commandkey, idx, standardSettingsFile))
                    commandkeys[idx] := commandkey
                    break
                }
            }
            FileDelete, %standardSettingsFile%
            FileAppend, %ssettings%, %standardSettingsFile%
        }
        if !fastReset
            SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod fast-reset. Download: https://github.com/jan-leila/FastReset/releases", moddir))
        if !sleepBg
            SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod sleepbackground. Download: https://github.com/RedLime/SleepBackground/releases", moddir))
        if !sodium
            SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod sodium. Download: https://github.com/jan-leila/sodium-fabric/releases", moddir))
        if !srigt
            SendLog(LOG_LEVEL_WARNING, Format("Directory {1} missing recommended mod SpeedRunIGT. Download: https://redlime.github.io/SpeedRunIGT/", moddir))
        FileRead, settings, %optionsFile%
        if InStr(settings, "fullscreen:true") {
            ControlSend, ahk_parent, % Format("{Blind}{{1}}", this.fsKey), % Format("ahk_pid {1}", this.pid)
        }
        SendLog(LOG_LEVEL_INFO, Format("Finished instance verification for directory: {1}", mcDir))
    }
}