; Copyright (c) 1993 by Richard Kelsey and Jonathan Rees.  See file COPYING.


; ,load-config =scheme48/alt/packages.scm
; ,open remote

; To start a server, do
;   (define sock (make-socket))
;   (serve sock)
; To start a client, do
;   (remote-repl "hostname" <number>)
; where <number> is the number displayed by the server when it starts up.


; Server side

(define (note-structure-locations! s)
  (let ((p (structure-package s)))
    (for-each-binding (lambda (name type binding)
			(if (and (pair? binding)
				 (not (eq? type 'syntax)))
			    (note-location! (cdr binding))))
		      s)))

(note-structure-locations! scheme-level-2)

(define (make-socket)
  (call-with-values socket-server cons))

(define (serve sock)
  (let ((port-number (car sock))
	(accept (cdr sock)))
    (display "Port number is ")
    (write port-number)
    (newline)
    (let ((in #f)
	  (out #f))
      (dynamic-wind (lambda ()
		      (call-with-values accept
			(lambda (i-port o-port)
			  (display "Open") (newline)
			  (set! in i-port)
			  (set! out o-port))))
		    (lambda ()
		      (start-server in out))
		    (lambda ()
		      (if in (close-input-port in))
		      (if out (close-output-port out)))))))

(define (start-server in out)
  (let loop ()
    (let ((message (restore-carefully in)))
      (case (car message)
	((run)
	 (dump (run-carefully (cdr message))
	       (lambda (c) (write-char c out))
	       -1)
	 (force-output out)
	 (loop))
	((eof) (cdr message))
	(else (error "unrecognized message" message))))))

(define (run-carefully template)
  (call-with-current-continuation
    (lambda (escape)
      (with-handler
	  (lambda (c punt)
	    (if (error? c)
		(escape (cons 'condition c))
		(punt)))
	(lambda ()
	  (call-with-values (lambda ()
			      (invoke-closure (make-closure template #f)))
	    (lambda vals
	      (cons 'values vals))))))))


; Client side

(define (make-remote-eval in out)
  (lambda (form p)
    (compile-and-run-forms (list form)
			   p
			   #f
			   (lambda (template)
			     (dump (cons 'run template)
				   (lambda (c) (write-char c out))
				   -1)
			     (force-output out)
			     (let ((reply (restore-carefully in)))
			       (case (car reply)
				 ((values)
				  (apply values (cdr reply)))
				 ((condition)
				  (signal-condition (cdr reply)))
				 ((eof)
				  (error "eof on connection")))))
			   #f)))


(define (make-remote-package in out opens id)
  (let ((for-syntax (package-for-syntax (interaction-environment))))
    (make-simple-package opens
			 (make-remote-eval in out)
			 (delay for-syntax)
			 id)))

(define (remote-repl host-name socket-port-number)
  (let ((in #f) (out #f))
    (dynamic-wind
     (lambda ()
       (call-with-values (lambda ()
			   (socket-client host-name socket-port-number))
	 (lambda (i-port o-port)
	   (set! in i-port)
	   (set! out o-port))))
     (lambda ()
       (command-loop list #f
		     (make-remote-package in out (list scheme) 'remote)))
     (lambda ()
       (if in (close-input-port in))
       (if out (close-output-port out))))))


; Common auxiliary

(define (restore-carefully in)
  (call-with-current-continuation
    (lambda (exit)
      (restore (lambda ()
		 (let ((c (read-char in)))
		   (if (eof-object? c)
		       (exit (cons 'eof c))
		       c)))))))
