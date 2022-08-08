; v0.8
; General settings
global rows := 3 ; Number of row on the wall scene
global cols := 3 ; Number of columns on the wall scene
global mode := "W" ; W = Normal wall, B = Wall bypass (skip to next locked), M = Modern multi (send to wall when none loaded), C = Classic original multi (always force to next instance)
global windowMode := "W" ; W = windowed mode, F = fullscreen mode, B = borderless windowed

; Extra features
global disableTTS := False
global widthMultiplier := 2.5 ; How wide your instances go to maximize visibility :) (set to 0 for no width change)
global resetSounds := True ; Make a sound when you reset an instance
global lockSounds := True ; Make a sound when you lock an instance
global coop := False ; Automatically opens to LAN when you load in a world
global useObsWebsocket := False ; Allows for > 9 instances (Additional setup required)
global useSingleSceneOBS := False ; Allows for simple OBS setup & Tinder. (Additional setup required)
global audioGui := False ; A simple GUI so the OBS application audio plugin can capture sounds
global doF1 := False ; Toggle the f1 GUI hiding button on world join and reset

; Delays (Defaults are probably fine)
global spawnProtection := 100 ; Prevent a new instance from being reset for this many milliseconds after the preview is visible
global fullScreenDelay := 100 ; increse if fullscreening issues
global obsDelay := 100 ; increase if not changing scenes in obs
global tinderCheckBuffer := 5 ; When all instances cant reset, how often it checks for an instance in seconds

; Super advanced settings (Do not change unless you know exactly absolutely what you are doing

; Affinity
; -1 == use macro math to determine thread counts
global affinityType := "B" ; N = no affinity management, B = basic affinity management, A = advanced affinity mangement (best if used with locking+resetAll)
global playThreadsOverride := -1 ; Thread count dedicated to the instance you are playing
global lockThreadsOverride := -1 ; Thread count dedicated to locked instances while on wall
global highThreadsOverride := -1 ; Thread count dedicated to instances that have just been reset but not previewing
global midThreadsOverride := -1 ; Thread count dedicated to loading preview instances on wall
global lowThreadsOverride := -1 ; Thread count dedicated to loading bg instances and idle wall instances
global superLowThreadsOverride := -1 ; Thread count dedicated to idle bg instances
global loadBurstLength := 400 ; How many milliseconds the prior thread count stays dedicated to an instance before switching to the next stage while ACTIVELY LOADING INSTANCES (less important for basic affinity)

; OBS
global obsSceneControlType := "N" ; N = Numpad hotkeys (up to 9 instances), F = Function hotkeys f13-f24 (up to 12 instances), A = advanced key array (too many instances)
global obsWallSceneKey := "F12" ; All obs scene control types use wallSceneKey
global obsCustomKeyArray := [] ; Must be used with advanced key array control type. Add keys in quotes separated by commas. The index in the array corresponds to the scene
global obsResetMediaKey := "" ; Key pressed on any instance reset with sound (used for playing reset media file in obs for recordable/streamable resets and requires addition setup to work)
global obsLockMediaKey := "" ; Key pressed on any lock instance with sound (used for playing lock media file in obs for recordable/streamable lock sounds and requires addition setup to work)
global obsUnlockMediaKey := "" ; Key pressed on any unlock instance with sound (used for playing unlock media file in obs for recordable/streamable unlock sounds and requires addition setup to work)

; Reset Management
global resetManagementTimeout := 20000 ; Milliseconds that pass before reset manager gives up. Too high may leave unresetable instances, too low will leave instances unpaused. Default (20000) likely fine
global manageResetAfter := 200 ; Delay before starting reset management log reading loop. Default (200) likely fine
global resetManagementLoopDelay := 70 ; Buffer time between log lines check in reset management loop. Lowering will decrease possible pause latencies but increase cpu usage of reset managers. Default (70) likely fine

; Attempts
global overallAttemptsFile := "data/ATTEMPTS.txt" ; File to write overall attempt count to
global dailyAttemptsFile := "data/ATTEMPTS_DAY.txt" ; File to write daily attempt count to