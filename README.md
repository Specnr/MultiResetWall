# MultiResetWall
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/specnr)

## Instructions

Watch the [NEW Multi Instance & Wall Setup Video](https://youtu.be/0xAHMW93MQw)

If further help is needed, feel free to open a ticket in my [Discord server](https://discord.gg/tXxwrYw).

## Usage

To use the macro, run TheWall.ahk and wait for it to say ready. Start up OBS, then start up a [Fullscreen projector](https://youtu.be/9YqZ6Ogv3rk).

On the Fullscreen projector, you have a few default hotkeys (You may customize these hotkeys in the hotkeys.ahk file): 
- (1-9): Will reset the instance with the corresponding number
- Shift + (1-9): Will play the instance with the corresponding number
- E: Will reset the instance which your mouse is hovering over
- R: Will play the instance which your mouse is hovering over
- F: Will play the instance which your mouse is hovering over, and reset all of the other ones
- T: Will reset all instances
- Shift + Left Mouse button: Lock instance so "blanket reset" functions skip over it

Other optional hotkey functions include (to use, put the quoted text after a hotkey and double colon in the hotkeys.ahk file):
- "ResetAll(true)": Reset all instances regardless of locked status
- "FocusReset(MousePosToInstNumber(), true)": Play the instance which your mouse is hovering over and reset all the rest regardless of locked status
- "UnlockInstance(MousePosToInstNumber())": Unlock the instance which your mouse is hovering over
- "LockAll()": Lock all instances (add False to the parentheses for it to be silent)
- "UnlockAll()": Unlock all instances (add False to the parentheses for it to be silent)
- "PlayNextLock()": Play to the first locked instance (add True in the parentheses to reset all other non-locked instances, add 2 True separated by a comma to reset all other instances regardless of locks) (for use on wall only)

Use [this world deletion program](https://gist.github.com/Specnr/8a572ac5c5cfdb54eb0dc7d1eb2906a3) to delete worlds, or use the Delete Worlds option in the system tray (Requires Python).

## OBS Locked Instance Indicators

Adds the media/lock.png on screen whenever you lock an instance (does NOT require OBS Websocket)

1) Start the macro, then lock all instances
2) This will create an image in each of your instance's .minecraft folder named lock.png, add an Image source to OBS for each corresponding instance and use the lock image created in that specific instance's .minecraft folder.

Make sure you AREN'T adding the lock.png file that is included in the media folder. You may customize your lock images by simply replacing the png files in your wall media folder. Changing the files in your .minecraft folders won't do anything.

## Utility Functions

In the /utils folder, you'll find some helpful scripts which we will add to over time. You can also access some of these by right clicking on the tray icon for TheWall.ahk

### CloseInstances.ahk
This script will simply close all your instances for you. This is also an option in TheWall.ahk tray options

### setFunctionKeys.ahk
This script is used for setting function hotkeys f13-f24 in your OBS hotkeys if you choose to use "F" or "A" for obsSceneControlType which allows for more than 9 instances.

### Setup-OBS.exe
This is a program that generates a scene collection for you which you can import in OBS, which also includes settings for the Advanced Scene Switcher (see below for info) to eliminate OBS setup time. All files are generated into the data folder.

### Startup.ahk
This script will startup your instances for you, however it will only work after your first session.

If you want, you can create a names.txt file in the /data folder with one name per line, and one line per instance to launch your instances in offline mode with custom names.

## Advanced Scene Switching

This is a much better OBS Websocket alternative which allows us to control all OBS actions without any hotkeys, including Tinder-style background resetting.

Setting this up is simple:
- Make sure to run the macro at least once with all instances open
- Download the [Advanced Scene Switcher](https://obsproject.com/forum/resources/advanced-scene-switcher.395/) plugin and install it
- Run the Setup-OBS.exe in the utils folder. This will generate a file in your data folder called `sceneCollection.json`.
- Hit `Import` under the `Scene Collection` tab in OBS, and select this file.

## Super Advanced Settings

These settings can be useful for optimizing performance, testing code, configuring slightly more advanced things, or for specific use cases.

### Affinity

Affinity is by far the most advanced section but can be used to fine tune performance of resetting and with good tuning can maybe increase instance count

- affinityType: What kind of general affinity management do you want, this does not affect any override settings except -1. Options: No affinity management (N), Basic affinity management, resetting background instances have lower priority (B), Advanced affinity mangement, advanced priority system for wall resetting. Use with locking (A)
- superHighThreadsOverride: Threads used for the instance you are currently playing or instances that are locked while fullscreen projector is focused. Default by macro math: total threads unless override is set
- highThreadsOverride: Threads used for instances loading the "dirt screen" while fullscreen projector is focused. Default by macro math: 95% of threads or total threads minus 2, whichever is higher unless override is set
- midThreadsOverride: Threads used for instances loading a preview (previewBurstLength) after detecting it. Default by macro math: 80% of threads if advanced mode otherwise same as high unless override is set
- lowThreadsOverride: Threads used for instances that have reached (previewLoadPercent) requirement or for any idle instances. Default by macro math: 70% of threads if advanced mode otherwise high unless override is set
- bgLoadThreadsOverride: Threads used for loading background instances. Default by macro math: 40% of threads unless override is set
- previewBurstLength: The length of time in ms that instances spend on highThreads before switching to midThreads after a preview has been detected while fullscreen projector is focused. Default: 300
- previewLoadPercent: The percentage of world gen that must be reached after a preview is detected before lowering to lowThreads. Default: 10

### OBS

These are the OBS hotkey settings. If you want to use more than 9 instances or change the hotkeys that are used for OBS you can change these.

- obsSceneControlType: What kind of hotkeys should the macro use for OBS scene control. Options: Numpad hotkeys 1-9 (N), Function hotkeys f13-f24, setup script in utils folder (F), Advanced key array, any keys you want, use the obsCustomKeyArray variable (A)
- obsWallSceneKey: The key that is pressed when switching to the wall. All obs scene control types use wallSceneKey. Default: 'F12'
- obsCustomKeyArray: Used with advanced key array setting. Add keys inside the brackets in quotes and separated by commas. The index of the key in the array corresponds to the scene that it will be used for. Default: empty
- obsResetMediaKey: The key pressed when any instance is reset with sound. This can be used to play media sources in OBS. Default: none
- obsLockMediaKey: The key pressed when any instance is locked with sound. This can be used to play media sources in OBS. Default: none
- obsUnlockMediaKey: The key pressed when any instance is unlocked with sound. This can be used to play media sources in OBS. Default: none

### Reset Management

These are values used by the reset manager scripts. They can have minor performance impacts or be used if something doesn't seem to be working quite right.

- beforePauseDelay: Extra delay added before the final pause for a loaded instance. May be needed for very laggy loading. Default: 0
- resetManagementTimeout: Max Time in ms that can pass before reset manager gives up looking for a preview or load line in logs. May be needed if instances become unresetable often, too low can leave instances unpaused. Default: -1 (do not timeout)
- manageResetAfter: Delay before starting reset management log reading loop. Too low might create delayed resets or previews that are not f3+esc paused. Default: 300
- resetManagementLoopDelay: Buffer time for the loop that reads Minecraft logs to check for previews and loads. Lower might decrease pause latencies but increase cpu usage. Default: 70
- doubleCheckUnexpectedLoads: If you plan to use the wall without World Preview mod you should disable this. If you reset right when an instance finishes loading it will detect the load and need to double check that there was just a reset. Default: True

## Credit

- Me
- Mach for efficient reset managers & for affinity management
- Ravalle for a lot of great ideas and code
- Boyenn for the better lock indication idea
- The collaborators listed for minor enhancements
- PodX12 for some minor enhancements
- Sam Dao (real)
- jojoe77777 for making the original wall macro
