#lang br
(require "tokenizer.rkt" "parser.rkt" brag/support)

(define str #<<here
10 rem print
20 end

here
  )

(module+ test
  (require rackunit)
  (check-equal?
   (parse-to-datum (apply-tokenizer-maker make-tokenizer str))
   '(b-program (b-line 10 (b-rem "rem print")) (b-line 20 (b-end)))))