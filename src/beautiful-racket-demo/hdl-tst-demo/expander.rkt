#lang br/quicklang
(require (for-syntax racket/string) rackunit racket/file)
(provide #%module-begin (all-defined-out))

(define (print-cell val fmt)
  (match-define (list _ radix-letter number-strings) (regexp-match #px"^%(.)(.*)$" fmt)) ; like %B1.16.1
  (match-define (list left-margin width right-margin) (map string->number (string-split number-strings ".")))
  (cond
    [(number? val)
     (define radix (case radix-letter
                     [("B") 2]))
     (string-append (make-string left-margin #\space)
                    (~r val #:min-width width #:pad-string "0" #:base radix)
                    (make-string right-margin #\space))]
    [(string? val) (~a val #:min-width (+ left-margin width right-margin) #:pad-string " " #:align 'center)]
    [else (error 'unknown-value)]))


(define (print-line output-filename cells)
  (with-output-to-file output-filename
    (λ () (printf (format "~a\n" (string-join cells "|" #:before-first "|" #:after-last "|"))))
    #:mode 'text #:exists 'append))

(module+ test
  (require rackunit)
  (define a 123)
  (check-equal? (print-cell a "%B1.16.1") " 0000000001111011 ")
  (check-equal? (print-cell "out" "%B1.16.1") "       out        ")
  (check-equal? (print-cell "out" "%B3.1.3") "  out  ")
  (check-equal? (print-cell "in" "%B3.1.3") "  in   "))


(define-for-syntax chip-prefix #f)


(define-macro (program EXPR ...)
  (with-shared-id (compare-files)
    #'(begin
        EXPR ...
        (compare-files))))


(define-macro (load-expr CHIPFILE-STRING)
  (set! chip-prefix (string-replace (syntax->datum #'CHIPFILE-STRING) ".hdl" ""))
  (with-pattern ([CHIPFILE.RKT (format-string "~a.rkt" #'CHIPFILE-STRING)])
    #'(require CHIPFILE.RKT)))


(define-macro (output-file-expr OUTPUT-FILE-STRING)
  (with-shared-id (output-file output-filename)
    #'(begin
        (define output-filename OUTPUT-FILE-STRING)
        (with-output-to-file output-filename (λ () (printf ""))
          #:mode 'text #:exists 'replace))))


(define-macro (compare-to-expr COMPARE-FILE-STRING)
  (with-shared-id (compare-files output-filename)
    #'(define (compare-files)
        (check-equal? (file->lines output-filename) (file->lines COMPARE-FILE-STRING)))))


(define-macro (output-list-expr (COL-NAME FORMAT-SPEC) ...)
  (with-shared-id (eval-result eval-chip output output-filename)
    (with-pattern ([(COL-ID ...) (suffix-ids #'(COL-NAME ...) "")]
                   [(CHIP-COL-ID ...) (prefix-ids chip-prefix "-" #'(COL-NAME ...))])
      #'(begin
          (define (output COL-ID ...)
            (print-line output-filename (map print-cell (list COL-ID ...) (list FORMAT-SPEC ...))))
          (define eval-result #f)
          (define (eval-chip) (list (CHIP-COL-ID) ...))
          (output COL-NAME ...)))))


(define-macro (set-expr IN-BUS IN-VAL)
  (with-pattern
      ([CHIP-IN-BUS-ID-WRITE (prefix-id chip-prefix "-" (suffix-id #'IN-BUS "-write"))])
    #'(CHIP-IN-BUS-ID-WRITE IN-VAL)))


(define-macro (eval-expr)
  (with-shared-id (eval-result eval-chip)
    #'(set! eval-result (eval-chip))))


(define-macro (output-expr)
  (with-shared-id (output eval-result)
    #'(apply output eval-result)))
