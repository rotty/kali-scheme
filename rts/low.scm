; Copyright (c) 1993 by Richard Kelsey and Jonathan Rees.  See file COPYING.


; Low-level things that rely on the fact that we're running under the
; Scheme 48 VM.

; Needs LET macro.


; Characters are represented in ASCII.

(define char->integer char->ascii)
(define integer->char ascii->char)
(define ascii-limit 256)		;for reader

(define ascii-whitespaces '(32 10 9 12 13)) ;space linefeed tab page return


; Procedures and closures are two different abstractions.  Procedures
; are created by LAMBDA and invoked with procedure call; those are
; their only defined operations.  Closures are made with MAKE-CLOSURE,
; accessed using CLOSURE-TEMPLATE and CLOSURE-ENV, and invoked by
; INVOKE-CLOSURE, which starts the virtual machine going.

; In a running Scheme 48 system, the two happen to be implemented
; using the same data type.  The following is the only part of the
; system that should know this fact.

(define procedure? closure?)

(define (invoke-closure thunk-closure . args)
  (apply thunk-closure args))


; Similarly, there are "true" continuations and there are VM
; continuations.  True continuations are obtained with PRIMITIVE-CWCC
; and invoked with WITH-CONTINUATION.  VM continuations are obtained
; with PRIMITIVE-CATCH and inspected using CONTINUATION-REF and
; friends.  The dbeugger assumes that a VM continuation can be
; extracted from a true one using EXTRACT-CONTINUATION.

; In a running Scheme 48 system, the two happen to be implemented
; using the same data type.  The following is the only part of the
; system that should know this fact.

(define primitive-cwcc primitive-catch)


; These two procedures are part of the location abstraction.

(define (make-undefined-location id)
  (let ((loc (make-location #f id)))
    (set-location-defined?! loc #f)
    loc))

(define (location-assigned? loc)
  (if (eq? (contents loc) (unassigned)) #f #t)) ;NOT is undefined


; STRING-COPY is here because it's needed by STRING->SYMBOL.

(define (string-copy s)
  (let ((z (string-length s)))
    (let ((copy (make-string z #\space)))
      (let loop ((i 0))
	(cond ((= i z) copy)
	      (else
	       (string-set! copy i (string-ref s i))
	       (loop (+ i 1))))))))


; The symbol table

(define (string->symbol string)
  (really-string->symbol (if (immutable? string)
			     string	;+++
			     (string-copy string))))

(define (really-string->symbol string)
  (if (eq? *the-symbol-table* #f)
      (restore-the-symbol-table!))
  (make-immutable! string)
  (let ((sym (intern string *the-symbol-table*)))
    (make-immutable! sym)
    sym))

(define *the-symbol-table* #f)

(define (flush-the-symbol-table!)
  (set! *the-symbol-table* #f))

(define (restore-the-symbol-table!)
  (set! *the-symbol-table* (make-vector 512 '()))
  (find-all-symbols *the-symbol-table*))

(restore-the-symbol-table!)


; I/O

(define (maybe-open-input-file string)
  (open-port string 1))

(define (maybe-open-output-file string)
  (open-port string 2))

(define (open-input-file string)
  (or (maybe-open-input-file string)
      (error "can't open for input" string)))

(define (open-output-file string)
  (or (maybe-open-output-file string)
      (error "can't open for output" string)))

(define close-input-port  close-port)
(define close-output-port close-port)


; HALT is for the exception system to call when all else fails.

(define (halt n)
  (with-continuation #f (lambda () n)))
