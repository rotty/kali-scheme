; -*- Mode: Scheme; Syntax: Scheme; Package: Scheme; -*-
; Copyright (c) 1993-2001 by Richard Kelsey and Jonathan Rees. See file COPYING.

;;;; Disassembler

; This will need to track the template's offset.  Drat.

; This defines a command processor command
;      dis <expression>
; that evaluates <expression> to obtain a procedure or lambda-expression,
; which is then disassembled.

; The assembly language is designed to be rereadable.  See env/assem.scm.

(define-command-syntax 'dis "[<exp>]" "disassemble procedure"
  '(&opt expression))

; The command.  The thing to be disassembled defaults to the focus object (##).

(define (dis . maybe-exp)
  (disassemble (if (null? maybe-exp)
		   (focus-object)
		   (eval (car maybe-exp) (environment-for-commands)))))

(define (disassemble obj)
  (really-disassemble (coerce-to-template-or-code obj) 0)
  (newline))

(define (really-disassemble template-or-code level)
    (let* ((template (if (template? template-or-code)
                         template-or-code
                         #f))
           (code (if template
                     (template-code template)
                     template-or-code)))
      (parse-template-code 
       template code level
       (make-attribution disasm-init-template disasm-attribute-literal 
                         disasm-table disasm-make-label disasm-at-label))))


(define (disasm-init-template level template p-args push-template? push-env?)
  (if (template-name template)
      (write (template-name template)))
  (print-opcode (enum op protocol) 0 level)
  (show-protocol p-args 0)
  (if (or push-template? push-env?)
      (begin
        (display " (push")
        (if push-env?
            (display " env"))
        (if push-template?
            (display " template"))
        (display #\))))
  (display #\))
  level)

(define (disasm-attribute-literal literal index level)
  level)

(define (disasm-make-label target-pc)
  target-pc)

(define (disasm-at-label label level)
  level)

(define disasm-table (make-opcode-table
                               (lambda (opcode template level pc . args)
                                 (print-opcode opcode pc level)
                                 (print-opcode-args args)
                                 (display #\))
                                 level)))

(define-syntax define-disasm
  (syntax-rules ()
    ((define-disasm inst disasm)
     (opcode-table-set! disasm-table (enum op inst) disasm))))

;------------------------------
(define-disasm protocol
  (lambda (opcode template level pc p-args)
    (print-opcode opcode pc level)
    (show-protocol (cdr p-args) pc)
    (display #\))
    level))

(define (show-protocol p-args pc)
  (let ((protocol (car p-args)))
    (display #\space)
    (cond ((<= protocol maximum-stack-args)
           (display protocol))
          ((= protocol two-byte-nargs-protocol)
           (display (cadr p-args)))
          ((= protocol two-byte-nargs+list-protocol)
           (display (cadr p-args))
           (display " +"))
          ((= protocol ignore-values-protocol)
           (display "discard all values"))
          ((= protocol call-with-values-protocol)
           (display "call-with-values")
           (let ((target-pc (cadr p-args)))
             (if (not (= pc target-pc))
                 (begin
                   (display #\space)
                   (write `(=> ,(cadr p-args)))))))
          ((= protocol args+nargs-protocol)
           (display "args+nargs ")
           (display (cadr p-args))
           (display "+"))
          ((= protocol nary-dispatch-protocol)
           (display "nary-dispatch")
           (for-each display-dispatch (cdr p-args) (list 0 1 2 "3+")))
          ((= protocol big-stack-protocol)
           (apply
            (lambda (real-attribution stack-size)
              (display "big-stack")
              (show-protocol real-attribution pc)
              (display #\space)
              (display stack-size))
            (cdr p-args)))
          (else
           (error "unknown protocol" protocol)))))

(define (display-dispatch target-pc tag)
  (if target-pc
      (begin
        (display #\space)
        (display (list tag '=> target-pc)))))

;------------------------------
(define-disasm global
  (lambda (opcode template level pc index-to-template index-within-template)
    (print-opcode opcode pc level)
    (print-opcode-args (list index-to-template index-within-template))
    (display #\space)
    (display-global-reference template (cdr index-within-template))
    (display #\))
    level))

(define-disasm set-global!
  (lambda (opcode template level pc index-to-template index-within-template)
    (print-opcode opcode pc level)
    (print-opcode-args (list index-to-template index-within-template))
    (display #\space)
    (display-global-reference template (cdr index-within-template))
    (display #\))
    level))    

(define (display-global-reference template index)
  (let ((loc (if template
		 (template-ref template index)
		 #f)))
    (cond ((location? loc)
	   (write (or (location-name loc)
		      `(location ,(location-id loc)))))
	  (else
	   (display #\')
	   (write loc)))))


;------------------------------
(define (disasm-make-flat-env opcode template level pc env-data-arg)
  (let ((env-data (cdr env-data-arg)))
    (print-opcode opcode pc level)
    (display #\space)
    (write (env-data-total-count env-data))
    (display #\space)
    (let ((closure-offsets (env-data-closure-offsets env-data)))
      (if closure-offsets
          (begin
            (write (- (length closure-offsets) 1))
            (display-flat-env-closures closure-offsets))
          (write 0)))

    (display #\space)
    (display (env-data-frame-offsets env-data))

    (for-each (lambda (env-offset)
                (display #\space)
                (display #\()
                (display (car env-offset))
                (display " => ")
                (display (cdr env-offset))
                (display #\)))
              (env-data-env-offsets env-data))
    (display #\))
    level))

(define (display-flat-env-closures closure-offsets)
  (display " (closures from ")
  (display (car closure-offsets))
  (display #\:)
  (for-each (lambda (offset)
              (display #\space)
              (display offset))
            (cdr closure-offsets))
  (display #\)))

(define-disasm make-flat-env disasm-make-flat-env)
(define-disasm make-big-flat-env disasm-make-flat-env)

;------------------------------

(define (display-cont-data cont-data)
  (let ((gc-mask (bytes->bits (cont-data-mask-bytes cont-data))))
    (write-char #\space)
    (display (list (cont-data-depth cont-data)))
    (if (zero? (cont-data-gc-mask-size cont-data))
	(display " all-live"))
    (let loop ((mask gc-mask) (i 0))
      (if (not (zero? mask))
	  (begin
	    (if (odd? mask)
		(begin
		  (write-char #\space)
		  (display i)))
	    (loop (arithmetic-shift mask -1) (+ 1 i)))))))
		  
(define (bytes->bits l)
  (let loop ((n 0) (l l))
    (if (null? l)
	n
	(loop (+ (arithmetic-shift n 8) (car l))
	      (cdr l)))))

(define-disasm cont-data
  (lambda (opcode template level pc cont-data-arg)
    (print-opcode opcode pc level)
    (display-cont-data (cdr cont-data-arg))
    (display #\))
    level))
;------------------------------
(define (display-shuffle opcode template level pc moves-data)
  (print-opcode opcode pc level)
  (write-char #\space)
  (let ((moves (cdr moves-data)))
    (display (length moves))
    (for-each (lambda (move)
                (write-char #\space)
                (display (list (car move) (cdr move))))
              moves)
    (write-char #\))
    level))    

(define-disasm stack-shuffle! display-shuffle)
(define-disasm big-stack-shuffle! display-shuffle)

;------------------------------
(define (print-opcode opcode pc level)    
  (newline-indent (* level 3))
  (write-pc pc)
  (display " (")
  (write (enumerand->name opcode op)))

; Generic opcode argument printer.

(define (print-opcode-args args)
  (for-each (lambda (arg)
              (display #\space)
              (print-opcode-arg arg))
            args))

; Print out the particular type of argument.  

; This works only for the generic argument types, the special types
; are handled by the instruction disassemblers themselves

(define (print-opcode-arg spec.arg)
  (let ((spec (car spec.arg))
        (arg (cdr spec.arg)))
    (case spec
      ((nargs byte literal two-bytes index small-index)
       (write arg))
      ((offset)
       (write `(=> ,arg)))
      ((offset-)
       (write `(=> ,arg)))
      ((stob)
       (write (enumerand->name arg stob)))
      (else
       (error "unknown arg spec" spec)))))

;----------------
; Utilities.

; Turn OBJ into a template, if possible.

(define (coerce-to-template-or-code obj)
  (cond ((template? obj)
	 obj)
	((closure? obj)
	 (closure-template obj))
	((continuation? obj)
	 (or (continuation-template obj)
	     (continuation-code obj)))
	(else
	 (error "expected a procedure or continuation" obj))))

; Indenting and aligning the program counter.

(define (newline-indent n)
  (newline)
  (do ((i n (- i 1)))
      ((= i 0))
    (display #\space)))

(define (write-pc pc)
  (if (< pc 100) (display " "))
  (if (< pc 10) (display " "))
  (write pc))
