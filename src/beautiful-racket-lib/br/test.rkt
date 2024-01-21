#lang racket/base
(require setup/getinfo racket/runtime-path)
(provide message run-source)
(define-runtime-path br-dir "../../beautiful-racket")
(define gi (get-info/full br-dir))
(define message
  (format "You installed beautiful-racket~acorrectly."
          (if gi
              (format " v~a " (gi 'version))
              " ")))

(require racket/port racket/system compiler/find-exe)
(define (run-source path)
  (define racket-path (find-exe))
  (define cmd-string (format "'~a' ~a" racket-path path))
  (with-output-to-string (λ () (system cmd-string))))

(module+ main
  (displayln message))
