#lang br
(provide (all-defined-out))

(define-values (bus bus? bus-get)
  (make-impersonator-property 'bus))

(define-values (output-bus output-bus? output-bus-get)
  (make-impersonator-property 'output-bus))

(define-values (input-bus input-bus? input-bus-get)
  (make-impersonator-property 'input-bus))