#lang br/quicklang
(require "bus.rkt" (for-syntax racket/syntax racket/require-transform br/syntax "bus-properties.rkt"))
(provide #%module-begin (all-defined-out))

(define-macro (chip-program CHIPNAME
                            (in-spec (IN-BUS IN-WIDTH ...) ...)
                            (out-spec (OUT-BUS OUT-WIDTH ...) ...)
                            PART ...)
  (with-pattern
      ([CHIP-PREFIX (suffix-id #'CHIPNAME "-")]
       [(IN-BUS-WRITE ...) (suffix-id #'(IN-BUS ...) "-write")]
       [(PREFIX-OUT-BUS ...) (prefix-id #'CHIP-PREFIX #'(OUT-BUS ...))])
    #'(begin
        (provide (prefix-out CHIP-PREFIX (combine-out IN-BUS ... IN-BUS-WRITE ...)))
        (define-input-bus IN-BUS IN-WIDTH ...) ...
        PART ...
        (provide PREFIX-OUT-BUS ...)
        (define-output-bus PREFIX-OUT-BUS OUT-BUS OUT-WIDTH ...) ...)))


(define-macro (part PARTNAME ((BUS-LEFT . BUS-LEFT-ARGS) BUS-RIGHT-EXPR) ...)
  (with-pattern
      ([(PARTNAME-BUS-LEFT ...) (prefix-id #'PARTNAME "-" #'(BUS-LEFT ...))]
       [PARTNAME-MODULE-PATH (format-string "~a.hdl.rkt" #'PARTNAME)])
    #'(begin
        (require (import-chip PARTNAME-MODULE-PATH)
                 ;; need for-syntax to make phase 1 binding available
                 ;; so we can determine during expansion which buses are `input-bus?`
                 ;; because the pin-spec syntax is inherently ambiguous
                 (for-syntax (import-chip PARTNAME-MODULE-PATH))) 
        (handle-buses ((PARTNAME-BUS-LEFT . BUS-LEFT-ARGS) BUS-RIGHT-EXPR) ...))))


(define-syntax import-chip
  (make-require-transformer
   (λ (stx)
     (syntax-case stx ()
       [(_ module-path)
        (expand-import #'module-path)]))))

(require (for-syntax racket/list))
(define-macro (handle-buses BUS-ASSIGNMENTS ...)
  (let-values
      ;; we "pre-evaluate" #'PREFIXED-WIRE so we can set up the program correctly.
      ;; This is not ideal: usually we want evaluate runtime expressions only at runtime.
      ;; But in this case, it controls which identifiers we `define` as output buses
      ;; so there's no way around it. Runtime would be too late.
      ([(in-bus-assignments out-bus-assignments)
        (partition (λ (stx)
                     (syntax-case stx ()
                       [((PREFIXED-WIRE . _) _)
                        (input-bus? (syntax-local-eval #'PREFIXED-WIRE))
                        #'PREFIXED-WIRE]
                       [else #f])) (syntax->list #'(BUS-ASSIGNMENTS ...)))])
    (with-pattern
        ([(((IN-BUS IN-BUS-ARG ...) IN-BUS-VALUE) ...) in-bus-assignments]
         [(IN-BUS-WRITE ...) (suffix-id #'(IN-BUS ...) "-write")]
         [((OUT-BUS-EXPR (NEW-OUT-BUS)) ...) out-bus-assignments])
      #'(begin
          (define-output-bus NEW-OUT-BUS
            (λ ()
              (IN-BUS-WRITE IN-BUS-ARG ... IN-BUS-VALUE) ...
              OUT-BUS-EXPR)) ...))))