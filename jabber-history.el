;; jabber-history.el - recording message history

;; Copyright (C) 2004 - Mathias Dahl
;; Copyright (C) 2004 - Magnus Henoch - mange@freemail.hu

;; This file is a part of jabber.el.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

;;; Log format:
;; Each message is on one separate line, represented as a vector with
;; five elements.  The first element is time encoded according to
;; JEP-0082.  The second element is direction, "in" or "out".
;; The third element is the sender, "me" or a JID.  The fourth
;; element is the recipient.  The fifth element is the text
;; of the message.

(defcustom jabber-history-enabled nil
  "Non-nil means message logging is enabled"
  :type 'boolean
  :group 'jabber)

(defun jabber-message-history (from buffer text proposed-alert)
  "Log message to log file. For now, all messages from all users
will be logged to the same file."
  (if jabber-history-enabled
      ;; timestamp is dynamically bound from jabber-display-chat
      (jabber-history-log-message "in" from nil text timestamp)))

(defun jabber-history-log-message (direction from to body timestamp)
  "Log a message"
  (with-temp-buffer
    ;; Encode text as Lisp string - get decoding for free
    (setq body (prin1-to-string body))
    ;; Encode LF and CR
    (while (string-match "\n" body)
      (setq body (replace-match "\\n" nil t body nil)))
    (while (string-match "\r" body)
      (setq body (replace-match "\\r" nil t body nil)))
    (insert (format "[\"%s\" \"%s\" \"%s\" \"%s\" %s]\n"
		    (jabber-encode-time (or timestamp (current-time)))
		    (or direction
			"in")
		    (or from
			"me")
		    (or to
			"me")
		    body))
    (let ((coding-system-for-write 'utf-8))
      (append-to-file (point-min) (point-max) "~/.jabber_global_message_log"))))

(defun jabber-history-query (time-compare-function
			     time
			     number
			     direction
			     jid-regexp)
  "Return a list of vectors, one for each message matching the criteria.
TIME-COMPARE-FUNCTION is either `<' or `>', to be called as
\(TIME-COMPARE-FUNCTION (float-time time-of-message) TIME), and
returning non-nil for matching messages.
NUMBER is the maximum number of messages to return, or t for
unlimited.
DIRECTION is either \"in\" or \"out\", or t for no limit on direction.
JID-REGEXP is a regexp which must match the JID."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents "~/.jabber_global_message_log"))
    (let ((from-beginning (eq time-compare-function '<))
	  collected current-line)
      (if from-beginning
	  (goto-char (point-min))
	(goto-char (point-max))
	(backward-sexp))
      (while (progn (setq current-line (car (read-from-string
					     (buffer-substring
					      (point)
					      (save-excursion
						(forward-sexp)
						(point))))))
		    (and (funcall time-compare-function
				  (float-time (jabber-parse-time
					       (aref current-line 0)))
				  time)
			 (if from-beginning (not (eobp))
			   (not (bobp)))
			 (or (eq number t)
			     (< (length collected) number))))
	(if (and (or (eq direction t)
		     (string= direction (aref current-line 1)))
		 (string-match 
		  jid-regexp 
		  (car
		   (remove "me"
			   (list (aref current-line 2)
				 (aref current-line 3))))))
	    (push current-line collected))
	(if from-beginning (forward-sexp) (backward-sexp)))
      collected)))

;; Try it with:
;; (setq jabber-history-enabled t)
;; (add-hook 'jabber-alert-message-hooks 'jabber-message-history)

(provide 'jabber-history)

;; arch-tag: 0AA0C235-3FC0-11D9-9FE7-000A95C2FCD0
