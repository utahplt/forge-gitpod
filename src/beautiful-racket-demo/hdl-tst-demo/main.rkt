#lang br
(require "grammar.rkt" brag/support)

(module+ reader
  (provide read-syntax))

(define tokenize
  (lexer-srcloc
   [(:or (from/to "/*" "*/")
         (from/to "//" #\newline)) (token 'COMMENT lexeme #:skip? #t)]
   [whitespace (token lexeme #:skip? #t)]
   [(:or "load" "output-list" "output-file" "compare-to" "set" "eval" "output" "," ";") lexeme]
   [(:seq "%" (:+ alphabetic numeric ".")) (token 'FORMAT-STRING lexeme)]
   [(:+ numeric) (token 'VAL (string->number lexeme))]
   [(:+ alphabetic numeric "-" ".") (token 'ID lexeme)]))

(define (read-syntax src ip)
  (port-count-lines! ip)
  (strip-context
   (with-syntax ([PT (parse src (λ () (tokenize ip)))])
     #'(module hdl-mod hdl-tst-demo/expander
         PT))))
