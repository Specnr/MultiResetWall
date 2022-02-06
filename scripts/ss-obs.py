from obswebsocket import obsws, requests
import sys
from obsSettings import host, port, password, wall_scene_name, other_hide_on_wall

ws = obsws(host, port, password)
ws.connect()

# Scene-specific things
for other in other_hide_on_wall:
    ws.call(requests.SetSceneItemProperties(
        other, visible=int(sys.argv[1]) != 0))
# Force next inst to show
if int(sys.argv[1]) != 0:
    ws.call(requests.SetSceneItemProperties(
        f"mc {int(sys.argv[1])}", visible=True))
# The wall
ws.call(requests.SetSceneItemProperties(
    wall_scene_name, visible=int(sys.argv[1]) == 0))
# Actual instances
for i in range(int(sys.argv[2])):
    ws.call(requests.SetSceneItemProperties(
        f"mc {i+1}", visible=int(sys.argv[1]) != 0 and i+1 == int(sys.argv[1])))

ws.disconnect()
