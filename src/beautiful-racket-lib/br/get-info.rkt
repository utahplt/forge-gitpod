#lang racket
(require racket/class)
(provide (all-defined-out))

(define (indenter t pos)
  (with-handlers ([exn:fail? (λ (exn) #f)]) ; this function won't work until gui-lib 1.26
    (send t compute-racket-amount-to-indent pos (λ(x)
                                                  (case x
                                                    [("with-pattern"
                                                      "with-shared-id"
                                                      "pattern-case"
                                                      "pattern-case-filter") 'lambda]
                                                    [("define-macro"
                                                      "define-macro-cases"
                                                      "define-cases"
                                                      "while"
                                                      "until") 'define]
                                                    [else #f])))))

(define (br-get-info key default-value proc)
  (define (fallback) (if proc (proc key default-value) default-value))
  (define (try-dynamic-require lib export)
    (with-handlers ([exn:missing-module?
                     (λ (x) (case key
                              [(drracket:indentation) indenter]
                              [else (fallback)]))])
      (dynamic-require lib export)))
  (case key
    [(color-lexer)
     (try-dynamic-require 'syntax-color/scribble-lexer 'scribble-lexer)]
    [(drracket:indentation)
     (try-dynamic-require 'scribble/private/indentation 'determine-spaces)]
    [(drracket:keystrokes)
     (try-dynamic-require 'scribble/private/indentation 'keystrokes)]
    [else (fallback)]))