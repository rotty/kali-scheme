
(define (sender)
  (values 1 2 3 4))

(define (receiver a b c d)
  (+ a (- b (* c d))))

(define (test)
  (call-with-values sender receiver))
