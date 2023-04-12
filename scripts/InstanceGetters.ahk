GetIdx() {
    return this.idx
}

GetPID() {
    return this.pid
}

GetMcDir() {
    return this.mcDir
}

GetLocked() {
    return this.locked
}

GetPlaying() {
    return this.playing
}

GetFocus() {
    return this.focus
}

GetIdle() {
    return FileExist(this.idleFile)
}

GetHeld() {
    return FileExist(this.holdFile)
}

GetPreviewing() {
    return FileExist(this.previewFile)
}

GetPreviewTime() {
    FileRead, previewStartTime, % this.previewFile
    previewStartTime += 0
    previewTime := A_TickCount - previewStartTime
    return previewTime
}

GetCanPlay() {
    if (this.GetIdle() || mode == "C") {
        return true
    }
    
    return false
}

GetCanReset(bypassLock:=true, extraProt:=0, force:=false) {

    if (force) {
        SendLog(LOG_LEVEL_INFO, "forced")
        return true
    }
  
    if (this.GetLocked() && !bypassLock) {
        SendLog(LOG_LEVEL_INFO, "locked (with no bypass)")
        return false
    }
  
    if (this.GetHeld()) {
        SendLog(LOG_LEVEL_INFO, "held")
        return false
    }

    if (this.GetPreviewTime() < spawnProtection + extraProt) {
        SendLog(LOG_LEVEL_INFO, "protected")
        return false
    }
  
    if (this.GetPlaying()) {
        SendLog(LOG_LEVEL_INFO, "playing")
        return false
    }
  
    SendLog(LOG_LEVEL_INFO, "good")
    return true
}