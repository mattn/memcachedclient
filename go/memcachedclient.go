package main

import (
	"github.com/mattn/go-gtk/gtk"
	"github.com/bradfitz/gomemcache/memcache"
	"strings"
)

func main() {
	mc := memcache.New("127.0.0.1:11211")

	gtk.Init(nil)

	window := gtk.NewWindow(gtk.WINDOW_TOPLEVEL)
	window.SetTitle("memcachedclient")
	window.Connect("destroy", gtk.MainQuit)

	vbox := gtk.NewVBox(false, 1)

	swin := gtk.NewScrolledWindow(nil, nil)
	textview := gtk.NewTextView()
	textview.SetEditable(false)
	textview.SetCursorVisible(false)
	textview.ModifyFontEasy("monospace 12")
	swin.Add(textview)
	vbox.Add(swin)

	buffer := textview.GetBuffer()

	input := gtk.NewEntry()
	input.SetEditable(true)
	vbox.PackEnd(input, false, false, 0)

	tag := buffer.CreateTag("red", map[string]string{"foreground": "#FF0000"})
	input.Connect("activate", func() {
		var iter gtk.TextIter
		tokens := strings.SplitN(input.GetText(), " ", 3)
		if len(tokens) == 2 && strings.ToUpper(tokens[0]) == "GET" {
			if t, err := mc.Get(tokens[1]); err == nil {
				buffer.GetEndIter(&iter)
				buffer.Insert(&iter, string(t.Value) + "\n")
			} else {
				buffer.InsertWithTag(&iter, err.Error() + "\n", tag)
			}
			input.SetText("")
		} else if len(tokens) == 3 && strings.ToUpper(tokens[0]) == "SET" {
			if err := mc.Set(
					&memcache.Item{
						Key: tokens[1],
						Value: []byte(tokens[2]),
					}); err == nil {
				buffer.GetEndIter(&iter)
				buffer.InsertWithTag(&iter, "OK\n", tag)
			} else {
				buffer.InsertWithTag(&iter, err.Error() + "\n", tag)
			}
			input.SetText("")
		}
	})
	input.GrabFocus()

	window.Add(vbox)
	window.SetSizeRequest(300, 500)
	window.ShowAll()
	gtk.Main()
}
