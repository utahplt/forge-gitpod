#lang racket/base
(require (for-syntax racket/base) br/define)
(provide (all-defined-out))

(define-macro (until COND EXPR ...)
  #'(let loop ()
      (unless COND
        EXPR ...
        (loop))))

(define-macro (while COND EXPR ...)
  #'(let loop ()
      (when COND
        EXPR ...
        (loop))))

(module+ test
  (require rackunit)
  (check-equal? (let ([x 5])
                  (until (zero? x)
                         (set! x (- x 1)))
                  x) 0)
  (check-equal? (let ([x 5])
                  (while (positive? x)
                         (set! x (- x 1)))
                  x) 0))

