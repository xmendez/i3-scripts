# xmendez@edge-security.com
#
# Move to the workspace starting with the given letter.
# Trying to mimic wmii + rumai behauvior
#
# All the letters must be added to the i3 configuration, ie:
# bindsym Mod4+u exec python ~/.i3/scripts/ws_letter.py a
# ...
# bindsym Mod4+u exec python ~/.i3/scripts/ws_letter.py z
#
# using ziberna's i3-py library: https://github.com/ziberna/i3-py

import i3
import sys

def cut_number(string):
    if string.find(": ") > 0:
	return string[string.rfind(": ")+2:]
    return string


ws = i3.get_workspaces()

ws_map = {}

for ws in i3.get_workspaces():
    letter_name = cut_number(ws['name'])[:1]
    if letter_name >= 'a' and letter_name <= 'z':
	ws_map[letter_name] = ws['name']


if len(sys.argv) == 2:
    if ws_map.has_key(sys.argv[1]):
	i3.workspace(ws_map[sys.argv[1]])
