#! /usr/bin/env lua

require "gtk"
require "Memcached"
require 'string'

-- clone of http://code.sixapart.com/svn/memcached/trunk/frontends/gtk2-perl/
 
local cmds = {}
local cmd_cur = -1
local mc = Memcached.Connect('127.0.0.1', 11211)

function string:split( pattern, res )
  if not res then
    res = { }
  end
  local start = 1
  local split_start, split_end = string.find( self, pattern, start )
  while split_start do
    table.insert( res, string.sub( self, start, split_start-1 ) )
    start = split_end + 1
    split_start, split_end = string.find( self, pattern, start )
  end
  table.insert( res, string.sub( self, start ) )
  return res
end

function entry_keypress(entry, ev)
  if ev.key.keyval == 65362 then
    if cmd_cur < #cmds then
      cmd_cur = cmd_cur + 1
    end
    if cmds[cmd_cur] then
      entry:set_text(cmds[cmd_cur])
    end
    return true
  elseif ev.key.keyval == 65364 then
    if cmd_cur >= 0 then
      cmd_cur = cmd_cur - 1
    end
    if cmd_cur >= 0 and cmds[cmd_cur] then
      entry:set_text(cmds[cmd_cur])
    else
      entry:set_text('')
    end
    return true
  end
  return false
end

function entry_activate(entry)
  local text = entry:get_text()
  if text then
    run_command(text)
    entry:set_text("")
  end
end

function display(level, text)
  local iter = gtk.new("GtkTextIter")
  buffer:get_end_iter(iter)
  buffer:insert_with_tags_by_name(iter, text .. "\n", -1, level, nil)
end

function run_command(text)
  local vars = text:split(" ")

  if cmd_cur >= 0 and cmds[cmd_cur] == text then
    cmds[#cmds + 1] = nil
  end
  for n = #cmds + 1, 1, -1 do cmds[n] = cmds[n - 1] end
  cmds[0] = text
  cmd_cur = -1

  display('command', text)
  if vars[1] == "get" then
    local str,err = pcall(function() mc:get(vars[2]) end)
    if str then
      display('data', str)
    else
      display('error', 'Not found.')
    end
  elseif vars[1] == "set" and vars[3] then
	local ok,err = pcall(function() mc:set(vars[2], vars[3]) end)
    if ok then
      display('data', 'Ok.')
    else
      display('error', 'Not found.')
    end
  elseif vars[1] == "delete" then
    local ok,err = pcall(function() mc:delete(vars[2]) end)
    if ok then
      display('data', 'Ok.')
    else
      display('error', 'Not found.')
    end
  else
    display('error', "Unknown command '" .. text .. "'.")
  end
end

gtk.init(nil, nil)
win = gtk.window_new(gtk.GTK_WINDOW_TOPLEVEL)
win:connect('destroy', function() gtk.main_quit() end)
win:set_border_width(10)

vb = gtk.vbox_new(false, 5)
textview = gtk.text_view_new()
buffer = textview:get_buffer()
textview:set_editable(false)
scroll = gtk.scrolled_window_new(nil, nil)
scroll:set_policy(gtk.GTK_POLICY_AUTOMATIC, gtk.GTK_POLICY_AUTOMATIC)
scroll:set_shadow_type(gtk.GTK_SHADOW_IN)
scroll:add(textview);
vb:pack_start(scroll, true, true, 0)

textview:modify_font(gtk.pango_font_description_from_string('monospace'))
buffer:create_tag("command", "foreground", "blue", nil)
buffer:create_tag("data", "foreground", "black", nil)
buffer:create_tag("error", "foreground", "red", nil)

entry = gtk.entry_new()
entry:connect('key_press_event', entry_keypress)
entry:connect('activate', entry_activate)
vb:pack_start(entry, false, false, 0)

win:add(vb)

win:set_title("MemCachedClient")
win:set_default_size(400, 500)
win:connect('show', function() entry:grab_focus() end)
win:show_all()

gtk.main()
