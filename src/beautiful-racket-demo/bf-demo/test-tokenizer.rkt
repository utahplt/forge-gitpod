#lang br
(require brag/support)
(provide tokenize)

(define (tokenize ip)
  (define get-token
    (lexer
     [(char-set "><-.,+[]") lexeme]
     ;; todo: try adding support for line comments
     #;[(:: "#" (:* (complement "\n")) "\n") (token 'comment #:skip? #t)]
     [whitespace (token 'white #:skip? #t)]
     ;; treat other characters as comments
     [(char-range #\nul #\~) (token 'ascii #:skip? #t)]))
  
  (define (next-token) (get-token ip))
  
  next-token)

(module+ test
  (require rackunit)
  (define (test-tokenize str)
    (define ip (open-input-string str))
    (define token-producer (tokenize ip))
    (for/list ([token (in-producer token-producer eof)])
              token))
  
  (check-equal? (test-tokenize "+") (list "+")))
