#lang mischief

(require
  ;; Base language:
  mischief
  (for-template
    (only-in racket
      define-syntax
      define-syntaxes))
  ;; Debugging versions:
  debug
  (for-template debug/syntax)
  ;; Export macro:
  debug/provide)

(provide
  (debug-out
    (all-from-out mischief)
    (for-template
      define-syntax
      define-syntaxes)))
