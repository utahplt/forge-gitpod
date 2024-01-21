#lang br/quicklang
(require (for-syntax syntax/strip-context))
(provide #%top-interaction #%app #%datum
         (rename-out [basic-module-begin #%module-begin])
         (all-defined-out))

; BASIC implementation details
; http://www.atariarchives.org/basicgames/showpage.php?page=i12

(begin-for-syntax
  (require racket/list)
  (define (gather-unique-ids stx)
    (remove-duplicates (map syntax->datum (filter (λ(s) (syntax-property s 'id)) (syntax-flatten stx))) eq?)))

(define-macro (basic-module-begin (basic-program PROGRAM-LINE ...))
  (with-pattern ([(UNIQUE-ID ...)
                  (map (compose1 syntax-local-introduce (λ(id) (datum->syntax #f id)))
                       (gather-unique-ids #'(PROGRAM-LINE ...)))])
    #'(#%module-begin
       (define UNIQUE-ID 0) ...
       (provide UNIQUE-ID ...)
       (run (sort (cons (line +inf.0 (statement "end"))
                        (list PROGRAM-LINE ...)) #:key $line-number <)))))


(struct exn:line-not-found exn:fail ())
(define (raise-line-not-found-error ln)
  (raise
   (exn:line-not-found
    (format "line number ~a not found in program" ln)
    (current-continuation-marks))))

(struct end-program-signal exn:fail ())
(define (raise-end-program-signal)
  (raise (end-program-signal "" (current-continuation-marks))))

(struct end-line-signal exn:fail ())
(define (raise-end-line-signal)
  (raise (end-line-signal "" (current-continuation-marks))))

(define (run line-list)
  (define lines (list->vector line-list))
  (define (find-index ln)
    (or
     (for/or ([idx (in-range (vector-length lines))])
       (and (= ($line-number (vector-ref lines idx)) ln)
            idx))
     (raise-line-not-found-error ln)))
  (void
   (with-handlers ([end-program-signal? void])
     (for/fold ([program-counter 0])
               ([i (in-naturals)])
       (let* ([line-thunk ($line-thunk (vector-ref lines program-counter))]
              [maybe-line-number (line-thunk)])
         (if (number? maybe-line-number)
             (find-index maybe-line-number)
             (add1 program-counter)))))))

(define current-return-stack (make-parameter empty))

(define (basic:gosub where)
  (let/cc return-k
    (current-return-stack (cons return-k (current-return-stack)))
    (basic:goto where)))

(define current-line (make-parameter #f))
(struct $line (number thunk) #:transparent)
(define-macro (line NUMBER . STATEMENTS)
  #'($line NUMBER (λ ()
                    (current-line NUMBER)
                    (with-handlers ([end-line-signal? (λ _ #f)]
                                    [end-program-signal? raise]
                                    [exn:fail? (λ(exn)
                                                 (displayln (format "in line ~a" NUMBER))
                                                 (raise exn))])
                      . STATEMENTS))))

(define-macro-cases statement
  [(statement ID "=" EXPR) #'(basic:let ID EXPR)]
  [(statement PROC-NAME . ARGS)
   (with-pattern
       ([PROC-ID (prefix-id "basic:" #'PROC-NAME)])
     #'(PROC-ID . ARGS))])

(define-macro-cases basic:let
  [(_ (id-expr ID) EXPR)
   #'(set! ID EXPR)]
  [(_ (id-expr ID DIM-IDX ...) EXPR)
   #'(array-set! ID DIM-IDX ... EXPR)])

(define-macro-cases basic:if
  [(_ COND-EXPR TRUE-EXPR FALSE-EXPR)
   #'(if (true? COND-EXPR)
         TRUE-EXPR
         FALSE-EXPR)]
  [(_ COND-EXPR TRUE-EXPR)
   #'(if (true? COND-EXPR)
         TRUE-EXPR
         (raise-end-line-signal))]) ; special short-circuit rule for one-armed conditional

(define true? (compose1 not zero?))
(define (cond->int cond) (if cond 1 0))
(define (basic:and . args) (cond->int (andmap true? args)))
(define (basic:or . args) (cond->int (ormap true? args)))

(define-macro-cases id-expr
  [(_ ID) #'(cond
              [(procedure? ID) (ID)]
              [(array? ID) (array-ref ID (make-vector (array-rank ID) 0))] ; no subscript => zeroth element
              [else ID])]
  [(_ ID EXPR0 EXPR ...) #'(cond
                             [(procedure? ID) (ID EXPR0 EXPR ...)]
                             [(array? ID) (array-ref ID EXPR0 EXPR ...)]
                             [else (error 'id-expr-confused)])])

(define-macro-cases expr
  [(_ COMP-EXPR) #'COMP-EXPR]
  [(_ COMP-EXPR "and" SUBEXPR) #'(basic:and COMP-EXPR SUBEXPR)]
  [(_ COMP-EXPR "or" SUBEXPR) #'(basic:or COMP-EXPR SUBEXPR)])

(define-macro-cases comp-expr
  [(_ SUM) #'SUM]
  [(_ SUM "=" COMP-EXPR)
   #'(cond->int (equal? SUM COMP-EXPR))] ; special case because `=` is overloaded in basic
  [(_ SUM OP-STR COMP-EXPR)
   (with-pattern
       ([OP (replace-context #'here (prefix-id #'OP-STR))])
     #'(cond->int (OP SUM COMP-EXPR)))])

(define <> (compose1 not equal?))

(define-macro-cases sum
  [(_ SUM) #'SUM]
  [(_ SUM "+" PRODUCT) #'(+ SUM PRODUCT)]
  [(_ SUM "-" PRODUCT) #'(- SUM PRODUCT)])

(define-macro-cases product
  [(_ "-" VALUE) #'(- VALUE)]
  [(_ VALUE) #'VALUE]
  [(_ PRODUCT "*" VALUE) #'(* PRODUCT VALUE)]
  [(_ PRODUCT "/" VALUE) #'(/ PRODUCT VALUE)])

(define-macro-cases power
  [(_ BASE) #'BASE]
  [(_ BASE POWER) #'(expt BASE POWER)])

(define-macro-cases maybe-negative-val
  [(_ "-" ID) #'(- ID)]
  [(_ ID) #'ID])

(define print-list list)

(define (basic:print [args #f])
  (define (println [x ""])
    (define xstr (format "~a" x))
    (displayln xstr)
    (current-print-position 0))
  (define (print x)
    (define xstr (format "~a" x))
    (display xstr)
    (current-print-position (+ (current-print-position) (string-length xstr))))
  
  (match args
    [#f (println)]
    [(list print-list-items ... ";" pl)
     (begin
       (for-each
        (λ(pli)
          (print (if (number? pli)
                     (format "~a " pli)
                     pli)))
        print-list-items)
       (basic:print pl))]
    [(list print-list-items ... ";") (for-each print print-list-items)]
    [(list print-list-items ...)
     (for-each println print-list-items)]))

(define current-print-position (make-parameter 0))
(define (TAB num) (make-string (max 0 (INT (- num (current-print-position)))) #\space))
(define (INT num) (inexact->exact (truncate num)))
(define (SIN num) (sin num))
(define (ABS num) (inexact->exact (abs num)))
(define (RND num) (* (random) num))
(define (EXP num) (exp num))
(define (SQR num) (sqrt num))

(define-macro-cases basic:input
  [(_ (print-list . PL-ITEMS) ID ...)
   #'(begin
       (basic:print (append (print-list . PL-ITEMS) (list ";")))
       (basic:input ID) ...)]
  [(_ ID ...) #'(begin
                  (set! ID (let* ([str (read-line)]
                                  [num (string->number (string-trim str))])
                             (or num str))) ...)])

(define (basic:goto where) where)

(define-macro-cases basic:on
  [(_ TEST-EXPR "goto" OPTION ...)
   #'(basic:goto (list-ref (list OPTION ...) (sub1 TEST-EXPR)))]
  [(_ TEST-EXPR "gosub" OPTION ...)
   #'(basic:gosub (list-ref (list OPTION ...) (sub1 TEST-EXPR)))])


(define (basic:return)
  (define return-k (car (current-return-stack)))
  (current-return-stack (cdr (current-return-stack)))
  (return-k #f))

(define (basic:stop) (basic:end))
(define (basic:end) (raise-end-program-signal))

(require srfi/25)

(define-macro (basic:dim (id-expr ID EXPR ...) ...)
  #'(begin
      (set! ID (make-array (apply shape (append (list 0 (add1 EXPR)) ...)))) ...))

(define current-for-stack (make-parameter empty))

(define (push-for-stack thunk)
  (current-for-stack (cons thunk (current-for-stack))))

(define (pop-for-stack)
  (current-for-stack (cdr (current-for-stack))))

(define (in-closed-interval? x left right)
  (define cmp (if (< left right) <= >=))
  (cmp left x right))

(define-macro-cases basic:for
  [(_ VAR START-VALUE END-VALUE)
   #'(basic:for VAR START-VALUE END-VALUE 1)]
  [(_ VAR START-VALUE END-VALUE STEP-VALUE)
   #'(begin
       (statement (id-expr VAR) "=" START-VALUE) ; initialize the loop counter
       (let/cc return-k ; create a return point
         (push-for-stack (cons 'VAR
                               (λ () ; thunk that increments counter & teleports back to beginning of loop
                                 (define next-val (+ VAR STEP-VALUE))
                                 (if (next-val . in-closed-interval? . START-VALUE END-VALUE)
                                     (begin
                                       (set! VAR next-val)
                                       (return-k #f)) ; return value for subsequent visits to line
                                     (pop-for-stack)))))
         #f))]) ; return value for first visit to line

(define (handle-next [which #f])
  (unless (pair? (current-for-stack)) (error 'next "for-stack is empty"))
  (define for-thunk (cdr (if which
                             (assq which (current-for-stack))
                             (car (current-for-stack)))))
  (for-thunk))

(define-macro (basic:next VAR ...)
  #'(handle-next 'VAR ...))

(define-macro (basic:def DEF-ID LAMBDA-ID EXPR)
  #'(set! DEF-ID (λ (LAMBDA-ID) EXPR)))