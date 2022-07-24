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
- "LockAll()": Lock all instances
- "UnlockAll()": Unlock all instances

No longer moves worlds, it slows down the macro a lot, use [this world moving macro](https://gist.github.com/Specnr/f7a5450d932a1277fdcd6c141ad7bf6a).

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

## OBS Locked Instance Indicators

Add little locks or any image you want to signal when an instance is locked or not

Note: Depends on OBS Websocket

1) Add an image source to your wall scene in OBS for each instance and name them accordingly (lock1, lock2, lock3...) and position them where you want them to be. For example: ![walllocks](https://user-images.githubusercontent.com/60681673/174759119-e4822c08-6ce1-4b8e-b345-68b15cd23aa9.png)
![locksources](https://user-images.githubusercontent.com/60681673/174758616-d960a51e-c355-4cb9-b748-7b63420731a0.png)
2) Edit the 2 extra settings in obsSettings.py accordingly. For lock_indicator_format put the prefix you used for your lock image sources in OBS.
3) Set lockIndicators in settings.ahk to "True"

After that it should be working. Open a ticket in the [Discord](https://discord.gg/tXxwrYw) if you have any issues or need clarification.

## Credit

- Me
- Ravalle for a lot of great ideas and code
- The collaborators listed for minor enhancements
- PodX12 for some minor enchancements
- Sam Dao (real)
- jojoe77777 for making the original wall macro
