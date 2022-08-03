; v0.8
; General settings
global rows := 3 ; Number of row on the wall scene
global cols := 3 ; Number of columns on the wall scene

; Extra features
global windowMode := "W" ; W = windowed mode, F = fullscreen mode, B = borderless windowed
global disableTTS := False
global widthMultiplier := 2.5 ; How wide your instances go to maximize visibility :) (set to 0 for no width change)
global resetSounds := True ; Make a sound when you reset an instance
global lockSounds := True ; Make a sound when you lock an instance
global countAttempts := True ; Makes a text file to count resets
global coop := False ; Automatically opens to LAN when you load in a world
global useObsWebsocket := False ; Allows for > 9 instances (Additional setup required)
global useSingleSceneOBS := False ; Allows for simple OBS setup & Tinder. (Additional setup required)
global audioGui := False ; A simple GUI so the OBS application audio plugin can capture sounds
global wallBypass := False ; If you have at least one locked instance, it will skip the wall and go to it
global multiMode := False ; Never send you back to the wall unless there are no playable instances
global doF1 := False ; Toggle the f1 GUI hiding button on world join and reset

; Delays (Defaults are probably fine)
global spawnProtection := 100 ; Prevent a new instance from being reset for this many milliseconds after the preview is visible
global fullScreenDelay := 100 ; increse if fullscreening issues
global obsDelay := 100 ; increase if not changing scenes in obs
global tinderCheckBuffer := 5 ; When all instances cant reset, how often it checks for an instance in seconds

; Super advanced settings (Do not change unless you know exactly absolutely what you are doing)
; -1 == use macro math to determine thread counts
global affinityType := "B" ; N = no affinity management, B = basic affinity management, A = advanced affinity mangement (best if used with locking+resetAll)
global playThreadsOverride := -1 ; Thread count dedicated to the instance you are playing
global lockThreadsOverride := -1 ; Thread count dedicated to locked instances while on wall
global highThreadsOverride := -1 ; Thread count dedicated to instances that have just been reset but not previewing
global midThreadsOverride := -1 ; Thread count dedicated to loading preview instances on wall
global lowThreadsOverride := -1 ; Thread count dedicated to loading bg instances and idle wall instances
global superLowThreadsOverride := -1 ; Thread count dedicated to idle bg instances

global loadBurstLength := 400 ; How many milliseconds highThreads stays dedicated to an instance after a preview is detected before lowering to midThreads