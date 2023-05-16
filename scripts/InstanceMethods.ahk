; All methods here are only called by the Instance class and not called from outside the Instance class

SwitchToInstanceObs() {
    obsKey := ""
    if (obsControl == "C") {
        SendOBSCmd("Play," . this.idx)
        return
    } else if (obsControl == "N") {
        obsKey := "Numpad" . this.idx
    } else if (obsControl == "F") {
        obsKey := "F" . (this.idx+12)
    } else if (obsControl == "ARR") {
        obsKey := obsCustomKeyArray[this.idx]
    }
    Send {%obsKey% down}
    Sleep, %obsDelay%
    Send {%obsKey% up}
}

SwitchFiles() {
    FileAppend,, % this.holdFile
    FileDelete, data/instance.txt
    FileAppend, % this.idx, data/instance.txt
    FileAppend,, % Format("{1}/sleepbg.lock", USER_PROFILE)
}

ExitFiles() {
    FileDelete, % this.holdFile
    FileDelete, % this.killFile
    FileDelete, % Format("{1}/sleepbg.lock", USER_PROFILE)
}

LockOBS() {
    if (this.GetLocked()) {
        return
    }
    if (obsControl == "C" && mode != "I") {
        SendOBSCmd(GetCoverTypeObsCmd("Lock",true,[this]))
    }
}

UnlockOBS() {
    if (!this.GetLocked()) {
        return
    }
    if (obsControl == "C" && mode != "I") {
        SendOBSCmd(GetCoverTypeObsCmd("Lock",false,[this]))
    }
}