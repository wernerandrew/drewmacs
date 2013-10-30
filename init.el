;;(define-key input-decode-map "\e[1;2A" [S-up])
(define-key function-key-map "\e[1;2A" [S-up])

(setq backup-directory-alist
      `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms
      `((".*" ,temporary-file-directory t)))

(require 'mouse)
(xterm-mouse-mode t)
(defun track-mouse (e))
(setq mouse-sel-mode t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; .emacs file for gleit
;; rev: march, 2010
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; epylint
(autoload 'flymake-mode "flymake" "" t)
(when (load "flymake" t)
  (defun flymake-pylint-init ()
    (let* ((temp-file (flymake-init-create-temp-buffer-copy
		       'flymake-create-temp-inplace))
	   (local-file (file-relative-name
			temp-file
			(file-name-directory buffer-file-name))))
      (list "epylint" (list local-file))))

  (add-to-list 'flymake-allowed-file-name-masks
	       '("\\.py\\'" flymake-pylint-init)))

;; (add-to-list 'auto-mode-alist '("\\.py$" . (lambda()
;; 					     (python-mode)
;; 					     (flymake-mode))))

;;flymake-ler(file line type text &optional full-file)
(defun show-fly-err-at-point ()
  "If the cursor is sitting on a flymake error, display the
message in the minibuffer"
  (interactive)
  (let ((line-no (line-number-at-pos)))
    (dolist (elem flymake-err-info)
      (if (eq (car elem) line-no)
          (let ((err (car (second elem))))
            (message "%s" (fly-pyflake-determine-message err)))))))

(defun fly-pyflake-determine-message (err)
  "pyflake is flakey if it has compile problems, this adjusts the
message to display, so there is one ;)"
  (cond ((not (or (eq major-mode 'Python) (eq major-mode 'python-mode) t)))
        ((null (flymake-ler-file err))
         ;; normal message do your thing
         (flymake-ler-text err))
        (t ;; could not compile err
         (format "compile error, problem on line %s" (flymake-ler-line err)))))

(defadvice flymake-goto-next-error (after display-message activate compile)
  "Display the error in the mini-buffer rather than having to mouse over it"
  (show-fly-err-at-point))

(defadvice flymake-goto-prev-error (after display-message activate compile)
  "Display the error in the mini-buffer rather than having to mouse over it"
  (show-fly-err-at-point))

(defadvice flymake-mode (before post-command-stuff activate compile)
  "Add functionality to the post command hook so that if the
cursor is sitting on a flymake error the error information is
displayed in the minibuffer (rather than having to mouse over
it)"
  (set (make-local-variable 'post-command-hook)
       (cons 'show-fly-err-at-point post-command-hook)))

(define-key global-map [(control \<)] 'flymake-goto-prev-error)
(define-key global-map [(control \>)] 'flymake-goto-next-error)
(define-key global-map [(control \?)] 'show-fly-err-at-point)

;; Path
;; (setenv "PATH" (concat (getenv "PATH") "/hunch/appcore/python/2.5.4/bin"))
(setq exec-path (append exec-path '("/hunch/www/tools/pylint/bin")))

;; Create custom string-match-p function to if not defined
;; Necessary for web-mode
(defun my-string-match-p (regexp string &optional start)
  "Same as `string-match' except this function does not change the match data."
  (let ((inhibit-changing-match-data t))
    (string-match regexp string start)))

(when (not (fboundp 'string-match-p))
  (fset 'string-match-p (symbol-function 'my-string-match-p)))

;; Load the defaults
(load "emacs_inherit.el")
(custom-set-variables
  ;; custom-set-variables was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 '(js2-mode-escape-quotes 1)
 '(c-basic-offset 8)
 '(js2-cleanup-whitespace t))
(custom-set-faces
  ;; custom-set-faces was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 )

;; Some mac specific stuff

(if (boundp 'mac-command-modifier)
    (setq mac-command-modifier 'meta))

(define-key global-map [end] 'end-of-line)
(define-key global-map [home] 'beginning-of-line)
