
;; give the outer continuation as an extra argument
;; to the handler
(define-syntax with-continuation-handler
  (syntax-rules ()
    ((with-continuation-handler handler thunk)
     (call-with-current-continuation
      (lambda (k)
	(with-exception-handler 
	 (lambda (c)
	   (handler c k))
	 thunk))))))

;; call the handler in the outer continuation
(define-syntax with-except-handler
  (syntax-rules ()
    ((with-except-handler handler thunk)
     ((call-with-current-continuation
       (lambda (k)
	 (lambda ()
	   (with-exception-handler
	    (lambda (c)
	      (k (lambda ()
		   (handler c))))
	    thunk))))))))

;; ----------------
;; conditions
;;
;; kali-error  - kali-reader-error  - kali-reader-eof-error
;;                                  - kali-reader-insufficient-error
;;                                  - kali-reader-condvar-error
;;                                  - kali-unknown-reader-error
;;
;;             - kali-remote-error
;;
;;             - kali-send-message-to-self-error
;; 
;;             - kali-connection-error
;;

(define-condition-type &kali-error &error
  kali-error?)

;; --------------
;; reader
(define-condition-type &kali-reader-error &kali-error
  kali-reader-error?
  (channel kali-reader-error-channel))

(define-condition-type &kali-reader-eof-error &kali-reader-error
  kali-reader-eof-error?)

(define-condition-type &kali-reader-insufficient-error &kali-reader-error
  kali-reader-insufficient-error?
  (got     kali-reader-insufficient-error-got)
  (length  kali-reader-insufficient-error-length))

(define-condition-type &kali-reader-condvar-error &kali-reader-error
  kali-reader-condvar-error?)

(define-condition-type &kali-unknown-reader-error &kali-reader-error
  kali-unknown-reader-error?
  (condition kali-unknown-reader-error-condition))

;; -----------
;; remote
(define-condition-type &kali-remote-error &kali-error
  kali-remote-error?
  (aspace    kali-remote-error-aspace)
  (procedure kali-remote-error-procedure)
  (arguments kali-remote-error-arguments)
  (condition kali-remote-error-condition))

;; (define-condition-type &kali-remote-apply-error &kali-remote-error
;;   kali-remote-apply-error?)

;; -----------
;; send
(define-condition-type &kali-send-message-to-self-error &kali-error
  kali-send-message-to-self-error?
  (type kali-send-message-to-self-error-type)
  (message kali-send-message-to-self-error-message))

;; -----------
;; connect
(define-condition-type &kali-connect-error &kali-error
  kali-connect-error?
  (need-counts kali-connect-error-nedd-counts))

;; ----------
;; memory
(define-condition-type &kali-memory-layout-error &kali-error
  kali-memory-layout-error?
  (alien-vector kali-memory-layout-error-alien-vector)
  (local-vector kali-memory-layout-error-local-vector))