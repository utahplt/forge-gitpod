#lang br/quicklang

(module+ reader
  (provide read-syntax))

(define (tokenize ip)
  (for/list ([tok (in-port read ip)])
    tok))

(define (parse tok)
  (if (list? tok)
      (map parse tok)
      'taco))

(define (read-syntax src ip)
  (define toks (tokenize ip))
  (define parse-tree (parse toks))
  (with-syntax ([(PT ...) parse-tree])
    #'(module tacofied racket
        'PT ...)))