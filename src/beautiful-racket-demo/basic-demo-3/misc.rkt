#lang br
(require "struct.rkt" "expr.rkt")
(provide b-rem b-print b-let b-input b-import b-export b-repl)

(define (b-rem val) (void))

(define (b-print . vals)
  (displayln (string-append* (map ~a vals))))

(define-macro (b-let ID VAL) #'(set! ID VAL))

(define-macro (b-input ID)
  #'(b-let ID (let* ([str (read-line)]
                     [num (string->number (string-trim str))])
                (or num str))))

(define-macro (b-import NAME) #'(void))

(define-macro (b-export NAME) #'(void))

(define-macro (b-repl . ALL-INPUTS)
  (with-pattern
      ([INPUTS (pattern-case-filter #'ALL-INPUTS
                 [(b-print . PRINT-ARGS)
                  #'(b-print . PRINT-ARGS)]
                 [(b-expr . EXPR-ARGS)
                  #'(b-print (b-expr . EXPR-ARGS))]
                 [(b-let ID VAL)
                  #'(define ID VAL)]
                 [(b-def FUNC-ID VAR-ID ... EXPR)
                  #'(define (FUNC-ID VAR-ID ...) EXPR)]
                 [ANYTHING-ELSE
                  #'(error 'invalid-repl-input)])])
    #'(begin . INPUTS)))