#!/usr/bin/env python
import gtk
import pango
import memcache
import re

# clone of http://code.sixapart.com/svn/memcached/trunk/frontends/gtk2-perl/

cmds = []
cmd_cur = -1

def display(level, text):
    buffer.insert_with_tags_by_name(buffer.get_end_iter(), "%s\n" % text, level)

def run_command(text):
    global cmds, cmd_cur
    # if we're rerunning a history command, then
    # we should pull it out of its old spot in the history.
    if cmd_cur >= 0 and cmds[cmd_cur] == text:
        del cmds[cmd_cur]

    # and in any case, add this command to the history.
    cmds.insert(0, text)
    cmd_cur = -1

    display('command', text)
    m = re.match('^(get|set|delete)\s+(\S+)((\s+)(\S+))?', text, re.IGNORECASE)
    if m and m.group(1).lower() == 'get':
        str = mc.get(m.group(2))
        if not str is None:
            str = re.sub("^                ", "", str)
        if not str is None and len(str):
            display('data', str)
        else:
            display('error', "Not found.")
    elif m and m.group(1).lower() == 'set':
        if mc.set(m.group(2), m.group(5)):
            display('data', "Ok.")
        else:
            display('error', "Not found.")
    elif m and m.group(1).lower() == 'delete':
        mc.delete(m.group(2))
        display('data', "Ok.")
    else:
        display('error', "Unknown command '%s'." % text)

def entry_keypress(entry, ev):
    global cmds, cmd_cur
    if ev.keyval == gtk.keysyms.Up:
        if cmd_cur < len(cmds)-1:
            cmd_cur += 1
        if cmd_cur >= 0 and len(cmds[cmd_cur]):
            entry.set_text(cmds[cmd_cur])
        return True
    elif ev.keyval == gtk.keysyms.Down:
        if cmd_cur >= 0:
            cmd_cur -= 1
        if cmd_cur >= 0 and len(cmds[cmd_cur]):
            entry.set_text(cmds[cmd_cur])
        else:
            entry.set_text("")
        return True
    return False

def entry_activate(entry):
    text = entry.get_text()
    if len(text):
        run_command(text)
        entry.set_text("")
        entry.grab_focus()

mc = memcache.Client([
    "127.0.0.1:11211",
])

win = gtk.Window()
win.connect('destroy', gtk.main_quit)
win.set_border_width(10)

vb = gtk.VBox(0, 5)
textview = gtk.TextView()
buffer = textview.get_buffer()
textview.set_editable(False)
scroll = gtk.ScrolledWindow()
scroll.set_policy('automatic', 'automatic')
scroll.set_shadow_type('in')
scroll.add(textview)
vb.pack_start(scroll, 1, 1, 0)

textview.modify_font(pango.FontDescription("monospace"))
buffer.create_tag("command").set_property("foreground", "blue")
buffer.create_tag("data").set_property("foreground", "black")
buffer.create_tag("error").set_property("foreground", "red")

entry = gtk.Entry()
entry.connect('key-press-event', entry_keypress)
entry.connect('activate', entry_activate)
vb.pack_start(entry, 0, 0, 0)

win.add(vb)

win.set_title("MemCachedClient")
win.set_default_size(400, 500)
win.connect('show', lambda x: entry.grab_focus())
win.show_all()

gtk.main()
