#lang br
(provide (prefix-out Nand- (all-defined-out)))
(require "bus.rkt")

(define-input-bus a)
(define-input-bus b)

(define (out . etc)
  (if (< (+ (a) (b)) 2)
      1
      0))

(module+ test
  (require rackunit)
  (check-equal? (begin (a-write 0) (b-write 0) (out)) 1)
  (check-equal? (begin (a-write 0) (b-write 1) (out)) 1)
  (check-equal? (begin (a-write 1) (b-write 0) (out)) 1)
  (check-equal? (begin (a-write 1) (b-write 1) (out)) 0))
