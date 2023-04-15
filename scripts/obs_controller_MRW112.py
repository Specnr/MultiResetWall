# v1.3.0

# cmd formatting:
# cmd[0] specifies command, later args are for cmd args
# cmd[0]: "ToWall" goes to wall scene
# cmd[0]: "Play" goes to main/playing scene, cmd[1] specifies instance to play
# cmd[0]: "Lock" shows or hides lock, cmd[1] specifies which lock, cmd[2] specifies to show or hide (1 = show, 0 = hide)

import obspython as S
import importlib
import logging
import shutil
import csv
import os

wall_scene_name = "The Wall"
instance_scene_format = "Instance *"
lock_format = "lock *"
cover_format = "cover *"
mc_format = "mc *"
version = "v1.1.2"


logging.basicConfig(
    filename=os.path.dirname(os.path.realpath(__file__)) + "\obs_log.log",
    format='%(asctime)s %(levelname)-8s %(message)s',
    level=logging.INFO,
    datefmt='%Y-%m-%d %H:%M:%S')


def get_cmd(path):
    cmdFiles = []
    cmd = []
    for folder, subs, files in os.walk(path):
        for filename in files:
            cmdFiles.append(os.path.abspath(os.path.join(path, filename)))

    oldest_file = min(cmdFiles, key=os.path.getctime)
    while (cmd == []):
        try:
            with open(oldest_file) as cmd_file:
                csv_reader = csv.reader(cmd_file, delimiter=",")
                for row in csv_reader:
                    for value in row:
                        cmd.append(value)
        except:
            cmd = []

    os.remove(oldest_file)
    return cmd


def handle_wall():
    wall_scene = S.obs_get_scene_by_name(wall_scene_name)
    wall_scene_source = S.obs_scene_get_source(wall_scene)
    S.obs_scene_release(wall_scene)
    S.obs_frontend_set_current_scene(wall_scene_source)


def handle_play(inst):
    instance_name = instance_scene_format.replace("*", str(inst))
    instance_scene = S.obs_get_scene_by_name(instance_name)
    instance_scene_source = S.obs_scene_get_source(instance_scene)
    S.obs_scene_release(instance_scene)
    if not instance_scene_source:
        print(
            f"Could not find instance scene '{instance_name}', make sure they are in the format 'Instance *'")
    S.obs_frontend_set_current_scene(instance_scene_source)


def handle_lock(render, inst):
    wall_scene = S.obs_get_scene_by_name(wall_scene_name)
    lock_name = lock_format.replace("*", str(inst))
    lock_source = S.obs_scene_find_source_recursive(
        wall_scene, lock_name)
    if not lock_source:
        print(
            f"Could not find lock source '{lock_name}', make sure they are in the format 'lock *'")
    S.obs_sceneitem_set_visible(lock_source, render)
    S.obs_scene_release(wall_scene)


def execute_cmd(cmd):
    try:
        if (cmd[0] == "ToWall"):
            handle_wall()
        elif (cmd[0] == "Play"):
            handle_play(cmd[1])
        elif (cmd[0] == "Lock"):
            render = cmd[1] == "1"
            wall_scene = S.obs_scene_get_source(
                S.obs_get_scene_by_name(wall_scene_name))
            for lock_num in cmd[2:len(cmd)]:
                lock_name = lock_format.replace("*", str(lock_num))
                lock_source = S.obs_scene_find_source_recursive(S.obs_scene_from_source(
                    wall_scene), lock_name)
                if not lock_source:
                    print(
                        f"Could not find lock source '{lock_name}', make sure they are in the format 'lock *'")
                S.obs_sceneitem_set_visible(lock_source, render)
        # elif (cmd[0] == "Cover"):
        #     render = cmd[1] == "1"
        #     wall_scene = S.obs_scene_get_source(
        #         S.obs_get_scene_by_name(wall_scene_name))
        #     for num in cmd[2:len(cmd)]:
        #         cover_name = cover_format.replace("*", str(num))
        #         cover_source = S.obs_scene_find_source_recursive(S.obs_scene_from_source(
        #             wall_scene), cover_name)
        #         if not cover_source:
        #             print(
        #                 f"Could not find cover source '{cover_name}', make sure they are in the format 'cover *'")
        #         S.obs_sceneitem_set_visible(cover_source, render)

        #         mc_name = mc_format.replace("*", str(num))
        #         mc_source = S.obs_get_source_by_name(mc_name)

        #         invis_filter = S.obs_source_get_filter_by_name(mc_source, "invisible " + num)
        #         if not invis_filter:
        #             print("Could not find invisible filter 'invisible " + num + "', creating and adding now")
        #             temp_settings = S.obs_data_create()
        #             S.obs_data_set_int(temp_settings, "opacity", 0)
        #             invis_source = S.obs_source_create_private(
        #                 "color_filter", "invisible " + num, temp_settings
        #             )
        #             S.obs_source_filter_add(mc_source, invis_source)
        #             S.obs_source_release(mc_source)
        #             S.obs_data_release(temp_settings)
        #             S.obs_source_release(invis_source)
                    
        #         S.obs_source_set_enabled(invis_filter, render)

    except Exception as e:
        print(f"Error: {e}")
        logging.error(e)


def execute_latest():
    global cmdsPath
    try:
        if (os.listdir(cmdsPath)):
            cmd = get_cmd(cmdsPath)
            print(cmd)
            execute_cmd(cmd)
    except Exception as e:
        print(f"Error: {e}")
        logging.error(e)


def script_description():
    return f"MultiResetWall OBS Script {version}.\nYou ONLY need to provide your Wall Scene now, don't worry about any other setting."


def script_unload():
    S.timer_remove(execute_latest)


def script_properties():  # ui
    props = S.obs_properties_create()
    p = S.obs_properties_add_list(
        props,
        "scene",
        "The Wall Scene",
        S.OBS_COMBO_TYPE_EDITABLE,
        S.OBS_COMBO_FORMAT_STRING,
    )

    scenes = S.obs_frontend_get_scenes()
    for scene in scenes:
        name = S.obs_source_get_name(scene)
        S.obs_property_list_add_string(p, name, name)
    S.source_list_release(scenes)

    return props


def script_update(settings):
    global cmdsPath
    global wall_scene_name
    global instance_scene_format
    global lock_format
    wall_scene_name = S.obs_data_get_string(settings, "scene")
    cache_path = os.path.abspath(os.path.join(
        os.path.dirname(__file__), "..", "data", "wall-scene.txt"))
    with open(cache_path, "w+") as f:
        if (f.read().strip() == ""):
            f.write(wall_scene_name)

    try:
        execute_cmd(["ToWall"])
    except Exception as e:
        print(f"Error: {e}")
        logging.error(e)

    path = os.path.dirname(os.path.realpath(__file__))
    cmdsPath = os.path.abspath(os.path.realpath(
        os.path.join(path, '..', 'data', 'pycmds')))

    if (os.path.exists(cmdsPath)):
        shutil.rmtree(cmdsPath)
    os.mkdir(cmdsPath)

    print(f"Listening to {cmdsPath}...")
    logging.info(f"Listening to {cmdsPath}...")

    S.timer_remove(execute_latest)
    S.timer_add(execute_latest, 30)
