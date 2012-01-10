module Main (Main.main) where

import Text.Regex
import Graphics.UI.Gtk as Gtk
import Network.Memcache
import Network.Memcache.Protocol
 
main :: IO ()
main = do
  server <- Network.Memcache.Protocol.connect "localhost" 11211

  Gtk.initGUI
  
  window <- Gtk.windowNew
  Gtk.onDestroy window Gtk.mainQuit
  Gtk.set window [ containerBorderWidth := 10, windowTitle := "memcachedclient"]

  vbox <- Gtk.vBoxNew False 0

  swin <- scrolledWindowNew Nothing Nothing
  Gtk.scrolledWindowSetPolicy swin Gtk.PolicyAutomatic Gtk.PolicyAutomatic
  Gtk.containerAdd vbox swin

  tview <- textViewNew 
  Gtk.set tview [ containerBorderWidth := 1 ]
  buf <- Gtk.textViewGetBuffer tview
  Gtk.textViewSetEditable tview False
  Gtk.containerAdd swin tview

  entry <- Gtk.entryNew
  Gtk.onEntryActivate entry $ do
    end <- textBufferGetEndIter buf
    t <- Gtk.get entry entryText
    let tt = splitRegex (mkRegex " ") t
    if (length tt == 2 && (head tt == "get" || head tt == "delete")) ||
       (length tt == 3 && head tt == "set")
    then do
      case head tt of
        "get" -> do
          let
            key = (tt !! 1)
          r <- Network.Memcache.get server key
          case r of
            Nothing -> textBufferInsert buf end ((show key) ++ " not found")
            Just v -> textBufferInsert buf end ((v::String) ++ "\n")
        "set" -> do
          let key = (tt !! 1)
          let val = (tt !! 2)
          r <- Network.Memcache.set server key val
          case r of
            True -> textBufferInsert buf end "OK\n"
            False -> textBufferInsert buf end "ERROR\n"
        "delete" -> do
          let
            key = (tt !! 1)
          r <- Network.Memcache.delete server key 0
          case r of
            True -> textBufferInsert buf end "OK\n"
            False -> textBufferInsert buf end "ERROR\n"
    else
      textBufferInsert buf end "Unknown command\n"
    Gtk.entrySetText entry ""

  Gtk.boxPackEnd vbox entry Gtk.PackNatural 0
  Gtk.set window [ containerChild := vbox ]
  Gtk.windowSetDefaultSize window 400 300
  Gtk.widgetShowAll window
  Gtk.widgetGrabFocus entry

  Gtk.mainGUI

-- vim: set et ts=2:
