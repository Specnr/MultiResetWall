class Instance {

    #Include %A_ScriptDir%\scripts\Window.ahk
    #Include %A_ScriptDir%\scripts\InstanceGetters.ahk
    #Include %A_ScriptDir%\scripts\InstanceSetters.ahk
    #Include %A_ScriptDir%\scripts\InstanceMethods.ahk

    __New(idx, pid, mcDir) {
        this.idx := idx
        this.pid := pid
        this.mcDir := mcDir
        this.locked := false
        this.playing := false
        this.focus := true
        this.idleFile := Format("{1}idle.tmp", mcDir)
        this.lockFile := Format("{1}lock.tmp", mcDir)
        this.lockImage := Format("{1}lock.png", mcDir)
        this.holdFile := Format("{1}hold.tmp", mcDir)
        this.previewFile := Format("{1}preview.tmp", mcDir)
        this.doubleCheckUnexpectedLoads := true
        this.InitializeFiles()

        this.LaunchResetManager()

        this.window := New this.Window(this.idx, this.pid, this.mcDir)

        this.window.SetAffinity(highBitMask)

        SendLog(LOG_LEVEL_INFO, Format("Instance {1} ready for resetting", this.idx))
    }

    __Delete() {
        this.KillResetManager()
    }

    Reset(bypassLock:=true, extraProt:=0, force:=false) {
        if (!this.GetCanReset(bypassLock, extraProt, force))
            Return

        SendLog(LOG_LEVEL_INFO, Format("Instance {1} valid reset triggered", this.idx))

        this.SendReset()

        this.window.SetAffinity(highBitMask)

        if (mode == "I")
            MoveResetInstance(idx)
        else if (obsControl == "C")
            SendOBSCmd(GetCoverTypeObsCmd("Cover",true,[this]))

        this.Unlock(false)
    }

    Switch(special:=false) {
        if (!this.locked) {
            this.Lock(false, false)
        }

        if (!this.GetCanPlay() && smartSwitch) {
            SwitchInstance(FindBypassInstance())
            return
        } else if !this.GetCanPlay() {
            return
        }

        this.playing := true

        this.SwitchFiles()

        SetAffinities(this.idx)

        this.window.SwitchTo()

        this.window.JoinInstance(special)

        this.SwitchToInstanceObs()
    }

    Exit(nextInst:=-1) {
        this.window.GhostPie()

        this.window.ToggleFullscreen(false)

        this.ExitFiles()

        this.window.Restore()

        SetAffinities(nextInst)

        this.Reset(,,true)

        nextInst := GetNextInstance(this.idx, nextInst)
        if (nextInst <= 0) {
            ToWall(this.idx)
        } else {
            SwitchInstance(nextInst)
        }

        this.window.Widen()

        this.window.SendToBack()

        this.playing := false
    }

    Lock(sound:=true, affinityChange:=true) {
        this.LockFiles()

        this.LockOBS()

        this.locked := true

        if affinityChange
            this.window.SetAffinity(lockBitMask)

        LockSound(sound)
    }

    Unlock(sound:=true) {
        this.UnlockFiles()

        this.UnlockOBS()

        this.locked := false

        UnlockSound(sound)
    }

    LockFiles() {
        if (this.locked) {
            return
        }
        FileCopy, % GetLockImage(), % this.lockImage, 1
        FileSetTime,, % this.lockImage, M
        FileAppend,, % this.lockFile
    }

    UnlockFiles() {
        if (!this.locked) {
            return
        }
        if (obsControl != "C") {
            FileCopy, A_ScriptDir\..\media\unlock.png, % this.lockImage, 1
            FileSetTime,, % this.lockImage, M
        }
        FileDelete, % this.lockFile
    }

    SendReset() {
        if (!this.rmPID) {
            return
        }

        this.window.SendResetInput()

        DetectHiddenWindows, On
        PostMessage, MSG_RESET,,,, % Format("ahk_pid {1}", this.rmPID)
        DetectHiddenWindows, Off
    }

    CloseInstance() {
        WinClose, % Format("ahk_pid {1}", this.pid)
        this.KillResetManager()
    }

    LaunchResetManager() {
        SendLog(LOG_LEVEL_INFO, Format("Running a reset manager: {1} {2} {3} {4} {5}", this.idx, this.pid, this.doubleCheckUnexpectedLoads, mainPID, this.mcDir))
        Run, % Format("""{1}`\scripts`\reset.ahk"" {2} {3} {4} {5} ""{6}", A_ScriptDir, this.idx, this.pid, this.doubleCheckUnexpectedLoads, mainPID, this.mcDir), %A_ScriptDir%,, rmPID
        ; Run, % Format("""{1}`\scripts`\reset.ahk"" {2} {3} {4} {5} ""{6}", A_ScriptDir, this.idx, this.pid, this.doubleCheckUnexpectedLoads, mainPID, this.mcDir), %A_ScriptDir%,, rmPID
        this.rmPID := rmPID
        ; DetectHiddenWindows, On
        ; WinWait, % Format("ahk_pid {1}", this.rmPID)
        ; DetectHiddenWindows, Off
    }

    KillResetManager() {
        DetectHiddenWindows, On
        PostMessage, MSG_KILL,,,, % Format("ahk_pid {1}", this.rmPID)
        WinWaitClose, % Format("ahk_pid {1}", this.rmPID)
        DetectHiddenWindows, Off
        this.window.SetAffinity(GetBitMask(THREAD_COUNT))
    }

    InitializeFiles() {
        if (!FileExist(this.idleFile))
            FileAppend, %A_TickCount%, % this.idleFile
        if FileExist(this.holdFile)
            FileDelete, % this.holdFile
        if FileExist(this.previewFile)
            FileDelete, % this.previewFile
    }
}
