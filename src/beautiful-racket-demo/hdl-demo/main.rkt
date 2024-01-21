#lang br/quicklang
(require "grammar.rkt"
         brag/support)

(define-lex-abbrev reserved-terms
  (union "CHIP" "IN" "OUT" "PARTS:" (char-set "[]{}(),;=.")))

(define tokenize
  (lexer-srcloc
   [(:or (from/to "/*" "*/") (from/to "//" #\newline))
    (token 'COMMENT lexeme #:skip? #t)]
   [(:or #\tab #\space #\newline) (token 'WS #:skip? #t)]
   [reserved-terms lexeme]
   ["true" (token 'TRUE #t)]
   ["false" (token 'FALSE #f)]
   ;; bugaboo: "10" is ambiguous: number or binary number?
   [(:+ numeric) (token 'NUMBER (string->number lexeme))]
   [(:+ (char-set "01")) (token 'BINARY-NUMBER (string->number lexeme 2))]
   [(:seq alphabetic (:* (:or alphabetic numeric "-"))) (token 'ID (string->symbol lexeme))]))

(module+ reader
  (provide read-syntax))

(define (read-syntax src ip)
  (port-count-lines! ip)
  (strip-context
   (with-syntax ([PT (parse src (λ () (tokenize ip)))])
     #'(module hdl-mod hdl-demo/expander
         PT))))