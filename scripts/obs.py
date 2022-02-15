# v0.4.6
from obswebsocket import obsws, requests
import sys
from obsSettings import host, port, password, wall_scene_name, scene_name_format

ws = obsws(host, port, password)
ws.connect()

isWall, sceneNum = sys.argv[1:]

nextScene = f"{wall_scene_name}" if int(
    isWall) else f"{scene_name_format}{sceneNum}"

ws.call(requests.SetCurrentScene(nextScene))
ws.disconnect()
