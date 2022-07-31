; v0.8
; General settings
global rows := 3 ; Number of row on the wall scene
global cols := 3 ; Number of columns on the wall scene
global performanceMethod := "N" ; F = Instance Freezing, N = Nothing
global affinity := True ; A funky performance addition, enable for minor performance boost

; Extra features
global fullscreen := False 
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
global lockIndicators := False ; Visual indicator for locked instances (no websocket needed)
global affinityStrength := 0.5 ; for affinity, find a happy medium, max=1.0 (higher means more extreme thread management)

; Delays (Defaults are probably fine)
global resumeDelay := 50 ; increase if instance isnt resetting (or have to press reset twice)
global beforeFreezeDelay := 500 ; increase if doesnt join world
global beforePauseDelay := 0 ; basically the delay before dynamic FPS does its thing
global fullScreenDelay := 100 ; increse if fullscreening issues
global restartDelay := 200 ; increase if saying missing instanceNumber in .minecraft (and you ran setup)
global scriptBootDelay := 6000 ; increase if instance freezes before world gen
global obsDelay := 100 ; increase if not changing scenes in obs
global tinderCheckBuffer := 5 ; When all instances cant reset, how often it checks for an instance in seconds
global spawnProtection := 100 ; Prevent a new instance from being reset for this many milliseconds after the preview is visible