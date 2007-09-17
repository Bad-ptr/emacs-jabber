;; jabber-logon.el - logon functions

;; Copyright (C) 2003, 2004, 2007 - Magnus Henoch - mange@freemail.hu
;; Copyright (C) 2002, 2003, 2004 - tom berger - object@intelectronica.net

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

(require 'jabber-xml)
(require 'jabber-util)
;; sha1-el is known under two names
(condition-case e
    (require 'sha1)
  (error (require 'sha1-el)))

(defun jabber-get-auth (jc to session-id)
  "Send IQ get request in namespace \"jabber:iq:auth\"."
  (jabber-send-iq jc to
		  "get"
		  `(query ((xmlns . "jabber:iq:auth"))
			  (username () ,(plist-get (fsm-get-state-data jc) :username)))
		  #'jabber-do-logon session-id
		  #'jabber-report-success "Impossible error - auth field request"))

(defun jabber-do-logon (jc xml-data session-id)
  "send username and password in logon attempt"
  (let (auth)
    (if (jabber-xml-get-children (jabber-iq-query xml-data) 'digest)
	;; SHA1 digest passwords allowed
	(let ((passwd (or (plist-get (fsm-get-state-data jc) :password)
			  (jabber-read-password (jabber-connection-bare-jid jc)))))
	  (if passwd
	      (setq auth `(digest () ,(sha1 (concat session-id passwd))))))
      ;; Plaintext passwords - allow on encrypted connections
      (if (or (plist-get (fsm-get-state-data jc) :encrypted)
	      (yes-or-no-p "Jabber server only allows cleartext password transmission!  Continue? "))
	  (let ((passwd (jabber-read-password (jabber-connection-bare-jid jc))))
	    (when passwd
	      (setq auth `(password () ,passwd))))))
      
    ;; If auth is still nil, user cancelled process somewhere
    (if auth
	(jabber-send-iq jc (plist-get (fsm-get-state-data jc) :server)
			"set"
			`(query ((xmlns . "jabber:iq:auth"))
				(username () ,(plist-get (fsm-get-state-data jc) :username))
				,auth
				(resource () ,(plist-get (fsm-get-state-data jc) :resource)))
			#'jabber-process-logon t
			#'jabber-process-logon nil)
      (fsm-send jc :authentication-failure))))

(defun jabber-process-logon (jc xml-data closure-data)
  "receive login success or failure, and request roster.
CLOSURE-DATA should be t on success and nil on failure."
  (if closure-data
      ;; Logon success
	(fsm-send jc :authentication-success)

    ;; Logon failure
    (jabber-report-success jc xml-data "Logon")
    (jabber-uncache-password (jabber-connection-bare-jid jc))
    (fsm-send jc :authentication-failure)))

(provide 'jabber-logon)

;;; arch-tag: f24ebe5e-3420-44bb-af81-d4de21f378b0
