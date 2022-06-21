# v0.5
import os
from obswebsocket import obsws, requests
import time
import obsSettings as config

ws = obsws(config.host, config.port, config.password)
try:
    ws.connect()
    print("connected")
except:
    print("failed (reason unknown) to connect, exiting")
    quit()

last_completed_obs_line = -1
last_completed_li_line = -1
ops_file = "./scripts/obs.ops"
li_file = "./scripts/li.ops"


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
        try:
            ws.call(requests.SetCurrentScene(
                f"{config.scene_name_format}{data[0]}"))
            print("si "+data[0]+": "+str(ws.call(requests.SetCurrentScene(f"{config.scene_name_format}{data[0]}"))).split("called: ", 1)[1])
        except:
            print("si "+data[0]+": failed (reason unknown) (reason unknown)")


def toWall(isSS, data):
    if isSS:
        # Show the wall
        ws.call(requests.SetSceneItemProperties(
            config.wall_scene_name, visible=True))
        # Hide the instance
        ws.call(requests.SetSceneItemProperties(
            f"{config.mc_source_format}{data[0]}", visible=False))
    else:
        try:
            ws.call(requests.SetCurrentScene(f"{config.wall_scene_name}"))
            print("tw: "+str(ws.call(requests.SetCurrentScene(f"{config.wall_scene_name}"))).split("called: ", 1)[1])
        except:
            print("tw: failed (reason unknown)")


def lockIndicator(data):
    lock, which = data
    if lock == "l":
        lock = True
    else:
        lock = False
    if which == "a":
        for i in range(config.instances):
            try:
                ws.call(requests.SetSceneItemProperties(
                    f"{config.lock_indicator_format}{i+1}", visible=lock))
                print("li "+str((i+1))+" "+str(lock)+": "+str(ws.call(requests.SetSceneItemProperties(f"{config.lock_indicator_format}{i+1}", visible=lock))).split("called: ",1)[1])
            except:
                print("li "+str((i+1))+" "+str(lock)+": failed (reason unknown)")
    else:
        try:
            ws.call(requests.SetSceneItemProperties(
                f"{config.lock_indicator_format}{which}", visible=lock))
            print("li "+str(which)+" "+str(lock)+": "+str(ws.call(requests.SetSceneItemProperties(f"{config.lock_indicator_format}{which}", visible=lock))).split("called: ",1)[1])
        except:
            print("li "+str(which)+" "+str(lock)+": failed (reason unknown)")


breaking = False
while True:
    if (os.path.exists(li_file)):
        max_idx = sum(1 for _ in open(li_file)) - 1
        if max_idx > last_completed_li_line:
            with open(li_file) as li:
                for i, line in enumerate(li):
                    if i > last_completed_li_line:
                        last_completed_li_line += 1
                        splt = line.split(' ')
                        splt[-1] = splt[-1].strip()
                        op, args = splt[0], splt[1:]
                        if op == "li":
                            lockIndicator(args)
                        else:
                            print("Unexpected item in bagging area!")
    if (os.path.exists(ops_file)):
        max_idx = sum(1 for _ in open(ops_file)) - 1
        if max_idx > last_completed_obs_line:
            with open(ops_file) as ops:
                for i, line in enumerate(ops):
                    if i > last_completed_obs_line:
                        last_completed_obs_line += 1
                        splt = line.split(' ')
                        splt[-1] = splt[-1].strip()
                        op, args = splt[0], splt[1:]
                        if op == "xx":
                            breaking = True
                            print("stopping from \"xx\"")
                            break
                        elif op == "tm":
                            tinderMotion(args)
                        elif op == "li":
                            lockIndicator(args)
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
print("disconnected and exiting")