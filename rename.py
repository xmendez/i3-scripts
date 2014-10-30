# xmendez@edge-security.com
#
# Script to rename i3 workspace using dmenu, number it automatically, ie. x: new_name, and finally sort the others workspaces accordingly.
# Trying to mimic wmii + rumai behauvior
#
# Add the following to your configuration:
# bindsym $mod+Shift+r exec python ~/.i3/scripts/rename.py
#
# using ziberna's i3-py library: https://github.com/ziberna/i3-py

import i3
import subprocess

# convert 1: name to name
def cut_number(string):
    if string.find(": ") > 0:
	return string[string.rfind(": ")+2:]
    return string

# dmenu
def dmenu_prompt(clients):
    dmenu = subprocess.Popen(
        ['/usr/bin/dmenu','-b','-i', '-p', 'Type new workspace name: '],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE
    )
    menu_str = '\n'.join(sorted(clients.keys()))
    name = dmenu.communicate(menu_str.encode('utf-8'))[0].decode('utf-8').rstrip()

    return name

if __name__ == '__main__':
    # Get current workspaces names
    ws_map = {}
    for ws in i3.get_workspaces():
	ws_map[cut_number(ws['name'])] = ws['num']

    name = dmenu_prompt(ws_map)

    if not len(name):
        exit(0)

    # reorder current workspaces numbers
    i = 0
    for ws in i3.get_workspaces():
	i = i + 1

	new_name = "%d: %s" % (i, cut_number(ws['name']))

	if new_name != ws['name']:
	    ws_map[cut_number(ws['name'])] = i
	    i3.command("rename workspace \"{0}\" to \"{1}\"".format(
		ws['name'],
		new_name
	    ))

    # create new workspace and switch
    new_number = i + 1
    if ws_map.has_key(name):
	new_number = ws_map[name]

    i3.command("move window to workspace \"{0}: {1}\"".format(
	new_number,
        name
    ))
    i3.command("workspace \"{0}: {1}\"".format(
	new_number,
        name
    ))
