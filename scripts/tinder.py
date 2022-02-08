# v0.3.6
from obswebsocket import obsws, requests
import sys
from obsSettings import host, port, password, bg_mc_source_format

ws = obsws(host, port, password)
ws.connect()

# Show new
if int(sys.argv[2]) > 0:
    ws.call(requests.SetSceneItemProperties(
        f"{bg_mc_source_format}{int(sys.argv[2])}", visible=True))

# Hide old
if int(sys.argv[1]) > 0:
    ws.call(requests.SetSceneItemProperties(
        f"{bg_mc_source_format}{int(sys.argv[1])}", visible=False))

ws.disconnect()
