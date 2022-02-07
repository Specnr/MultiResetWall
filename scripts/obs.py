# v0.3.5
from obswebsocket import obsws, requests
import sys
from obsSettings import host, port, password, wall_scene_name, scene_name_format

ws = obsws(host, port, password)
ws.connect()
scenes = ws.call(requests.GetSceneList())
if bool(int(sys.argv[1])):
    ws.call(requests.SetCurrentScene(f"{scene_name_format}{sys.argv[2]}"))
else:
    ws.call(requests.SetCurrentScene(f"{wall_scene_name}"))
ws.disconnect()
