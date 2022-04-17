# v0.5
import os
from obswebsocket import obsws, requests
import time
import obsSettings as config

ws = obsws(config.host, config.port, config.password)
ws.connect()

last_completed_line = -1
ops_file = "./obs.ops"


def tinderMotion(data):
    hide, show = data
    if int(show) > 0:
        ws.call(requests.SetSceneItemProperties(
            f"{config.bg_mc_source_format}{int(show)}", visible=True))
    if int(show) > 0:
        ws.call(requests.SetSceneItemProperties(
            f"{config.bg_mc_source_format}{int(hide)}", visible=False))


def switchInstance(isSS, data):
    if isSS:
        hide, show, hideMini, showMini = data
        # Show mini and instance
        ws.call(requests.SetSceneItemProperties(
            f"{config.mc_source_format}{show}", visible=True))
        ws.call(requests.SetSceneItemProperties(
            f"{config.bg_mc_source_format}{showMini}", visible=True))
        # Hide wall if needed
        if int(show) == -1 or int(hide) == -1:
            ws.call(requests.SetSceneItemProperties(
                config.wall_scene_name, visible=False))
        # Hide mini and instance
        ws.call(requests.SetSceneItemProperties(
            f"{config.mc_source_format}{hide}", visible=False))
        ws.call(requests.SetSceneItemProperties(
            f"{config.bg_mc_source_format}{hideMini}", visible=False))
    else:
        ws.call(requests.SetCurrentScene(
            f"{config.scene_name_format}{data[0]}"))


def toWall(isSS, data):
    if isSS:
        # Show the wall
        ws.call(requests.SetSceneItemProperties(
            config.wall_scene_name, visible=True))
        # Hide the instance
        ws.call(requests.SetSceneItemProperties(
            f"{config.mc_source_format}{data[0]}", visible=False))
    else:
        ws.call(requests.SetCurrentScene(f"{config.wall_scene_name}"))


breaking = False
while True:
    if (os.path.exists(ops_file)):
        max_idx = sum(1 for _ in open(ops_file)) - 1
        if max_idx > last_completed_line:
            with open(ops_file) as ops:
                for i, line in enumerate(ops):
                    if i > last_completed_line:
                        last_completed_line += 1
                        splt = line.split(' ')
                        splt[-1] = splt[-1].strip()
                        op, args = splt[0], splt[1:]
                        if op == "xx":
                            breaking = True
                            break
                        elif op == "tm":
                            tinderMotion(args)
                        else:
                            isSS = op[:2] == "ss"
                            if op[-2] + op[-1] == "tw":
                                toWall(isSS, args)
                            else:
                                switchInstance(isSS, args)
        if breaking:
            break
    time.sleep(1/config.checks_per_second)

ws.disconnect()
