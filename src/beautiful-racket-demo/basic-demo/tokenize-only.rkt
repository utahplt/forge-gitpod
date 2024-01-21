#lang br/quicklang
(require brag/support "tokenizer.rkt")

(define (read-syntax path port)
  (define tokens (apply-tokenizer make-tokenizer port))
  (strip-bindings
   #`(module basic-tokens-mod basic-demo/tokenize-only
       #,@tokens)))
(module+ reader (provide read-syntax))

(define-macro (tokenize-only-mb TOKEN ...)
  #'(#%module-begin
     (list TOKEN ...)))
(provide (rename-out [tokenize-only-mb #%module-begin]))