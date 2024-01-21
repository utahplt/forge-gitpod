#lang br/quicklang
(require "grammar.rkt" brag/support racket/stxparam)
(provide #%module-begin (all-defined-out))

(module+ reader
  (provide read-syntax))

(define-lex-abbrev reserved-terms
  (:or "def" "(" ")" ":" "," "return" "<" "if" "else"))
(define-lex-abbrev indent (:: (:+ "\n") (:* " ")))

(define prev-indent 0)
(define pending-dedents 0) 

(define (tokenize ip)
  (cond
    ;; delegate string reading to Racket
    [(eqv? (peek-char ip) #\") (token 'STRING (read ip))]
    ;; we queue dedents because we can only return one dedent at a time
    [(> pending-dedents 0)
     (set! pending-dedents (sub1 pending-dedents))
     (token 'DEDENT)]
    [else
     (define lex
       (lexer
        [(eof)
         (cond
           [(> prev-indent 0) ; if last line is indented, queue dedents
            (set! pending-dedents prev-indent)
            (set! prev-indent 0)
            (tokenize input-port)]
           [else eof])] ; otherwise finish
        [(from/stop-before "#" "\n") (token 'COMMENT #:skip? #t)]
        [indent
         ;; measure current indent and take action based on
         ;; whether it implies an indent, dedent, or neither
         (match-let* ([(list _ spaces) (regexp-match #rx"^\n+( *)$" lexeme)])
           (define this-indent (/ (string-length spaces) 2))
           (begin0
             (cond
               [(> (- this-indent prev-indent) 1) (error 'only-one-indent-please)]
               [(> this-indent prev-indent) (token 'INDENT)]
               [(< this-indent prev-indent)
                (set! pending-dedents (- prev-indent this-indent))
                (tokenize input-port)]
               [(= this-indent prev-indent) (token lexeme #:skip? #t)])
             (set! prev-indent this-indent)))]
        [(:+ whitespace) (token 'WHITESPACE #:skip? #t)]
        [reserved-terms lexeme]
        [(:+ alphabetic) (token 'ID (string->symbol lexeme))]
        [(:+ (char-set "0123456789")) (token 'INT (string->number lexeme))]))
     (lex ip)]))

(define-macro top #'begin)

(define-macro (func-def VAR VARS STMT ...)
  #'(define (VAR . VARS)
      (let/cc return-cc
        (syntax-parameterize ([return (make-rename-transformer #'return-cc)])
          STMT ... (void)))))

(define-macro block #'begin)

(define-macro-cases comparison
  [(_ LEFT "<" RIGHT) #'(< LEFT RIGHT)]
  [(_ OTHER) #'OTHER])

(define-macro func-app #'#%app)

(define-syntax-parameter return (λ (stx) (error 'not-parameterized)))

(provide (rename-out [my-if if]))
(define-macro (my-if COND TBLOCK FBLOCK)
  #'(if COND (let () TBLOCK) (let () FBLOCK)))

(define (read-syntax src ip)
  (define token-thunk (λ () (tokenize ip)))
  (define parse-tree (parse token-thunk))
  (strip-context
   (with-syntax ([PT parse-tree])
     #'(module pyname pythonesque-demo
         PT))))