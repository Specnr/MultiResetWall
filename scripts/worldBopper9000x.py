import shutil
import glob
import os

folders = []
with open(f"{os.getcwd()}\data\mcdirs.txt", "r") as dirf:
    for mcdir in dirf:
        folders.append(mcdir.strip().split("~")[1])

for folder in folders:
    files = glob.glob(f'{folder}saves\*')
    for f in files:
        if os.path.isdir(f) and ("New World" in f or "Speedrun #" in f):
            shutil.rmtree(f)
