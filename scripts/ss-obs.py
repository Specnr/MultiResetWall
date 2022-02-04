from obswebsocket import obsws, requests
import sys

host = "localhost"
port = 4444
password = ""  # Edit this if you use a password (reccomended)

inst_count = 10
main_scene = "MainMulti"
mc_source_format = "mc "  # Edit this
wall_scene_name = "Wall"    # Edit this

# If you have the same audio sources on the wall, you need to hide them in main scene
other_hide_on_wall = ["Speed 1.16", "Main", "Secondary"]

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
for i in range(inst_count):
    ws.call(requests.SetSceneItemProperties(
        f"mc {i+1}", visible=int(sys.argv[1]) != 0 and i+1 == int(sys.argv[1])))

ws.disconnect()
