#lang br/quicklang
(require brag/support "grammar.rkt" xml)
(provide (all-from-out br/quicklang) (all-defined-out) xexpr?)

(module+ reader
  (provide read-syntax))

(define-lex-abbrev xml-reserved
  (:or "<" "/>" "</" ">" "<!--" "-->" "=" "\""))

(define tokenize
  (lexer
   [(:+ whitespace) (token 'SP " ")]
   ["&amp;" (token 'AMP "&")]
   ["&lt;" (token 'LT "<")]
   ["&gt;" (token 'GT ">")]
   [xml-reserved lexeme]
   [(:or alphabetic numeric) (token 'ALPHANUMERIC lexeme)]
   [any-char (token 'OTHER lexeme)]))

(define (top . contents) `(root ,@contents))
(define (content . xs) xs)

(define-cases tagged-element
  [(_ id attrs) (list id attrs)]
  [(_ id attrs contents id-end)
   (unless (eq? id id-end)
     (raise-argument-error 'tagged-element "matched tags" (list id id-end)))
   (list* id attrs contents)])

(define (attrs . attr-list) attr-list)
(define (attr id value) (list id value))

(define (string . strs) (string-join strs ""))
(define (identifier . strs)
  (string->symbol (apply string strs)))

(define (read-syntax src ip)
  (define parse-tree (parse (λ () (tokenize ip))))
  (strip-context
   (with-syntax ([PT parse-tree])
     #'(module mel xmlish-demo
         (println PT)
         (displayln (if (xexpr? PT)
                        "YES, it's an X-expression"
                        "NO, it's not an X-expression"))))))