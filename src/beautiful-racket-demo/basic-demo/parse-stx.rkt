#lang br/quicklang
(require "parser.rkt" "tokenizer.rkt")

(define (read-syntax path port)
  (define parse-tree (parse path (make-tokenizer port path)))
  (strip-bindings
   #`(module basic-parser-mod basic-demo/parse-stx
       #'#,parse-tree)))
(module+ reader (provide read-syntax))

(define-macro (parser-only-mb PARSE-STX)
  #'(#%module-begin
     PARSE-STX))
(provide (rename-out [parser-only-mb #%module-begin]))
(provide syntax)