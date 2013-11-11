;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; .emacs file
;; Benjamin Gleitzman (gleitz@hunch.com)
;; with some modifications by Drew Werner (drew@datadoghq.com)
;; rev: 11 Nov 2013
;; use with (load "~/drewmacs/emacs_inherit.el")
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Third-party libraries

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; VISUAL

;; Color Theming
(add-to-list 'load-path (expand-file-name "~/drewmacs/color-theme"))
(require 'color-theme)
(color-theme-initialize)
(color-theme-hober)

;; Highline
(load "~/drewmacs/highline.el")
(require 'highline)
(highline-mode 1)
;; To customize the background color
(set-face-background 'highline-face "#222")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; MAJOR MODES

;; web mode
(load "~/drewmacs/web-mode.el")
(add-to-list 'auto-mode-alist '("\\.erb$" . web-mode))
;; TODO: add mako mode to web mode
(add-to-list 'auto-mode-alist '("\\.mako$" . web-mode))

;; SVN
(load "~/drewmacs/psvn.el")

;; Javascript
(add-to-list 'load-path (expand-file-name "~/drewmacs"))
(autoload 'js2-mode "js2" nil t)
(add-to-list 'auto-mode-alist '("\\.js$" . js2-mode))

;; Cython
(load "~/drewmacs/cython-mode.el")

;; Ruby (blech)
(load "~/drewmacs/ruby-mode/ruby-mode.el")
(add-to-list 'auto-mode-alist '("\\.rb$" . ruby-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MISC

;; Display ido results vertically, rather than horizontally
(setq ido-decorations
      (quote ("\n-> " "" "\n   " "\n   ..." "[" "]" " [No match]"
              " [Matched]" " [Not readable]" " [Too big]" " [Confirm]")))

(defun ido-disable-line-truncation () (set (make-local-variable 'truncate-lines) nil))
(add-hook 'ido-minibuffer-setup-hook 'ido-disable-line-truncation)
(defun ido-define-keys () ;; C-n/p is more intuitive in vertical layout
  (define-key ido-completion-map (kbd "C-n") 'ido-next-match)
  (define-key ido-completion-map (kbd "C-p") 'ido-prev-match))
(add-hook 'ido-setup-hook 'ido-define-keys)

;; Projectile - Emacs 24 only
(if (and (boundp 'emacs-major-version)
	 (>= emacs-major-version 24))
    (progn
      (add-to-list 'load-path "~/drewmacs/projectile")
      (require 'projectile)
      ;; Applies to all modes
      (projectile-global-mode)
      ;; Use ido for search
      (setq projectile-completion-system 'ido)))

;; Getting the executable path from the shell
;; Needed to find the ag executable
(defun set-exec-path-from-shell-PATH ()
  "Set up Emacs' `exec-path' and PATH environment variable to match that used by the user's shell.

This is particularly useful under Mac OSX, where GUI apps are not started from a shell."
  (interactive)
  (let ((path-from-shell (replace-regexp-in-string
			  "[ \t\n]*$" ""
			  (shell-command-to-string "$SHELL --login -i -c 'echo $PATH'"))))
    (setenv "PATH" path-from-shell)
    (setq exec-path (split-string path-from-shell path-separator))))

(set-exec-path-from-shell-PATH)

;; import ag, if possible
(if (executable-find "ag") ; Require only if executable exists
    (progn
      (load "~/drewmacs/ag.el")
      (require 'ag)
      ;; same buffer for every search
      (setq ag-reuse-buffers t)
      (setq ag-reuse-window t)))


;; Add local vars mode hook
(defun run-local-vars-mode-hook ()
  "Run a hook for the major mode after the local variables have been processed."
  (run-hooks (intern (concat (symbol-name major-mode) "-local-vars-hook"))))
(add-hook 'hack-local-variables-hook 'run-local-vars-mode-hook)

;; Auto complete mode
(add-to-list 'load-path "~/drewmacs/auto-complete")
(require 'auto-complete-config)
(ac-config-default)

;; Jedi Python Mode

;; Experimental (but functional)
;; a good candidate for tweaking
;; TODO: rework to use vc-find-root, minimize dupe processes
(defun guess-best-python-root-for-buffer (buf)
  "Guesses that the python root is the less 'deep' of either:
     -- the root directory of the repository, or
     -- the directory before the first directory after the root
        having an __init__.py file."
  (interactive)
  (let ((found-project-root nil)
        (found-init-py nil)
        (search-depth 0)
        (root-depth nil)
        (max-search-depth 0)
        (base-directory (file-name-directory (buffer-file-name buf))))
    (setq max-search-depth (length (split-string base-directory "/")))

    (defun path-at-depth (base depth-val)
      (if (> depth-val 0)
          (concat (path-at-depth base (- depth-val 1)) "../")
        base))

    (defun exists-at-current-depth (fname)
      (file-exists-p (concat (path-at-depth base-directory search-depth) fname)))

    ;; head down to the root of the git repo
    (while (and (< search-depth max-search-depth) (not found-project-root))
      (if (exists-at-current-depth ".git") ; add others?
          (setq found-project-root t)
        (setq search-depth (+ search-depth 1))))
    (setq root-depth search-depth)
    ;; heading back, pick the directory _before_ the first
    ;; directory having an __init__.py file
    (while (and (>= search-depth 0) (not found-init-py))
        (if (exists-at-current-depth "__init__.py")
            (progn
              ;; if it's not the root, then go back a directory
              (if (not (eq search-depth root-depth))
                  (setq search-depth (+ search-depth 1)))
              (setq found-init-py t))
          (setq search-depth (- search-depth 1))))
    ;; return the full absolute path at the search depth
    (path-at-depth base-directory search-depth)
    )
  )

(defun setup-jedi-extra-args ()
  (let ((project-base (guess-best-python-root-for-buffer (current-buffer))))
    (make-local-variable 'jedi:server-args)
    (when project-base (set 'jedi:server-args (list "--sys-path" project-base)))))

;; Only activate in Emacs 24 and up
(if (and (boundp 'emacs-major-version)
	 (>= emacs-major-version 24))
    (progn
      ;; EPC (prereq for jedi)
      (add-to-list 'load-path (expand-file-name "~/drewmacs/epc-deps"))
      (load "~/drewmacs/epc.el")

      ;; Jedi
      (setq jedi:setup-keys t)
      (setq jedi:complete-on-dot t)
      (load "~/drewmacs/jedi.el")
      (setq jedi:server-command (list
                                 (executable-find "python")
                                 (cadr jedi:server-command)))
      (add-to-list 'ac-sources 'ac-source-jedi-direct)
      (add-hook 'python-mode-local-vars-hook 'setup-jedi-extra-args)
      (add-hook 'python-mode-local-vars-hook 'jedi:setup)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; mode CONFIGURATION

;; No Toolbar
(if window-system (tool-bar-mode -1))

;; No Scrollbar
(if (fboundp 'tool-scroll-bar) (tool-scroll-bar -1))
(if (fboundp 'toggle-scroll-bar) (toggle-scroll-bar -1))

;; Hide password prompts
(add-hook 'comint-output-filter-functions
          'comint-watch-for-password-prompt)

;; Screen-saver
;; (require 'zone)
;; (setq zone-idle (* 60 10))
;; (zone-when-idle zone-idle)

; Whitespace is evil
; Uncomment to automatically delete
; (add-hook 'before-save-hook 'delete-trailing-whitespace)

; copy and paste from X
(setq x-select-enable-clipboard t)
;(setq interprogram-paste-function 'x-cut-buffer-or-selection-value)

;; Use colorization for all modes
(global-font-lock-mode t)
(font-lock-mode +1)
(cond ((fboundp 'global-font-lock-mode)
       ;; Turn on font-lock in all modes that support it
       (global-font-lock-mode t)
       ;; Maximum colors
       (setq font-lock-maximum-decoration t)))

;; Show the matching immediately, we are in a hurry
(setq show-paren-delay 0)
(show-paren-mode t)

;; Activate the dynamic completion of buffer names
(iswitchb-mode 1)

;; Activate the dynamic completion in the mini-buffer
(icomplete-mode 1)

;; Activate a number of variables
(setq
 ;; avoid GC as much as possible
 gc-cons-threshold 2500000
 ;; no startup message
 inhibit-startup-message t
 ;; no message in the scratch buffer
 initial-scratch-message nil
 ;; do not fill my buffers, you fool
 next-line-add-newlines nil
 ;; keep the window focused on the messages during compilation
 compilation-scroll-output t
 ;; blink the screen instead of beeping
 ;; visible-bell t
 ;; take the CR when killing a line
 kill-whole-line t
 ;; Show all lines, even if the window is not as large as the frame
 truncate-partial-width-windows nil
 ;; Do not keep tracks of the autosaved files
 auto-save-list-file-prefix nil
 ;; Show me empty lines at the end of the buffer
 default-indicate-empty-lines t
 ;; Show me the region until I do something on it
 transient-mark-mode t
 ;; Don't bother me with questions even if "unsafe" local variables
 ;; are set
 enable-local-variables :all

 ;; The backups
 temporary-file-directory "/tmp/"
 vc-make-backup-files t
 backup-directory-alist '((".*" . "~/archives/emacs.backups/"))
 version-control t ;; Use backup files with numbers
 kept-new-versions 10
 kept-old-versions 2
 delete-old-versions t
 backup-by-copying-when-linked t
 )

(setq-default
 ;; Show white spaces at the end of lines
 show-trailing-whitespace t
 ;; Do not show the cursor in non-active window
 cursor-in-non-selected-windows nil
 use-dialog-box nil
 ;; when on a TAB, the cursor has the TAB length
 x-stretch-cursor t
 )

;; Show the column number
(column-number-mode 1)

;; What modes for what file extentions
(add-to-list 'auto-mode-alist '("\\.h\\'" . c++-mode))

(add-to-list 'auto-mode-alist '("\\.txt\\'" . (lambda()
                                                (text-mode)
                                                (auto-fill-mode)
                                                (flyspell-mode))))

; Kill Copy/Paste lag
(setq interprogram-cut-function nil)
(setq interprogram-paste-function nil)
(global-set-key [(escape) (meta w)]
  (lambda ()
    (interactive)
    (eval-expression
      '(setq interprogram-cut-function
             'x-select-text))
    (kill-ring-save (region-beginning) (region-end))
    (eval-expression
      '(setq interprogram-cut-function nil))))

(global-set-key [(escape) (control y)]
  (lambda ()
    (interactive)
    (eval-expression
      '(setq interprogram-paste-function
             'x-cut-buffer-or-selection-value))
    (yank)
    (eval-expression
      '(setq interprogram-paste-function nil))))

; Desktop load
;; (desktop-load-default)
;; (desktop-read)

; Hippie-expand
(setq hippie-expand-try-functions-list '(try-expand-dabbrev try-expand-dabbrev-all-buffers try-expand-dabbrev-from-kill try-complete-file-name-partially try-complete-file-name try-expand-all-abbrevs try-expand-list try-expand-line try-complete-lisp-symbol-partially try-complete-lisp-symbol))
(global-set-key (kbd "M-/") 'hippie-expand)

; Auto-revert
(global-auto-revert-mode 1)

; Uniquify
(require 'uniquify)
(setq uniquify-buffer-name-style 'reverse)
(setq uniquify-separator "/")
(setq uniquify-after-kill-buffer-p t) ; rename after killing uniquified
(setq uniquify-ignore-buffers-re "^\\*") ; don't muck with special buffers

; Don't echo shell
(defun my-comint-init ()
           (setq comint-process-echoes t))
         (add-hook 'comint-mode-hook 'my-comint-init)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Move the window on the buffer without moving the cursor
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ff/scroll-down ()
  "Scroll the buffer down one line and keep the cursor at the same location."
  (interactive)
  (condition-case nil
      (scroll-down 1)
    (error nil)))

(defun ff/scroll-up ()
  "Scroll the buffer up one line and keep the cursor at the same location."
  (interactive)
  (condition-case nil
      (scroll-up 1)
    (error nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; I comment stuff often, let's be efficient. shift + down comments
;; the current line and goes down, and shift + up uncomments the line
;; and goes up.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ff/comment-and-go-down (arg)
  "Comments and goes down ARG lines."
  (interactive "p")
  (condition-case nil
      (comment-region (point-at-bol) (point-at-eol)) (error nil))
  (next-line 1)
  (if (> arg 1) (ff/comment-and-go-down (1- arg))))

(defun ff/uncomment-and-go-up (arg)
  "Uncomments and goes up ARG lines."
  (interactive "p")
  (condition-case nil
      (uncomment-region (point-at-bol) (point-at-eol)) (error nil))
  (next-line -1)
  (if (> arg 1) (ff/uncomment-and-go-up (1- arg))))

(defun ff/count-char ()
  "Prints the number of characters between the first previous \"--\"
and the firt next \"--\"."
  (interactive)
  (let ((from (save-excursion (re-search-backward "^--$" nil t)))
        (to (save-excursion (re-search-forward "^--$" nil t))))
    (if (and to from) (message "%d character(s)" (- to from 6))
      (error "Can not find the -- delimiters"))))

(defun ff/count-words ()
  "Print number of words between the first previous \"--\" and the
firt next \"--\"."
  (interactive)
  (let ((from (save-excursion (re-search-backward "^--$" nil t)))
        (to (save-excursion (re-search-forward "^--$" nil t))))
    (if (and to from)
        (save-excursion
          (goto-char from)
          (let ((count 0))
            (while (< (point) to)
              (re-search-forward "\\w+\\W+")
              (setq count (1+ count)))
            (message "%d word(s)" count)))
      (error "Can not find the -- delimiters"))))

(defun ff/word-occurences ()
  "Display in a new buffer the list of words sorted by number of
occurrences "
  (interactive)

  (let ((buf (get-buffer-create "*word counting*"))
        (map (make-sparse-keymap))
        (nb (make-hash-table))
        (st (make-hash-table))
        (result nil))

    ;; Collects all words in a hash table
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\([\\-a-zA-Z\\\\]+\\)" nil t)
        (let* ((s (downcase (match-string-no-properties 1)))
               (k (sxhash s)))
          (puthash k s st)
          (puthash k (1+ (gethash k nb 0)) nb))))

    ;; Creates the result buffer
    (define-key map "q" 'kill-this-buffer)
    (display-buffer buf)
    (set-buffer buf)
    (setq show-trailing-whitespace nil)
    (erase-buffer)

    ;; Builds a list from the hash table
    (maphash
     (lambda (key value)
       (setq result (cons (cons value (gethash key st)) result)))
     nb)

    ;; Sort and display it
    (mapc (lambda (x)
            (if (and (> (car x) 3)
                     ;; No leading backslash and at least four characters
                     (string-match "^[^\\]\\{4,\\}" (cdr x))
                     )
                (insert (number-to-string (car x)) " " (cdr x) "\n")))
          (sort result (lambda (a b) (> (car a) (car b)))))

    ;; Adjust the window size and stuff
    (fit-window-to-buffer (get-buffer-window buf))
    (use-local-map map)
    (set-buffer-modified-p nil))
  )

;; More commands

(defun ff/non-existing-filename (dir prefix suffix)
  "Returns a filename of the form DIR/PREFIX[.n].SUFFIX whose file does not exist"
  (let ((n 0)
        (f (concat prefix suffix)))
    (while (file-exists-p (concat dir "/" f))
      (setq n (1+ n)
            f (concat prefix "." (prin1-to-string n) suffix)))
    f))

(defun ff/print-buffer-or-region-with-faces (&optional file)
  (unless
      (condition-case nil
          (ps-print-region-with-faces (region-beginning) (region-end) file)
        (error nil))
    (ps-print-buffer-with-faces file)))

(defun ff/print-to-file (file)
  "Prints the region if selected or the whole buffer in postscript
into FILE."
  (interactive
   (list
    (read-file-name
     "PS file: " "/tmp/" nil nil
     (ff/non-existing-filename
      "/tmp"
      (replace-regexp-in-string "[^a-zA-Z0-9_.-]" "_" (file-name-nondirectory (buffer-name)))
      ".ps"))
    ))
   (ff/print-buffer-or-region-with-faces file))

(defun ff/print-to-printer ()
  "Prints the region if selected or the whole buffer to a postscript
printer."
  (interactive)
  (message "Printing to '%s'" (getenv "PRINTER"))
  (ff/print-buffer-or-region-with-faces))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ff/system-info () (interactive)
  (let ((buf (get-buffer-create "*system info*"))
        (map (make-sparse-keymap)))
    (define-key map "q" 'kill-this-buffer)
    (display-buffer buf)
    (set-buffer buf)
    (setq show-trailing-whitespace nil)
    (erase-buffer)
    (insert "Hostname: " (system-name) "\n")
    (insert (propertize (with-temp-buffer
                          (call-process "df" nil t nil "-h")
                          (buffer-string))
                        'face 'menu))
    (insert (with-temp-buffer
              (call-process "ifconfig" nil t)
              (replace-string "\n\n" "\n" nil (point-min) (point-max))
              (buffer-string)))
    (insert (propertize (with-temp-buffer
                          (call-process "ssh-add" nil t nil "-l")
                          (buffer-string))
                        'face 'menu))
    (fit-window-to-buffer (get-buffer-window buf))
   (use-local-map map)
    (set-buffer-modified-p nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Moving through buffers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ff/next-buffer ()
  "Switches to the next buffer in cyclic order."
  (interactive)
  (let ((buffer (current-buffer)))
    (switch-to-buffer (other-buffer buffer))
    (bury-buffer buffer)))

(defun ff/prev-buffer ()
  "Switches to the previous buffer in cyclic order."
  (interactive)
  (let ((list (nreverse (buffer-list)))
        found)
    (while (and (not found) list)
      (let ((buffer (car list)))
        (if (and (not (get-buffer-window buffer))
                 (not (string-match "\\` " (buffer-name buffer))))
            (setq found buffer)))
      (setq list (cdr list)))
    (switch-to-buffer found)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Automatization of things I do often
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ff/snip () (interactive)
  (insert
   "---------------------------- snip snip -------------------------------\n"
   "---------------------------- snip snip -------------------------------\n"
   ))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Insert a line showing all the variables written on the current line
;; and separated by commas

(defun ff/cout-var (arg)
  "Invoked on a line with a list of variables names,
it inserts a line which displays their values in cout
(or cerr if the function is invoked with a universal arg)"
  (interactive "P")
  (let ((line (if arg "cerr" "cout")))
    (goto-char (point-at-bol))
    ;; Regexp syntax sucks moose balls, honnest. To match '[', just
    ;; put it as the first char in the [...] ... This leads to some
    ;; obvious things like the following
    (while (re-search-forward "\\([][a-zA-Z0-9_.:\(\)]+\\)" (point-at-eol) t)
      (setq line
            (concat line " << \" "
                    (match-string 1) " = \" << " (match-string 1))))
    (goto-char (point-at-bol))
    (kill-line)
    (insert line " << endl\;\n")
    (indent-region (point-at-bol 0) (point-at-eol 0) nil)
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ff/clean-article ()
  "Cleans up an article by removing the leading blanks on each line
and refilling all the paragraphs."
  (interactive)
(let ((fill-column 92))
  (goto-char (point-min))
  (while (re-search-forward "^\\ +" nil t)
    (replace-match "" nil nil))
  (fill-individual-paragraphs (point-min) (point-max) t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ff/count-words-region (beginning end)
  "Print number of words in the region.
Words are defined as at least one word-constituent character
followed by at least one character that is not a
word-constituent.  The buffer's syntax table determines which
characters these are."

  (interactive "r")
  (message "Counting words in region ... ")
  (save-excursion
    (goto-char beginning)
    (let ((count 0))
      (while (< (point) end)
        (re-search-forward "\\w+\\W+")
        (setq count (1+ count)))
      (cond ((zerop count) (message "The region does NOT have any word."))
            ((= 1 count) (message "The region has 1 word."))
            (t (message "The region has %d words." count))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Keymaping
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Moving around

(defun select-next-window ()
  "Switch to the next window"
  (interactive)
  (select-window (next-window)))

(defun select-previous-window ()
  "Switch to the previous window"
  (interactive)
  (select-window (previous-window)))

(global-set-key (kbd "M-}") 'select-next-window)
(global-set-key (kbd "M-{") 'select-previous-window)

(require 'info nil t)

;; shift-tab going backward is kind of standard
(define-key Info-mode-map [(shift iso-lefttab)] 'Info-prev-reference)

;; (define-key global-map [(control x) (control a)] 'auto-fill-mode)

;; Put back my keys, you thief!
(define-key global-map [(home)] 'beginning-of-buffer)
(define-key global-map [(end)] 'end-of-buffer)
;; (define-key global-map [(insertchar)] 'overwrite-mode)
(define-key global-map [(delete)] 'delete-char)

;; Cool shortcuts to move to the end / beginning of block keen
;; (define-key global-map [(control right)] 'forward-sexp)
;; (define-key global-map [(control left)] 'backward-sexp)

;; Wheel mouse moves up and down 2 lines (and DO NOT BEEP when we are
;; out of the buffer)

(define-key global-map [mouse-4]
  (lambda () (interactive) (condition-case nil (scroll-down 2) (error nil))))
(define-key global-map [mouse-5]
  (lambda () (interactive) (condition-case nil (scroll-up 2) (error nil))))

;; with shift it goes faster
(define-key global-map [(shift mouse-4)]
  (lambda () (interactive) (condition-case nil (scroll-down 50) (error nil))))
(define-key global-map [(shift mouse-5)]
  (lambda () (interactive) (condition-case nil (scroll-up 50) (error nil))))

;; Meta-? shows the properties of the character at point
(define-key global-map [(meta ??)]
  (lambda () (interactive)
    (message (prin1-to-string (text-properties-at (point))))))

;; Dictionnary lookup

(add-hook 'latex-mode-hook (lambda () (define-key latex-mode-map [(control tab)] 'ispell-complete-word)))

;; Meta-/ remaped (completion)

(define-key global-map [(shift right)] 'dabbrev-expand)

;; Change the current window.

(defun ff/next-same-frame-window () (interactive)
  (select-window (next-window (selected-window)
                              (> (minibuffer-depth) 0)
                              nil)))

(defun ff/previous-same-frame-window () (interactive)
  (select-window (previous-window (selected-window)
                                  (> (minibuffer-depth) 0)
                                  nil)))

(define-key global-map [(shift prior)] 'ff/next-same-frame-window)
(define-key global-map [(shift next)] 'ff/previous-same-frame-window)

(define-key global-map [(control })] 'enlarge-window-horizontally)
(define-key global-map [(control {)] 'shrink-window-horizontally)
(define-key global-map [(control \")] 'enlarge-window)
(define-key global-map [(control :)] 'shrink-window)

;; I have two screens sometime!

(define-key global-map [(meta next)] 'other-frame)
(define-key global-map [(meta prior)] (lambda () (interactive) (other-frame -1)))

(define-key global-map [(shift home)] 'ff/delete-other-windows-in-column)

;; (define-key global-map [(control +)] 'enlarge-window)
;; (define-key global-map [(control -)] 'shrink-window)

;; Goes to next/previous buffer

(define-key global-map [(control prior)] 'ff/next-buffer)
(define-key global-map [(control next)] 'ff/prev-buffer)

(define-key global-map [(control c) (control l)] 'goto-line)

;; Allow printing to PDF
(defun print-to-pdf ()
  (interactive)
  (setq font-zoom-index 5)
  (ps-spool-buffer-with-faces)
  (switch-to-buffer "*PostScript*")
  (write-file "/tmp/tmp.ps")
  (kill-buffer "tmp.ps")
  (setq cmd (concat "ps2pdf14 /tmp/tmp.ps " (buffer-name) ".pdf"))
  (shell-command cmd)
  (shell-command "rm /tmp/tmp.ps")
  (message (concat "Saved to:  " (buffer-name) ".pdf")))

;; Touch wsgi file
(defun touch-wsgi ()
  (interactive)
  (shell-command "touch /hunch/www/svn/www/www.hunch.com.wsgi.py")
  (message "Can't touch this!!"))
(define-key global-map [(control x) (control a)] 'touch-wsgi)
; touch the server
(add-hook 'before-save-hook 'touch-wsgi)

;; Remap meta key
(defun modmap ()
  (interactive)
  (shell-command "xmodmap /hunch/www/.Xmodmap")
  (message "Modmap executed"))
(define-key global-map [(control x) (control x)] 'modmap)

;; Unwrap paragraphs
(defun th-unfill-paragraph ()
"Do the opposite of `fill-paragraph'; stuff all lines in the
current paragraph into a single long line."
(interactive)
(let ((fill-column most-positive-fixnum))
(fill-paragraph nil)))

;; Tabs are bad, mmkay?
(setq-default indent-tabs-mode nil)
(setq ruby-indent-level 8)
(add-hook 'html-mode-hook
        (lambda ()
          ;; Default indentation is usually 2 spaces, changing to 4.
          (set (make-local-variable 'sgml-basic-offset) 4)))
(autoload 'espresso-mode "espresso")
(defun my-js2-indent-function ()
  (interactive)
  (save-restriction
    (widen)
    (let* ((inhibit-point-motion-hooks t)
           (parse-status (save-excursion (syntax-ppss (point-at-bol))))
           (offset (- (current-column) (current-indentation)))
           (indentation (espresso--proper-indentation parse-status))
           node)

      (save-excursion

        ;; I like to indent case and labels to half of the tab width
        (back-to-indentation)
        (if (looking-at "case\\s-")
            (setq indentation (+ indentation (/ espresso-indent-level 2))))

        ;; consecutive declarations in a var statement are nice if
        ;; properly aligned, i.e:
        ;;
        ;; var foo = "bar",
        ;;     bar = "foo";
        (setq node (js2-node-at-point))
        (when (and node
                   (= js2-NAME (js2-node-type node))
                   (= js2-VAR (js2-node-type (js2-node-parent node))))
          (setq indentation (+ 4 indentation))))

      (indent-line-to indentation)
      (when (> offset 0) (forward-char offset)))))
(defun my-js2-mode-hook ()
  (require 'espresso)
  (setq espresso-indent-level 4
        indent-tabs-mode nil
        c-basic-offset 4)
  (c-toggle-auto-state 0)
  (c-toggle-hungry-state 1)
  (set (make-local-variable 'indent-line-function) 'my-js2-indent-function)
  (define-key js2-mode-map [(meta control |)] 'cperl-lineup)
  (define-key js2-mode-map [(meta control \;)]
    '(lambda()
       (interactive)
       (insert "/* -----[ ")
       (save-excursion
         (insert " ]----- */"))
       ))
  (define-key js2-mode-map [(return)] 'newline-and-indent)
  (define-key js2-mode-map [(backspace)] 'c-electric-backspace)
  (define-key js2-mode-map [(control d)] 'c-electric-delete-forward)
  (define-key js2-mode-map [(control meta q)] 'my-indent-sexp)
  (if (featurep 'js2-highlight-vars)
    (js2-highlight-vars-mode))
  (message "My JS2 hook"))

(add-hook 'js2-mode-hook 'my-js2-mode-hook)

(define-key global-map [(meta q)] 'th-unfill-paragraph)

(custom-set-variables
  ;; custom-set-variables was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 '(c-basic-offset 8))
(custom-set-faces
  ;; custom-set-faces was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 )

; Key remapping
(define-key global-map [(meta r)] 'replace-string)
(define-key global-map [(meta p)] 'ansi-term)
(define-key global-map [(meta up)] 'ff/scroll-down)
(define-key global-map [(meta down)] 'ff/scroll-up)
(define-key global-map [(shift down)] 'ff/comment-and-go-down)
(define-key global-map [(shift up)] 'ff/uncomment-and-go-up)
(define-key global-map [(print)] 'ff/print-to-file)
;; Can you believe it? There is a "print" key on PC keyboards ...
(define-key global-map [(shift print)] 'ff/print-to-printer)
(define-key global-map [?\C-x right] 'ff/next-buffer)
(define-key global-map [?\C-x left] 'ff/prev-buffer)
(define-key global-map [(control z)] nil)

;; OLD STUFF - mostly for web

;; For mako: using nxml / nxhtml

;; nxhtml + mako

;; MEH: needs some work.  Maybe I should start looking at web-mode again...
;; (load "~/drewmacs/nxhtml/autostart.el")
;; (setq mumamo-background-colors nil)
;; (setq debug-on-error nil) ;; disable auto debugging
;; (add-to-list 'auto-mode-alist '("\\.mak$" . mako-nxhtml-mumamo-mode))
;; (add-to-list 'auto-mode-alist '("\\.mako$" . mako-nxhtml-mumamo-mode))

;; Django Stuffs
;; (load "~/drewmacs/django-html-mode.el")
;; (autoload 'django-html-mode "django-html-mode")
;; (add-to-list 'auto-mode-alist
