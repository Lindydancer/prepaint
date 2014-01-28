;;; prepaint.el -- Highlight C-style preprocessor directives.

;; Copyright (C) 2003,2007,2014 Anders Lindgren

;; Author: Anders Lindgren
;; Keywords: c, languages, faces
;; Version: 0.0.0

;; Prepaint is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; Prepaint is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;;{{{ Documentation

;; *Prepaint* is an Emacs package that highlight C-style preprocessor
;; statements. The main feature is support for macros that span
;; multiple lines.
;;
;; Prepaint is implemented as two minor modes: `prepaint-mode' and
;; `global-prepaint-mode'.  The former can be applied to individual buffers
;; and the latter to all buffers.
;;
;; Activate this package by Customize, or by placing the following line
;; into the appropriate init file:
;;
;;    (global-prepaint-mode 1)
;;
;; This package use Fone Lock mode, so `font-lock-mode' or
;; `global-font-lock-mode' must be enabled.

;; Example:
;;
;; Below is a screenshot of a sample C file, demonstrating the effect
;; of this package:
;;
;; ![See doc/demo.png for screenshot of Prepaint mode](doc/demo.png)

;;}}}

;;; Code:

;;{{{ Dependencies

(eval-when-compile (require 'cl))

(require 'custom)
(require 'font-lock)
(require 'cc-mode)

;;}}}
;;{{{ Variables

(defgroup prepaint nil
  "Paint preprocessor lines in a different color."
  :group 'faces)

(defvar prepaint-mode nil
  "*Non-nil when Prepaint mode is active.

Never set this variable directly, use the command `prepaint-mode'
instead.")

(defcustom global-prepaint-mode nil
  "When on, proprocessor lines are in a different color.

Set this variable using \\[customize] or use the command
`global-prepaint-mode'."
  :group 'prepaint
  :initialize 'custom-initialize-default
  :set '(lambda (symbol value)
	  (global-prepaint-mode (or value 0)))
  :type 'boolean
  :require 'prepaint)

(defcustom prepaint-verbose t
  "When nil, Prepaint mode will not generate any messages.

Currently, messages are generated when the mode is activated and
deactivated."
  :group 'prepaint
  :type 'boolean)

(defcustom prepaint-mode-text " Prepaint"
  "String to display in the mode line when Prepaint mode is active.

\(When the string is not empty, make sure that it has a leading space.)"
  :tag "Prepaint mode text"                ; To separate it from `global-...'
  :group 'prepaint
  :type 'string)

(defcustom prepaint-mode-hook nil
  "Functions to run when Prepaint mode is activated."
  :tag "Prepaint mode hook"                ; To separate it from `global-...'
  :group 'prepaint
  :type 'hook)

(defcustom global-prepaint-mode-text ""
  "String to display when Global Prepaint mode is active.

The default is nothing since when this mode is active this text doesn't
vary over time, or between buffers.  Hence mode line text
would only waste precious space."
  :group 'prepaint
  :type 'string)

(defcustom global-prepaint-mode-hook nil
  "Hook called when Global Prepaint mode is activated."
  :group 'prepaint
  :type 'hook)

(defcustom prepaint-load-hook nil
  "Functions to run when Prepaint mode is first loaded."
  :tag "Load Hook"
  :group 'prepaint
  :type 'hook)


(defface prepaint-face
  '((((class color) (background light)) (:background "Grey85")))
  "Face for prepaint."
  :group 'prepaint)

(defvar prepaint-modes '(c-mode c++-mode objc-mode))

;;}}}
;;{{{ The modes

;;;###autoload
(defun prepaint-mode (&optional arg)
  "Minor mode that paints preprocessor lines in a different color."
  (interactive "P")
  (make-local-variable 'prepaint-mode)
  (setq prepaint-mode
	(if (null arg)
	    (not prepaint-mode)
	  (> (prefix-numeric-value arg) 0)))
  (if (and prepaint-verbose
	   (interactive-p))
      (message "Prepaint mode is now %s."
	       (if prepaint-mode "on" "off")))
  (if (not global-prepaint-mode)
      (if prepaint-mode
	  (prepaint-font-lock-add-keywords)
	(prepaint-font-lock-remove-keywords)))
  (font-lock-fontify-buffer)
  (if prepaint-mode
      (run-hooks 'prepaint-mode-hook)))

;;;###autoload
(defun turn-on-prepaint-mode ()
  "Turn on Prepaint mode.

This function is designed to be added to hooks, for example:
  (add-hook 'c-mode-hook 'turn-on-prepaint-mode)"
  (prepaint-mode 1))

;;;###autoload
(defun global-prepaint-mode (&optional arg)
  "Paint processors lines in a different color in all buffers.

With arg, turn Prepaint mode on globally if and only if arg is positive."
  (interactive "P")
  (let ((old-global-prepaint-mode global-prepaint-mode))
    (setq global-prepaint-mode
	  (if (null arg)
	      (not global-prepaint-mode)
	    (> (prefix-numeric-value arg) 0)))
    (if (and prepaint-verbose
	     (interactive-p))
	(message "Global Prepaint mode is now %s."
		 (if global-prepaint-mode "on" "off")))
    (when (not (eq global-prepaint-mode old-global-prepaint-mode))
      ;; Update for all future buffers.
      (dolist (mode prepaint-modes)
	(if global-prepaint-mode
	    (prepaint-font-lock-add-keywords mode)
	  (prepaint-font-lock-remove-keywords mode)))
      ;; Update all existing buffers.
      (save-excursion
	(dolist (buffer (buffer-list))
	  (set-buffer buffer)
	  ;; Update keywords in alive buffers.
	  (when (and font-lock-mode
		     (not prepaint-mode)
		     (prepaint-is-enabled major-mode))
	    (if global-prepaint-mode
		(prepaint-font-lock-add-keywords)
	      (prepaint-font-lock-remove-keywords))
	    (font-lock-fontify-buffer))))))
    ;; Kills all added keywords :-(
    ;; (font-lock-mode 0)
    ;; (makunbound 'font-lock-keywords)
    ;; (font-lock-mode 1))))
  (when global-prepaint-mode
    (run-hooks 'global-prepaint-mode-hook)))

;;}}}
;;{{{ Help functions

(defun prepaint-is-enabled (mode)
  "Non-nil if Prepaint FEATURE is enabled for MODE."
  c-buffer-is-cc-mode)

;;}}}
;;{{{ Match functions

;; The idea here is to use the font-lock "achored" model. We match the
;; "#" sign and then do a submatch line-by-line for the preprocessor
;; statement.
;;
;; The main match function `prepaint-match-statement-line' finds the
;; end of the preprocessor statement. The line-by-line matching
;; function simple match each line until it reaches the limit.
;;
;; Note: Should we match the entire statement as one single match,
;; Emacs would extend the highlighted area to the right side of the
;; display. With the current solution, the highligt stop at the last
;; character on the line.

(defvar prepaint-match-debug nil
  "When non-nil, messages are beging echoed.")

(defun prepaint-match-pre ()
  ;; Set up the line-by-line search.
  (if prepaint-match-debug
      (message "prepaint-match-pre called. Point is %s" (point)))
  ;; ----------
  ;; Tell font-lock not to stop after one or a few lines.
  (setq font-lock-multiline t)
  ;; Move the point to include the "#" part.
  (beginning-of-line)
  ;; ----------
  ;; Find the end of the preprocessor statement.
  ;;
  ;; (Note: Do not return "point-max"; it works but it really slows
  ;; down font-lock.)
  (save-excursion
    (while (progn
             (end-of-line)
             (and
              (eq (char-before) ?\\)
              (not (eobp))))
      (forward-line))
    (point)))                           ; Return new search limit.


(defun prepaint-match-statement-line (limit)
  "Match function for highlighting preprocessor statements."
  (if prepaint-match-debug
      (message "prepaint-match-statement-line called at %s with limit %s"
               (point) limit))
  ;; Match one line at a time until we hit the limit.
  (if (>= (point) limit)
      nil
    (looking-at "^.*$")                 ; Always true.
    (forward-line)
    t))


(defvar prepaint-font-lock-keywords
  '(("^\\s *#"
     (prepaint-match-statement-line
      (prepaint-match-pre)
      nil
      (0 'prepaint-face append t)))))

(defun prepaint-font-lock-add-keywords (&optional mode)
  "Install keywords into major MODE, or into current buffer if nil."
  (font-lock-add-keywords mode prepaint-font-lock-keywords t))

(defun prepaint-font-lock-remove-keywords (&optional mode)
  "Remove keywords from major MODE, or from current buffer if nil."
  (font-lock-remove-keywords mode prepaint-font-lock-keywords))

;;}}}
;;{{{ Profile support

;; The following (non-evaluated) section can be used to
;; profile this package using `elp'.
;;
;; Invalid indentation on purpose!

(cond (nil
(setq elp-function-list
      '(prepaint-match-statement-line))))

;;}}}

;;{{{ The end

(unless (assq 'prepaint-mode minor-mode-alist)
  (push '(prepaint-mode prepaint-mode-text)
	minor-mode-alist))
(unless (assq 'global-prepaint-mode minor-mode-alist)
  (push '(global-prepaint-mode global-prepaint-mode-text)
	minor-mode-alist))

(provide 'prepaint)

(run-hooks 'prepaint-load-hook)

;; This makes it possible to set Global Prepaint mode from
;; Customize.
(if global-prepaint-mode
    (global-prepaint-mode 1))

;;}}}

;;; prepaint.el ends here.
