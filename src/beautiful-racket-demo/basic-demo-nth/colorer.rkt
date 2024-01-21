#lang br
(require brag/support syntax-color/racket-lexer racket/contract
         basic-demo/tokenizer sugar/coerce)

(define (color-basic ip)
  (define postok (basic-lexer ip))
  (define tok (position-token-token postok))
  (define-values (type val)
    (cond
      [(eof-object? tok) (values eof eof)]
      [(string? tok) (values 'string tok)]
      [else (values (token-struct-type tok)
                    (format "~a" (token-struct-val tok)))]))
  (values val
          (caseq type
                 [(WHITE) 'white-space]
                 [(COMMENT) 'comment]
                 [(NUMBER) 'constant]
                 [(STRING) 'string]
                 [else 'keyword])
          #f
          (position-offset (position-token-start-pos postok))
          (position-offset (position-token-end-pos postok))))
  

#;(provide
   (contract-out
    [color-basic
     (input-port? . -> . (values
                          (or/c string? eof-object?)
                          symbol?
                          (or/c symbol? #f)
                          (or/c exact-positive-integer? #f)
                          (or/c exact-positive-integer? #f)))]))

(define (apply-colorer colorer-proc str)
  (let loop ([p (open-input-string str)][color-recs empty])
    (define color-rec (values->list (colorer-proc p)))
    (if (eof-object? (car color-rec))
        (reverse color-recs)
        (loop p (cons color-rec color-recs)))))

(module+ main
  (define str #<<HERE
10 rem 20
20 x = 42
30 print x
HERE
    )

  (apply-colorer color-basic str))