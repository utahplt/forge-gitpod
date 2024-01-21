#lang br/quicklang
(require "parser.rkt" "tokenizer.rkt" brag/support)

(define (read-syntax path port)
  (define tokens (apply-tokenizer-maker make-tokenizer port)) 
  (strip-bindings
   #`(module basic-parser-mod basic-demo-3/parse-only
       '#,tokens)))
(module+ reader (provide read-syntax))

(define-macro (mb PARSE-TREE)
  #'(#%module-begin
     'PARSE-TREE))
(provide (rename-out [mb #%module-begin]))