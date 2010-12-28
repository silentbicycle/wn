;;; wn.el --- thin wn wrapper for Emacs
;;
;; Copyright (c) 2010 Scott Vokes <vokes.s@gmail.com>
;;
;; Permission to use, copy, modify, and/or distribute this software for any
;; purpose with or without fee is hereby granted, provided that the above
;; copyright notice and this permission notice appear in all copies.
;;
;; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
;; WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
;; ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
;; ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
;; OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

; (global-set-key (kbd "C-c C-M-w") 'wn)
(defvar wn-program-name "wn")

(defun wn ()
  "Print what to do next."
  (interactive)
  (shell-command wn-program-name nil))

(defun wn-add (taskname)
  "Add a new task. Task name can be followed by an optional description."
  (interactive "sTask: ")
  (shell-command (concat wn-program-name " add "
                         taskname
                         nil)))

(defun wn-done (taskname)
  "Flag a task as done."
  (interactive "sTask: ")
  (shell-command (concat wn-program-name " done "
                         (shell-quote-argument taskname)
                         nil)))

(defun wn-leaves ()
  "Print leaves."
  (interactive)
  (shell-command (concat wn-program-name " leaves") nil))

(defun wn-tasks ()
  "Print tasks."
  (interactive)
  (shell-command (concat wn-program-name " tasks") nil))

(defun wn-info (taskname)
  "Print info about a task."
  (interactive "sTask: ")
  (shell-command (concat wn-program-name " info "
                         (shell-quote-argument taskname)
                         nil)))

(defun wn-dependencies (task-and-deps)
  "Add dependencies to a task"
  (interactive "sTask and deps: ")
  (shell-command (concat wn-program-name " dep "
                         task-and-deps
                         nil)))

(provide 'wn)
;;; wn.el ends here
