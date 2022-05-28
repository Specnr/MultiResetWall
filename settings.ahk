; v0.5
; General settings
global rows := 3 ; Number of row on the wall scene
global cols := 3 ; Number of columns on the wall scene
global performanceMethod := "S" ; F = Instance Freezing, S = Settings Changing RD, N = Nothing
global affinity := True ; A funky performance addition, enable for minor performance boost
global worldPreviewResetKey := "H" ; Update this to the key you set to reset in world preview (default: H)
global worldPreviewFreezeKey := "J" ; Update this to the key you set to freeze in world preview (default: J)
global freezePreviewAfter := 1 ; Freezes the preview after this many seconds (for performance)

; Extra features
global fullscreen := False 
global disableTTS := False
global wideResets := True ; Make windows wide on reset to maximize visibility
global widthMultiplier := 2.5 ; How wide your instances go :)
global resetSounds := True ; Make a sound when you reset an instance
global lockSounds := True ; Make a sound when you lock an instance
global countAttempts := True ; Makes a text file to count resets
global coop := False ; Automatically opens to LAN when you load in a world
global useObsWebsocket := False ; Allows for > 9 instances (Additional setup required)
global useSingleSceneOBS := False ; Allows for simple OBS setup & Tinder. Requires furture setup video
global audioGui := False ; A simple GUI so the OBS application audio plugin can capture sounds
global wallBypass := False ; If you have at least one locked instance, it will skip the wall and go to it
global multiMode := False ; Never send you back to the wall unless there are no playable instances

; Settings reset settings
; Set to 0 if you dont want to settings reset
; Sense and FOV may be off by 1, mess around with +-1 if you care about specifics
global renderDistance := 18
global entityDistance := 500
global FOV := 90 ; For quake pro put 110
global quakeProResets := True ; Quake pro for previews
global mouseSensitivity := 35
global lowRender := 5 ; For settings change performance method

; Delays
global resumeDelay := 50 ; increase if instance isnt resetting (or have to press reset twice)
global maxLoops := 50 ; increase if instance isnt resetting (or have to press reset twice)
global beforeFreezeDelay := 500 ; increase if doesnt join world
global beforePauseDelay := 500 ; basically the delay before dynamic FPS does its thing
global fullScreenDelay := 270 ; increse if fullscreening issues
global restartDelay := 200 ; increase if saying missing instanceNumber in .minecraft (and you ran setup)
global scriptBootDelay := 6000 ; increase if instance freezes before world gen
global obsDelay := 100 ; increase if not changing scenes in obs
global settingsDelay := 10 ; increase if settings arent changing
global lowBitmaskMultiplier := 0.75 ; for affinity, find a happy medium, max=1.0
global tinderCheckBuffer := 5 ; When all instances cant reset, how often it checks for an instance in seconds