; All Instance class basic getter methods, methods simply returning an instance variable are only called outside of the class

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
    if (this.GetIdle() || mode == "C")
        return true

    return false
}

GetCanReset(bypassLock:=true, extraProt:=0, force:=false) {

    if (!this.rmPID)
        return false

    if (force)
        return true

    if (this.locked && !bypassLock)
        return false

    if (this.GetHeld())
        return false

    if (this.GetPreviewTime() < spawnProtection + extraProt)
        return false

    if (this.playing)
        return false

    return true
}
