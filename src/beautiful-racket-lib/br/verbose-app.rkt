#lang br
(require (prefix-in br: (only-in br #%app)))
(provide #%app)

(define-macro (#%app APP ARG ...)
  #'(let ()
      (br:#%app displayln (br:#%app format "handling subexpressions in ~a" '(APP ARG ...)))
      (define result (br:#%app APP ARG ...))
      (br:#%app displayln (br:#%app format "evaluating ~a = ~a" '(APP ARG ...) result ))
      result))
