#lang br
(provide (prefix-out Nand2- (all-defined-out)))
(require "helper.rkt")
(define a (make-input))
(define b (make-input))


(define (out)
  (if (< (+ (a) (b)) 2)
      1
      0))

(module+ test
  (require rackunit)
  (check-equal? (begin (a 0) (b 0) (out)) 1)
  (check-equal? (begin (a 0) (b 1) (out)) 1)
  (check-equal? (begin (a 1) (b 0) (out)) 1)
  (check-equal? (begin (a 1) (b 1) (out)) 0))

#;(define n (make-Nand))
