#lang br/quicklang
(require "main.rkt")
(provide (all-from-out "main.rkt"))

(module+ reader
  (provide read-syntax))

(define (read-syntax path port)
  (define wire-datums
    (for/list ([wire-str (in-lines port)])
      (format-datum '(wire ~a) wire-str)))
  (strip-bindings
   #`(module wires-mod wires-demo/with-promises
       #,@wire-datums)))

(define-macro-cases wire
  [(wire ARG -> WIRE)
   #'(begin
       (define WIRE (delay ARG))
       (module+ main
         (displayln (format "promise ~a: ~a" 'WIRE (force WIRE)))))]
  [(wire OP ARG -> WIRE) #'(wire (OP (force ARG)) -> WIRE)]
  [(wire ARG1 OP ARG2 -> WIRE) #'(wire (OP (force ARG1) (force ARG2)) -> WIRE)]
  [else #'(void)])
(provide wire)
