# v0.4.11
from obswebsocket import obsws, requests
import sys
from obsSettings import host, port, password, wall_scene_name, mc_source_format, bg_mc_source_format

ws = obsws(host, port, password)
ws.connect()

isWall, hideInst, showInst, hideMini, showMini = sys.argv[1:]

# Force next inst to show
if int(showInst) != -1:
    ws.call(requests.SetSceneItemProperties(
        f"{mc_source_format}{int(showInst)}", visible=True))
if int(showMini) != -1:
    ws.call(requests.SetSceneItemProperties(
        f"{bg_mc_source_format}{showMini}", visible=True))
# The wall
if int(showInst) == -1 or int(hideInst) == -1:
    ws.call(requests.SetSceneItemProperties(
        wall_scene_name, visible=bool(int(isWall))))
# Hide prev instances
if int(hideMini) != -1:
    ws.call(requests.SetSceneItemProperties(
        f"{bg_mc_source_format}{hideMini}", visible=False))
if int(hideInst) != -1:
    ws.call(requests.SetSceneItemProperties(
        f"{mc_source_format}{hideInst}", visible=False))

ws.disconnect()
