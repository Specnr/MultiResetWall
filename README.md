# MultiResetWall
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/specnr)

## Instructions

Watch the [BRAND NEW Wall Tutorial](https://youtu.be/pVnNEBKC4aU) and read the [common issues support doc](https://bit.ly/3HfHZqQ) if needed.

For new Instance Moving (advanced), see the [tutorial here](https://docs.google.com/document/d/11KRbPlepeOIomj5rmzMrxDrzopOzMp4XvNeBQkq1WfE/edit?usp=sharing).

If further help is needed, feel free to open a ticket in my [Discord server](https://discord.gg/tXxwrYw).

## Usage

To use the macro, run TheWall.ahk and wait for it to say ready. Start up OBS, then start up a [Fullscreen projector](https://youtu.be/9YqZ6Ogv3rk).

On the Fullscreen projector, you have a few default hotkeys (You may customize these hotkeys in the hotkeys.ahk file):
- E: Will reset the instance which your mouse is hovering over
- R: Will play the instance which your mouse is hovering over
- F: Will play the instance which your mouse is hovering over, and reset all of the other ones
- T: Will reset all instances
- Shift + Left Mouse button: Lock instance so "blanket reset" functions skip over it

In a world you can use the following hotkeys:
- U: Exit world and go back to the wall

Other optional hotkey functions include (to use, put the quoted text after a hotkey and double colon in the hotkeys.ahk file):
- "ResetAll(true)": Reset all instances regardless of locked status
- "FocusReset(MousePosToInstNumber(), true)": Play the instance which your mouse is hovering over and reset all the rest regardless of locked status
- "UnlockInstance(MousePosToInstNumber())": Unlock the instance which your mouse is hovering over
- "LockAll()": Lock all instances (add False to the parentheses for it to be silent)
- "UnlockAll()": Unlock all instances (add False to the parentheses for it to be silent)
- "PlayNextLock()": Play to the first locked instance

Use [this world deletion program](https://gist.github.com/Specnr/8a572ac5c5cfdb54eb0dc7d1eb2906a3) to delete worlds, or use the Delete Worlds option in the system tray (Requires Python).

## Themes

This macro supports different themes for lock images and sounds, there are a few ones prebuilt into the `/themes` folder for you to choose, or you can make a custom theme by adding your own `lock.png` and `lock.wav` to the `/themes/custom` folder. To change themes just change the theme setting to be the folder name of whichever theme you want to use.

You can also have the macro pick a random lock image by naming the images `lock1.png`, `lock2.png`, ... etc

## Utility Functions

In the /utils folder, you'll find some helpful scripts which we will add to over time. You can also access some of these by right clicking on the tray icon for TheWall.ahk

### CloseInstances.ahk
This script will simply close all your instances for you. This is also an option in TheWall.ahk tray options

### Startup.ahk
This script will startup your instances for you, however it will only work after your first session.

If you want, you can create a names.txt file in the /data folder with one name per line, and one line per instance to launch your instances in offline mode with custom names.

## Super Advanced Settings

These settings can be useful for optimizing performance, testing code, configuring slightly more advanced things, or for specific use cases.

### Affinity

Affinity is by far the most advanced section but can be used to fine tune performance of resetting and with good tuning can maybe increase instance count

- affinityType: What kind of general affinity management do you want, this does not affect any override settings except -1. Options: No affinity management (N), Basic affinity management, resetting background instances have lower priority (B), Advanced affinity mangement, advanced priority system for wall resetting. Use with locking (A)
- playThreadsOverride: Threads used for the instance you are currently playing. Default by macro math: total threads unless override is set
- lockThreadsOverride: Threads used for instances that are locked while fullscreen projector is focused. Default by macro math: total threads unless override is set
- highThreadsOverride: Threads used for instances loading the "dirt screen" while fullscreen projector is focused. Default by macro math: 95% of threads or total threads minus 2, whichever is higher unless override is set
- midThreadsOverride: Threads used for instances loading a preview (previewBurstLength) after detecting it. Default by macro math: 80% of threads if advanced mode otherwise same as high unless override is set
- lowThreadsOverride: Threads used for instances that have reached (previewLoadPercent) requirement or for any idle instances. Default by macro math: 70% of threads if advanced mode otherwise high unless override is set
- bgLoadThreadsOverride: Threads used for loading background instances. Default by macro math: 40% of threads unless override is set
- previewBurstLength: The length of time in ms that instances spend on highThreads before switching to midThreads after a preview has been detected while fullscreen projector is focused. Default: 400
- previewLoadPercent: The percentage of world gen that must be reached after a preview is detected before lowering to lowThreads. Default: 15

### OBS

These are the OBS hotkey settings. If you want to use more than 9 instances or change the hotkeys that are used for OBS you can change these.

- obsControl: What system the macro use for OBS scene control. The default and reccomended is OBS Controller (C), and all other control types are legacy. The others are: Numpad hotkeys 1-9 (N), Function hotkeys f13-f24, setup script in utils folder (F), Advanced key array, any keys you want, use the obsCustomKeyArray variable (ARR)
- obsWallSceneKey: The key that is pressed when switching to the wall. All obs scene control types use wallSceneKey. Default: 'F12'
- obsCustomKeyArray: Used with advanced key array setting. Add keys inside the brackets in quotes and separated by commas. The index of the key in the array corresponds to the scene that it will be used for. Default: empty
- obsResetMediaKey: The key pressed when any instance is reset with sound. This can be used to play media sources in OBS. Default: none
- obsLockMediaKey: The key pressed when any instance is locked with sound. This can be used to play media sources in OBS. Default: none
- obsUnlockMediaKey: The key pressed when any instance is unlocked with sound. This can be used to play media sources in OBS. Default: none
- obsDelay: The delay between a hotkey press and release, increase if not changing scenes in obs and using a hotkey form of control. Default: 100

### Reset Management

These are values used by the reset manager scripts. They can have minor performance impacts or be used if something doesn't seem to be working quite right.

- beforePauseDelay: Extra delay added before the final pause for a loaded instance. May be needed for very laggy loading. Default: 0
- resetManagementTimeout: Max Time in ms that can pass before reset manager gives up looking for a preview or load line in logs. May be needed if instances become unresetable often, too low can leave instances unpaused. Default: -1 (do not timeout)
- manageResetAfter: Delay before starting reset management log reading loop. Too low might create delayed resets or previews that are not f3+esc paused. Default: 300
- resetManagementLoopDelay: Buffer time for the loop that reads Minecraft logs to check for previews and loads. Lower might decrease pause latencies but increase cpu usage. Default: 70

### Attempts

The paths of the files used for counting attempts. This can make updating attempts through macro versions.

- overallAttemptsFile: File path for overall attempt count. Default: "data/ATTEMPTS.txt"
- dailyAttemptsFile: File path for session attempt count. Default: "data/ATTEMPTS_DAY.txt"

## Credit

- Me
- Mach for efficient reset managers & for affinity management
- Ravalle for a lot of great ideas and code
- Boyenn for Instance Moving code which we modified, and general optimizations
- The collaborators listed for minor enhancements
- PodX12 for some minor enhancements
- Sam Dao (real)
- jojoe77777 for making the original wall macro
