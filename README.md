i3-scripts
==========

In my early Linux days, I loved using Blackbox and later Fluxbox as my window managers, but quickly I became a big supporter of tiling window managers like dwm, wmii, xmonad or i3.

I am so dependant on these kind of Window managers that I cannot switch back to the "normal" ones like gnome or kde.

I was a wmii user for a long time but I changed to i3 window manager a couple of years ago, mainly because i3 is an active project, well documented, implementing multi-monitor correctly and also due to the fact that I started enhancing wmii with some public scripts/frameworks that were not maintained and far to be compatible with the last wmii releases (the old https://web.archive.org/web/20081227225803/http://eigenclass.org/hiki.rb?wmii+ruby and then https://github.com/sunaku/wmiirc).

But I got so used to wmii that I was missing some of its functionality in i3, that's why I wrote these scripts for the i3 windows manager (https://i3wm.org/), trying to mimic the way that I was working before.

Hoping they are useful for someone else too.

All the scripts are using ziberna's i3-py library: https://github.com/ziberna/i3-py.

#### rename.py

Script to rename i3 workspace using dmenu, number it automatically, ie. x: new_name, and finally sort 
the others workspaces accordingly.                                                                      

#### bookmarks.rb

(Quick and dirty) Bookmark manager, mainly copied and then adapted to run from command line from the old ruby-wmii standart plugins collection (https://web.archive.org/web/20081227225803/http://eigenclass.org/hiki.rb?wmii+ruby).

#### to_letter.py

Move window to the workspace starting with the given letter.

#### winmenu.py
 
dmenu script to jump to windows in i3 from Jure Ziberna for i3-py's examples section.

#### ws_letter.py

Move to the workspace starting with the given letter.
