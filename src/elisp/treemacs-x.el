;;; treemacs.el --- A tree style file viewer package -*- lexical-binding: t -*-

(defun treemacs-insert-new-node (node parent pred)
  (-when-let (parent-pos (treemacs-find-node parent))
    (unless (treemacs-is-node-expanded? parent-pos)
      (treemacs-toggle-node parent-pos))
    (-let [insert-pos (treemacs-first-child-node-where parent-pos
                        (funcall pred node child-btn))]
      (treemacs-with-writable-buffer
       (-let [depth (1+ (treemacs-button-get parent-pos :depth))]
         (goto-char insert-pos)
         (end-of-line)
         (-let [strs (treemacs--create-file-button-strings
                      node
                      (concat "\n" (s-repeat (* depth treemacs-indentation) treemacs-indentation-string))
                      parent-pos
                      depth)]
           (-let [str (nth 2 strs)]
             (put-text-property
              0 (length str)
              'face (treemacs--get-button-face node treemacs--git-cache 'treemacs-git-unmodified-face) str))
           (treemacs-log "PROP %s %s" (nth 2 strs) (get-text-property 0 'face (nth 2 strs)))
           (insert (apply #'concat strs))))))))

(benchmark-run 1
  (with-current-buffer (treemacs-get-local-buffer)
    (save-excursion
      (treemacs-insert-new-node
       "treemacs-foo.el"
       "/home/a/Documents/git/treemacs/src/elisp"
       (lambda (x y)
         (treemacs-log "string> %s %s" (treemacs--get-label-of y) x)
         (string> x (treemacs--get-label-of y)))))))

(defconst std::test::nums
  (--map (make-string (random 20) ?A)
         (number-sequence 1 5000)))

(benchmark-run-compiled 500
  (treemacs--map-when-unrolled std::test::nums 3
    (propertize it 'face 'treemacs-git-unmodified-face)))

(benchmark-run-compiled 500
  (--each std::test::nums
    (when (= 0 (% it-index 2))
      (put-text-property 0 (length it) 'face 'treemacs-git-unmodified-face it))))

(defun treemacs-dom-node->all-parents (node)
  (let ((parent (treemacs-dom-node->parent node))
        (ret))
    (while parent
      (push parent ret)
      (setf parent (treemacs-dom-node->parent parent)))
    ret))

(defun treemacs-update-single-file (file)
  "Update node at given FILE path.
TODO rest."
  (let* ((local-buffer (current-buffer))
         (parent (treemacs--parent file))
         (parents (->> parent
                       (treemacs-find-in-dom)
                       (treemacs-dom-node->all-parents)
                       (-map #'treemacs-dom-node->key)))
         (current-state
          (pcase (or (-some-> treemacs--git-cache (ht-get parent) (ht-get file)) "0")
            ("M" "M")
            ("!" "!")
            ("?" "?")
            ((pred null) "0")
            (_ "M")))
         (cmd `("python" "-S" "-O" ,treemacs--single-file-git-status.py ,file ",current-state" ,@parents)))
    (pfuture-callback cmd
      :name "PF Test"
      :on-success
      (with-current-buffer local-buffer
        (treemacs-with-writable-buffer
         (pcase-dolist (`(,file . ,state) (read (pfuture-callback-output)))
           (treemacs-log "%s => %s" file state)
           (-when-let (pos (treemacs-find-visible-node file))
             (-let [face (treemacs--git-status-face state 'treemacs-git-unmodified-face)]
               (put-text-property
                (button-start pos) (button-end pos)
                'face face))))))
      :on-error
      (pcase (process-exit-status process)
        (2 (message "No Change"))
        (_ (message "Unknown exit code %s" status))))))

(with-current-buffer (treemacs-get-local-buffer)
  (treemacs-update-single-file "/home/a/Documents/git/treemacs/src/elisp/treemacs-async.el"))

(with-current-buffer (treemacs-get-local-buffer)
  (ht-get (ht-get treemacs--git-cache "/home/a/Documents/git/treemacs/src/elisp")
          "/home/a/Documents/git/treemacs/src/elisp/treemacs-impl.el"))
