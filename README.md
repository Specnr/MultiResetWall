# MultiResetWall
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/specnr)

## Instructions

Watch the [NEW Multi Instance & Wall Setup Video](https://youtu.be/0xAHMW93MQw)

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

Use [this world deletion program](https://gist.github.com/Specnr/8a572ac5c5cfdb54eb0dc7d1eb2906a3) to delete worlds.

## OBS Locked Instance Indicators

Adds the media/lock.png on screen whenever you lock an instance (does NOT require OBS Websocket)

1) Start the macro, then lock all instances
2) This will create an image in each of your instance's .minecraft folder named lock.png, add an Image source to OBS for each corresponding instance and use the lock image created in that specific instance's .minecraft folder.

Make sure you AREN'T adding the lock.png file that is included in the media folder. You may customize your lock images by simply replacing the png files in your wall media folder. Changing the files in your .minecraft folders won't do anything.

After that it should be working. Open a ticket in the [Discord](https://discord.gg/tXxwrYw) if you have any issues or need clarification.

## Utility Functions

In the /utils folder, you'll find some helpful scripts which we will add to over time. You can also access some of these by right clicking on the tray icon for TheWall.ahk

### Startup.ahk
This script will startup your instances for you, however it will only work after your first session.

If you want, you can create a names.txt file in the /data folder with one name per line, and one line per instance to launch your instances in offline mode with custom names.

### CloseInstances.ahk
This script will simply close all your instances for you. This is also an option in TheWall.ahk tray options

### setFunctionKeys.ahk
This script is used for setting function hotkeys f13-f24 in your OBS hotkeys if you choose to use "F" or "A" for obsSceneControlType which allows for more than 9 instances.

### Delete Worlds
This is a tray option for deleting ALL old worlds in your current instances. If you do not have this option it means the macro was not able to find a python install. After starting just wait until it tells you it's done.

## OBS Websocket

1) Download [Python 3.7+](https://www.python.org/downloads/)
2) Install [OBS websocket](https://obsproject.com/forum/resources/obs-websocket-remote-control-obs-studio-from-websockets.466/)
3) Open up command prompt, and run this command in `pip install obs-websocket-py`
4) Now, open up obsSettings.py in whatever text editor you want. 
5) For scene_name_format you want to put in whatever the prefix of all your scenes are. 
6) For wall_scene_name, its pretty self explanetory, just put in the scene name of your wall.
7) Now, for the password, you can put in a password if you want, and if you use it you can go to `Tools -> WebSockets Server Settings -> Enable Authentication` and then put in whatever password you want. Then you can put the same password in the password variable quotes.

After that it should be working. Open a ticket in the [Discord](https://discord.gg/tXxwrYw) if you have any issues or need clarification.

## Single Scene OBS

This removes scene switching to lighten the load on OBS. It lowers lag also allows for the "Tinder" background resetting method

Note: If you don't want you use Tinder, ignore anything related to it below.

1) Follow the OBS websocket tutorial above
2) You need 2 scenes: one which is just the wall, and the other which is our main scene. Whatever you call these, make sure it reflects in obsSettings.py
3) The wall scene will be the same as usual, but if using Tinder, put your Tinder sources behind the wall sources so they match titles on startup.
4) The main scene will have three levels: The wall level, the instances level, and the Tinder level. Put your sources in order from top to bottom with those priorities in mind. 
5) Make sure your Tinder sources follow the bg_mc_source_format outlined in obsSettings.py, and are independant from your regular instance sources

After that it should be working. Open a ticket in the [Discord](https://discord.gg/tXxwrYw) if you have any issues or need clarification.

## Super Advanced Settings

These settings can be useful for optimizing performance, testing code, configuring slightly more advanced things, or for specific use cases.

# Affinity

Affinity is by far the most advanced section but can be used to fine tune performance of resetting and with good tuning can maybe increase instance count

- affinityType: What kind of general affinity management do you want, this does not affect any override settings except -1. Options: No affinity management (N), Basic affinity management, resetting background instances have lower priority (B), Advanced affinity mangement, advanced priority system for wall resetting. Use with locking (A)
- superHighThreadsOverride: Threads used for the instance you are currently playing or instances that are locked while fullscreen projector is focused. Default by macro math: total threads unless override is set
- highThreadsOverride: Threads used for instances loading the "dirt screen" while fullscreen projector is focused. Default by macro math: 95% of threads or total threads minus 2, whichever is higher unless override is set
- midThreadsOverride: Threads used for instances loading a preview (previewBurstLength) after detecting it. Default by macro math: 65% of threads if advanced mode otherwise same as high unless override is set
- lowThreadsOverride: Threads used for instances that have reached (previewLoadPercent) requirement or for any idle instances. Default by macro math: 5% of threads if advanced mode otherwise high unless override is set
- bgLoadThreadsOverride: Threads used for "dirt screen", (previewBurstLength) period, and locked instances for all bg instances. Default by macro math: 40% of threads unless override is set
- previewBurstLength: The length of time in ms that instances spend on highThreads before switching to midThreads after a preview has been detected while fullscreen projector is focused. Default: 300
- loadedBurstLength: The length of time that instances are increased to midThreads after a full load is detected while fullscreen projector is focused. Default: 300
- previewLoadPercent: The percentage of world gen that must be reached after a preview is detected before lowering to lowThreads. Default: 10

# OBS

These are the OBS hotkey settings. If you want to use more than 9 instances or change the hotkeys that are used for OBS you can change these.

- obsSceneControlType: What kind of hotkeys should the macro use for OBS scene control. Options: Numpad hotkeys 1-9 (N), Function hotkeys f13-f24, setup script in utils folder (F), Advanced key array, any keys you want, use the obsCustomKeyArray variable (A)
- obsWallSceneKey: The key that is pressed when switching to the wall. All obs scene control types use wallSceneKey. Default: 'F12'
- obsCustomKeyArray: Used with advanced key array setting. Add keys inside the brackets in quotes and separated by commas. The index of the key in the array corresponds to the scene that it will be used for. Default: empty
- obsResetMediaKey: The key pressed when any instance is reset with sound. This can be used to play media sources in OBS. Default: none
- obsLockMediaKey: The key pressed when any instance is locked with sound. This can be used to play media sources in OBS. Default: none
- obsUnlockMediaKey: The key pressed when any instance is unlocked with sound. This can be used to play media sources in OBS. Default: none

# Reset Management

These are values used by the reset manager scripts. They can have minor performance impacts or be used if something doesn't seem to be working quite right.

- beforePauseDelay: Extra delay added before the final pause for a loaded instance. May be needed for very laggy loading. Default: 0
- resetManagementTimeout: Max Time in ms that can pass before reset manager gives up looking for a preview or load line in logs. May be needed if instances become unresetable often, too low can leave instances unpaused. Default: -1 (do not timeout)
- manageResetAfter: Delay before starting reset management log reading loop. Too low might create delayed resets or previews that are not f3+esc paused. Default: 300
- resetManagementLoopDelay: Buffer time for the loop that reads Minecraft logs to check for previews and loads. Lower might decrease pause latencies but increase cpu usage. Default: 70
- doubleCheckUnexpectedLoads: If you plan to use the wall without World Preview mod you should disable this. If you reset right when an instance finishes loading it will detect the load and need to double check that there was just a reset. Default: True

# Attempts

The paths of the files used for counting attempts. This can make updating attempts through macro versions.

- overallAttemptsFile: File path for overall attempt count. Default: "data/ATTEMPTS.txt"
- dailyAttemptsFile: File path for session attempt count. Default: "data/ATTEMPTS_DAY.txt"

## Credit

- Me
- Mach for efficient reset managers & for affinity management
- Ravalle for a lot of great ideas and code
- Boyenn for the better lock indication idea
- The collaborators listed for minor enhancements
- PodX12 for some minor enhancements
- Sam Dao (real)
- jojoe77777 for making the original wall macro