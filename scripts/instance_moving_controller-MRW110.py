from math import ceil, floor
import obspython as S
import os

# Don't configure

focus_cols = 0
focus_rows = 0
screen_estate_horizontal = 0
screen_estate_vertical = 0
locked_rows_before_rollover = 0
wall_scene_name = "The Wall"
instance_source_format = "mc *"
focused_count = focus_rows * focus_cols
prev_instances = []
prev_passive_count = 0
prev_locked_count = 0
pixels_between_instances = 0
lastUpdate = 0.0
screen_width = 0
screen_height = 0
version = "v1.1.0"
path = os.path.dirname(os.path.realpath(__file__))
reloadPath = os.path.abspath(os.path.realpath(
    os.path.join(path, '..', 'data', 'macro.reload')))
obstxtPath = os.path.abspath(os.path.realpath(
    os.path.join(path, '..', 'data', 'obs.txt')))
settingsPath = os.path.abspath(os.path.realpath(
    os.path.join(path, '..', 'settings.ahk')))


class FileInstance():
    def __init__(self, inst):
        self.suffix = inst.split("L")[0].split("H")[0].split("W")[0]
        self.locked = "L" in inst
        self.hidden = "H" in inst
        self.wall = "W" in inst

    def __eq__(self, other):
        """Overrides the default implementation"""
        if isinstance(other, FileInstance):
            return self.suffix == other.suffix and self.locked == other.locked and self.hidden == other.hidden and self.wall == other.wall
        return False

    def __str__(self) -> str:
        return self.suffix + ("L"if self.locked else "") + ("H" if self.hidden else "") + ("W" if self.wall else "")
    pass


def move_source(source, x, y):
    if source:
        pos = S.vec2()
        S.obs_sceneitem_get_pos(source, pos)
        if(pos.x == x and pos.y == y):
            return
        pos.x = x
        pos.y = y
        S.obs_sceneitem_set_pos(source, pos)


def scale_source(source, width, height):
    if source:
        bounds = S.vec2()
        bounds.x = width
        bounds.y = height
        S.obs_sceneitem_set_bounds(source, bounds)


def parse_instances_string(input: str) -> 'list[FileInstance]':
    raw_instances = input.split(",")
    return list(map(lambda inst: FileInstance(inst), raw_instances))


def passive_instance_count(instances: 'list[FileInstance]'):
    return len(list(filter(lambda inst: inst.hidden, instances)))


def locked_instance_count(instances: 'list[FileInstance]'):
    return len(list(filter(lambda inst: inst.locked, instances)))


def manage_movement():
    try:
        global lastUpdate
        global prev_instances
        global prev_locked_count
        global prev_passive_count
        global locked_rows_before_rollover
        global screen_width
        global screen_height
        global focus_rows
        global focus_cols
        global screen_estate_horizontal
        global screen_estate_vertical
        global locked_rows_before_rollover
        global pixels_between_instances

        # Reload settings on macro reload
        if os.path.exists(reloadPath):
            focus_rows = int(get_setting_from_ahk("rows"))
            focus_cols = int(get_setting_from_ahk("cols"))
            screen_estate_horizontal = float(
                get_setting_from_ahk("focusGridWidthPercent"))
            screen_estate_vertical = float(
                get_setting_from_ahk("focusGridHeightPercent"))
            locked_rows_before_rollover = int(
                get_setting_from_ahk("maxLockedRows"))
            pixels_between_instances = int(
                get_setting_from_ahk("pixelsBetweenInstances"))
            os.remove(reloadPath)

        if screen_height == 0:
            wall_scene = S.obs_scene_get_source(
                S.obs_get_scene_by_name(wall_scene_name))
            screen_width = S.obs_source_get_width(wall_scene)
            screen_height = S.obs_source_get_height(wall_scene)
            S.obs_source_release(wall_scene)

        wall_scene = S.obs_get_scene_by_name(wall_scene_name)
        if not wall_scene:
            print("Can't find scene")
            return

        if not os.path.exists(obstxtPath):
            print("Can't find obs.txt")
            return
        currentTime = os.path.getmtime(obstxtPath)
        if currentTime == lastUpdate:
            return
        lastUpdate = currentTime

        with open(obstxtPath) as f:

            raw_instances_string = f.readlines()[0]
            instances = parse_instances_string(raw_instances_string)
            print(raw_instances_string)
            passive_count = passive_instance_count(instances)
            locked_count = locked_instance_count(instances)
            locked_cols = ceil(locked_count / locked_rows_before_rollover)

            backupRow = 0
            lockedIndex = 0
            for item in range(len(instances)):
                pX = (pixels_between_instances /
                      2) if item % focus_cols < (focus_cols - 1) else 0
                pY = (pixels_between_instances /
                      2) if item // focus_rows < (focus_rows - 1) else 0
                if instances[item].wall:
                    scene_item = S.obs_scene_find_source_recursive(
                        wall_scene, instance_source_format.replace("*", instances[item].suffix))
                    inst_height, inst_width = screen_height / focus_rows, screen_width / focus_cols
                    move_source(scene_item, inst_width * (item %
                                                          focus_cols), inst_height * (item // focus_cols))

                    scale_source(scene_item, inst_width - pX, inst_height - pY)
                    continue
                if instances[item].hidden:
                    if passive_count == prev_passive_count and instances[item] == prev_instances[item]:
                        backupRow += 1
                        continue
                    scene_item = S.obs_scene_find_source_recursive(
                        wall_scene, instance_source_format.replace("*", instances[item].suffix))
                    inst_height = screen_height / passive_count
                    move_source(scene_item, screen_width *
                                screen_estate_horizontal, backupRow * inst_height)
                    scale_source(scene_item, screen_width *
                                 (1-screen_estate_horizontal), inst_height)
                    backupRow += 1
                    continue
                if instances[item].locked:
                    if locked_count == prev_locked_count and instances[item] == prev_instances[item]:
                        lockedIndex += 1
                        continue
                    scene_item = S.obs_scene_find_source_recursive(
                        wall_scene, instance_source_format.replace("*", instances[item].suffix))

                    inst_width = (
                        screen_width*screen_estate_horizontal) / locked_cols
                    inst_height = (screen_height * (1 - screen_estate_vertical)) / \
                        min(locked_count, locked_rows_before_rollover)
                    move_source(scene_item, (inst_width * floor(lockedIndex / locked_rows_before_rollover)),
                                screen_height * screen_estate_vertical + inst_height * (lockedIndex % locked_rows_before_rollover))
                    scale_source(scene_item, inst_width, inst_height)
                    lockedIndex += 1
                    continue
                row = floor(item/focus_cols)
                col = floor(item % focus_cols)

                scene_item = S.obs_scene_find_source_recursive(
                    wall_scene, instance_source_format.replace("*", instances[item].suffix))
                move_source(scene_item, col * (screen_width * screen_estate_horizontal /
                                               focus_cols), row * (screen_height * screen_estate_vertical / focus_rows))
                scale_source(scene_item, screen_width * screen_estate_horizontal /
                             focus_cols - pX, screen_height * screen_estate_vertical / focus_rows - pY)
            prev_instances = instances
            prev_passive_count = passive_count
            prev_locked_count = locked_count
    except Exception as e:
        print(e)
        return


def script_description():
    return f"MultiResetWall Instance Moving Controller {version}.\nPlease reload this script anytime you change any related settings in AHK.\n"


# Mainly works with numbers
def get_setting_from_ahk(setting_name):
    setting = None
    with open(settingsPath, "r") as f:
        for line in f:
            if line.startswith(f"global {setting_name}"):
                # Can probably be cleaner with regex
                setting = line.split("= ")[1].split(" ;")[0].strip()
                break
    return setting


def script_update(settings):
    global wall_scene_name
    global focus_rows
    global focus_cols
    global screen_estate_horizontal
    global screen_estate_vertical
    global locked_rows_before_rollover
    global pixels_between_instances
    wall_scene_name = ""
    cache_path = os.path.abspath(os.path.join(
        os.path.dirname(__file__), "..", "data", "wall-scene.txt"))
    if os.path.exists(cache_path):
        with open(cache_path, "r") as f:
            wall_scene_name = f.read().strip()
    if (wall_scene_name == ""):
        print("Could get wall scene from obs_controller. Please set it and refresh.")
        return
    focus_rows = int(get_setting_from_ahk("rows"))
    focus_cols = int(get_setting_from_ahk("cols"))
    screen_estate_horizontal = float(
        get_setting_from_ahk("focusGridWidthPercent"))
    screen_estate_vertical = float(
        get_setting_from_ahk("focusGridHeightPercent"))
    locked_rows_before_rollover = int(get_setting_from_ahk("maxLockedRows"))
    pixels_between_instances = int(
        get_setting_from_ahk("pixelsBetweenInstances"))
    S.timer_remove(manage_movement)
    S.timer_add(manage_movement, 100)
