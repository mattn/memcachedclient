#!/usr/bin/gosh
;;; まだまだまだ作りかけ
(use gtk)
(use gauche.net)
(use gauche.sequence)
(use srfi-13)

(define memcached-socket
  (make-client-socket 'inet "127.0.0.1" 11211))

(define memcached-socket-output-port
  (socket-output-port memcached-socket :buffering :line))

(define memcached-socket-input-port
  (socket-input-port memcached-socket :buffering :none))

(define (get-command . args)
  (let ((key   (get-keyword :key args)))
    (let1 line
          (string-append "get " key)
          (display (string-append line "\r\n") memcached-socket-output-port)
      (flush memcached-socket-output-port)
      (let loop ((str (string-incomplete->complete
            (read-line memcached-socket-input-port)))
        )
        (if (string-prefix? "VALUE " str)
          (string-drop-right (socket-recv memcached-socket (+ (string->number (list-ref (string-split str " ") 3) 10) 7)) 7)
        )
      )
    )
  )
)

(define (set-command . args)
  (let ((key   (get-keyword :key args))
        (value (get-keyword :value args)))
    (let1 line
          (string-append "set " key " 0 0 " (number->string (string-size value)) "\r\n" value)
          (display (string-append line "\r\n") memcached-socket-output-port)
      (flush memcached-socket-output-port)
      (let loop ((str (string-incomplete->complete
            (read-line memcached-socket-input-port)))
        )
        #t
      )
    )
  )
)

(define (main args)
  (gtk-init args)
  (let
    (
      (window (gtk-window-new GTK_WINDOW_TOPLEVEL))
      (vbox (gtk-vbox-new #f 0))
      (textview (gtk-text-view-new))
      (entry (gtk-entry-new))
      (font (pango-font-description-new))
    )
    (g-signal-connect window "delete_event" (lambda _ (gtk-main-quit)))
    (gtk-container-add window vbox)
    (let1 scroll (gtk-scrolled-window-new #f #f)
      (gtk-scrolled-window-set-policy scroll GTK_POLICY_AUTOMATIC GTK_POLICY_ALWAYS)
      (gtk-container-add scroll textview)
      (gtk-box-pack-start vbox scroll #t #t 0)
      (gtk-box-pack-start vbox entry #f #f 0)
    )
    (let1 buffer (gtk-text-view-get-buffer textview)
      (let1 tag-table (gtk-text-buffer-get-tag-table buffer)
        (let1 tag1 (gtk-text-tag-new "command")
          (g-object-set-property tag1 "foreground" "blue")
          (gtk-text-tag-table-add tag-table tag1)
        )
      )
    )
    (pango-font-description-set-family font "monospace")
    (gtk-widget-modify-font textview font)
    (pango-font-description-free font)
    (gtk-text-view-set-editable textview #f)

    (g-signal-connect entry "activate" (lambda (entry) 
      (let1 line (gtk-entry-get-text entry)
        (gtk-entry-set-text entry "")
        (if (string-prefix? "get " line)
          (let1 buffer (gtk-text-view-get-buffer textview)
            (let1 tag-table (gtk-text-buffer-get-tag-table buffer)
              (let1 start (gtk-text-buffer-get-end-iter buffer)
                (gtk-text-buffer-insert buffer start line -1)
                (let1 end (gtk-text-buffer-get-end-iter buffer)
                  (gtk-text-buffer-apply-tag-by-name buffer "command" start end)
                )
                (gtk-text-buffer-insert buffer start "\n" -1)
                (gtk-text-buffer-insert buffer start (get-command :key (list-ref (string-split line " ") 1)) -1)
                (gtk-text-buffer-insert buffer start "\n" -1)
              )
            )
          )
        )
        (if (string-prefix? "set " line)
          (let1 buffer (gtk-text-view-get-buffer textview)
            (gtk-text-buffer-insert buffer (gtk-text-buffer-get-end-iter buffer) line -1)
            (gtk-text-buffer-insert buffer (gtk-text-buffer-get-end-iter buffer) "\n" -1)
            (set-command :key (list-ref (string-split line " ") 1) :value (list-ref (string-split line " ") 2))
            (gtk-text-buffer-insert buffer (gtk-text-buffer-get-end-iter buffer) "Ok\n" -1)
          )
        )
      )
    ))
    (g-signal-connect window "show" (lambda _ (gtk-widget-grab-focus entry)))

    (gtk-window-set-title window "MemcachedClient")
    (gtk-window-set-default-size window 400 500)
    (gtk-widget-show-all window)

  )

  (gtk-main)
)

; vim:et
