# v0.3.5
from obswebsocket import obsws, requests
import sys
from obsSettings import host, port, password, wall_scene_name, mc_source_format, bg_mc_source_format

ws = obsws(host, port, password)
ws.connect()

# Force next inst to show
if int(sys.argv[2]) != 0:
    ws.call(requests.SetSceneItemProperties(
        f"{mc_source_format}{int(sys.argv[2])}", visible=True))  # Show BG
if int(sys.argv[4]) != 0:
    for i in range(int(sys.argv[3])):
        ws.call(requests.SetSceneItemProperties(
            f"{bg_mc_source_format}{i+1}", visible=i+1 == int(sys.argv[4])))
# The wall
ws.call(requests.SetSceneItemProperties(
    wall_scene_name, visible=int(sys.argv[2]) == 0))
# Actual instances
for i in range(int(sys.argv[3])):
    ws.call(requests.SetSceneItemProperties(
        f"{mc_source_format}{i+1}", visible=int(sys.argv[2]) != 0 and i+1 == int(sys.argv[2])))

ws.disconnect()
