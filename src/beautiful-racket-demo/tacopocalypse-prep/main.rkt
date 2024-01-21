#lang br/quicklang
(require brag/support racket/sequence)

(module+ reader
  (provide read-syntax))

(define taco-lexer
  (lexer
   ["(" "#"]
   [")" "$"]
   ["taco" "%"]
   [any-char (taco-lexer input-port)]))
  
(define (read-syntax src port)
  (define toks (for/list ([tok (in-port taco-lexer port)])
                         tok))
  (define parse-tree (string-join toks ""))
  
  ;; print result
  (strip-context
   (with-syntax ([PT parse-tree])
     #'(module untaco racket
         (display PT)))))