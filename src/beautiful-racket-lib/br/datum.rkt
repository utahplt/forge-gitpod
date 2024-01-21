#lang racket/base
(provide format-datum format-datums datum?)

(define (blank? str)
  (for/and ([c (in-string str)])
    (char-blank? c)))

;; read "foo bar" the same way as "(foo bar)" 
;; otherwise "bar" is dropped, which is too astonishing
(define (string->datum str)
  (unless (blank? str)
    (let ([result (read (open-input-string (format "(~a)" str)))])
      (if (= (length result) 1)
          (car result)
          result))))

(define (datum? x) (or (list? x) (symbol? x)))

(define (format-datum datum-template . args)
  (unless (datum? datum-template)
    (raise-argument-error 'format-datums "datum?" datum-template))
  (string->datum (apply format (format "~a" datum-template)
                        (map (λ (arg) (if (syntax? arg)
                                          (syntax->datum arg)
                                          arg)) args))))

(define (format-datums datum-template . argss)
  (unless (datum? datum-template)
    (raise-argument-error 'format-datums "datum?" datum-template))
  (apply map (λ args (apply format-datum datum-template args)) argss))

(module+ test
  (require rackunit syntax/datum)
  (check-equal? (string->datum "foo") 'foo)
  (check-equal? (string->datum "(foo bar)") '(foo bar))
  (check-equal? (string->datum "foo bar") '(foo bar))
  (check-equal? (string->datum "42") 42)
  (check-equal? (format-datum '(~a-bar-~a) "foo" "zam") '(foo-bar-zam))
  (check-equal? (format-datum '(~a-bar-~a) #'foo #'zam) '(foo-bar-zam))
  (check-equal? (format-datum (datum (~a-bar-~a)) "foo" "zam") '(foo-bar-zam))
  (check-equal? (format-datum '~a "foo") 'foo)
  (check-equal? (format-datum '~a "foo") 'foo)
  (check-equal? (format-datum '~a "") (void))
  (check-equal? (format-datum '~a "   ") (void))
  (check-equal? (format-datums '(put ~a) '("foo" "zam")) '((put foo) (put zam))))
