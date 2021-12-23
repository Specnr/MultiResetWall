from obswebsocket import obsws, requests
import sys

host = "localhost"
port = 4444
password = ""  # Edit this if you use a password (reccomended)
scene_name_format = "MultiMC-"  # Edit this
wall_scene_name = "Wall"    # Edit this

ws = obsws(host, port, password)
ws.connect()
scenes = ws.call(requests.GetSceneList())
if bool(int(sys.argv[1])):
    ws.call(requests.SetCurrentScene(f"{scene_name_format}{sys.argv[2]}"))
else:
    ws.call(requests.SetCurrentScene(f"{wall_scene_name}"))
ws.disconnect()
