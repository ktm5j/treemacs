;;; treemacs.el --- A tree style file viewer package -*- lexical-binding: t -*-

;; Copyright (C) 2018 Alexander Miller

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;; TODO(2019/01/22)

;;; Code:

(require 'dash)
(require 'treemacs-extensions)
(require 'treemacs-interface)
(require 'treemacs-rendering)
(require 'treemacs-impl)
(eval-when-compile
  (require 'inline)
  (require 'treemacs-macros))

(treemacs-import-functions-from "treemacs-interface"
  treemacs-define-TAB-action)

(treemacs--setup-icon treemacs-buffer-group-open "buffer-group-open.png")
(treemacs--setup-icon treemacs-buffer-group-closed "buffer-group-closed.png")

;; (treemacs--setup-icon )

(defvar-local treemacs--buffers-project nil)
(define-inline treemacs-icon-for-file (path)
  "Retrieve an icon for PATH from `treemacs-icons-hash'.
Uses `treemacs-icon-fallback' as fallback."
  (declare (pure t))
  (inline-letevals (path)
    (inline-quote
     (ht-get treemacs-icons-hash
             (-> ,path (treemacs--file-extension) (downcase))
             treemacs-icon-fallback))))

(defun treemacs--get-buffer-groups ()
  "Get the list of buffers, grouped by their major mode."
  (->> (buffer-list)
       (--reject
        (or (eq ?\ (aref (buffer-name it) 0))
            (memq (buffer-local-value 'major-mode it)
                  '(help-mode helm-major-mode))))
       (--group-by (buffer-local-value 'major-mode it))))

(defun treemacs--get-buffer-group (mode)
  "Get all buffers with given major MODE."
  ;; TODO(2019/01/25): sort?
  (--filter (eq mode (buffer-local-value 'major-mode it))
            (buffer-list)))

(defun treemacs--visit-buffer (buffer)
  "Switch to the given BUFFER."
  (switch-to-buffer buffer))

(treemacs-define-leaf-node buffer-leaf
  (treemacs-as-icon "• " 'face 'font-lock-builtin-face))

(treemacs-define-expandable-node buffer-group
  :icon-open-form
  (treemacs-icon-for-major-mode
   (treemacs--get-label-of btn)
   treemacs-buffer-group-open)

  :icon-closed-form
  (treemacs-icon-for-major-mode
   (treemacs--get-label-of btn)
   treemacs-buffer-group-closed)

  :query-function
  (treemacs--get-buffer-group (intern (treemacs--get-label-of btn)))

  :render-action
  (treemacs-render-node
   :icon treemacs-buffer-leaf-icon
   :label-form (buffer-name item)
   :state treemacs-buffer-leaf-state
   :face 'font-lock-string-face
   :key-form item
   :more-properties (:buffer item)))

(treemacs-define-expandable-node buffers-root
  :icon-open (treemacs-as-icon "- " 'face 'font-lock-string-face)
  :icon-closed (treemacs-as-icon "+ " 'face 'font-lock-string-face)
  :query-function (treemacs--get-buffer-groups)
  :render-action
  (treemacs-render-node
   :icon (treemacs-icon-for-major-mode
          (symbol-name (car item))
          treemacs-buffer-group-closed)
   :label-form (symbol-name (car item))
   :state treemacs-buffer-group-closed-state
   :face 'font-lock-keyword-face
   :key-form (car item)
   :more-properties (:buffers (cdr item)))
  :top-level-marker t
  :root-label "Buffers"
  :root-face 'treemacs-root-face
  :root-key-form 'treemacs-buffers)

(treemacs-define-top-level-extension
 :extension #'treemacs-BUFFERS-ROOT-extension
 :position 'top)

(treemacs-define-RET-action 'treemacs-buffer-leaf-state #'treemacs-visit-node-no-split)

(defvar treemacs--ignored-major-modes '(help-mode fundamental-mode helm-major-mode messages-buffer-mode)
  "TODO.")

(defun treemacs--hook-into-buffer-for-view ()
  "TODO."
  (unless (or (eq ?\ (aref (buffer-name) 0))
              (memq major-mode treemacs--ignored-major-modes))
    (add-hook 'kill-buffer-hook #'treemacs--on-viewed-buffer-kill nil :local)
    (-let [_mode major-mode]
      (treemacs-run-in-every-buffer
       (--when-let (treemacs-find-in-dom `(,treemacs-buffers-root-extension-project))
         (treemacs-save-position
          (treemacs-update-node `(,treemacs-buffers-root-extension-project))))))))

(defun treemacs--on-viewed-buffer-kill ()
  "TODO."
  (treemacs-log "Local delete %s" (current-buffer))
  (let ((buf (current-buffer))
        (mode major-mode))
    (treemacs-run-in-every-buffer
     (--when-let (treemacs-find-in-dom
                  `(,treemacs-buffers-root-extension-project ,mode))
       (treemacs-delete-single-node `(:custom ,mode ,buf))
       (treemacs-log "Delete!")))))

;; (defconst treemacs-icon-buffer-group-closed
;;   (treemacs-as-icon "+ "))

;; (defconst treemacs-icon-buffer-group-closed
;;   (treemacs-as-icon "- "))

(define-inline treemacs-icon-for-major-mode (mode default)
  "Retrieve an icon for MODE from `treemacs-icons-hash'.
TODO fallback."
  (inline-letevals (mode default)
    (inline-quote
     (ht-get treemacs-icons-hash
             ,mode
             ,default))))

(add-hook 'after-change-major-mode-hook #'treemacs--hook-into-buffer-for-view)

(provide 'treemacs-buffers)

;;; treemacs-buffers.el ends here
