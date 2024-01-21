#lang br/quicklang

(define (read-syntax path port)
  (define args (port->lines port))
  (define arg-datums (filter-not void? (format-datums '~a args)))
  (define module-datum `(module stacker-mod funstacker-demo
                          (nestify null ,@arg-datums)))
  (datum->syntax #f module-datum))
(provide read-syntax)

(define-macro (stacker-module-begin HANDLE-ARGS-EXPR)
  #'(#%module-begin
     (display (first HANDLE-ARGS-EXPR))))
(provide (rename-out [stacker-module-begin #%module-begin]))

(require (for-syntax sugar/debug))
(define-macro-cases nestify
  [(nestify ARG0) #'ARG0]
  [(nestify ARG0 ARG1 ARG ...) #'(nestify (h3 ARG0 ARG1) ARG ...)])
(provide nestify)
     
(define (h3 stack arg)
  (cond
    [(number? arg) (cons arg stack)]
    [(or (equal? * arg) (equal? + arg))
     (define op-result (arg (first stack) (second stack)))
     (cons op-result (drop stack 2))]))

(provide + * null)

(module+ test 
  (require rackunit)
  #;(check-equal? (with-output-to-string (λ () (dynamic-require "funstacker-test.rkt" #f))) "36"))