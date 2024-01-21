#lang racket/base

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; TEMPORAL FORGE READER
;   This is quite similar to the normal Forge reader, except it
;   injects a problem-type option annotation automatically.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require syntax/parse)
(require (only-in forge/lang/reader coerce-ints-to-atoms))
(require forge/lang/alloy-syntax/parser)
(require forge/lang/alloy-syntax/tokenizer)
(require (prefix-in log: forge/logging/2023/main))
(require forge/shared)
(do-time "forge/temporal/lang/reader")

(define (read-syntax path port)
  (define this-lang 'forge/temporal)
  (define-values (logging-on? project email) (log:setup this-lang port path))
  (define compile-time (current-seconds))
  (when logging-on?
    (uncaught-exception-handler (log:error-handler logging-on? compile-time (uncaught-exception-handler)))
    (log:register-run compile-time project this-lang email path))
  (define parse-tree (parse path (make-tokenizer port)))
  (define ints-coerced (coerce-ints-to-atoms parse-tree))
  (define final `((provide (except-out (all-defined-out) ; So other programs can require it
                                       forge:n))

                  (define-namespace-anchor forge:n) ; Used for evaluator
                  (forge:nsa forge:n)

                  (require (prefix-in log: forge/logging/2023/main))
                  (require (only-in racket printf uncaught-exception-handler))

                  (require forge/choose-lang-specific)
                  (require forge/temporal/lang/temporal-lang-specific-checks)
                  
                  (set-checker-hash! temporal-checker-hash)
                  (set-ast-checker-hash! temporal-ast-checker-hash)
                  (set-inst-checker-hash! temporal-inst-checker-hash)
                  (set-check-lang! 'temporal)                  

                  (uncaught-exception-handler (log:error-handler ',logging-on? ',compile-time (uncaught-exception-handler)))
                  ;; Override default exception handler

                  (set-option! 'problem_type 'temporal)
                  ,ints-coerced

                  (module+ execs)
                  (module+ main
                    (require (submod ".." execs)))
                  (log:flush-logs ',compile-time "no-error")))

  (define module-datum `(module forge-mod forge/lang/expander
                          ,@final))
  ; (printf "Ints-coerced: ~a~n" ints-coerced)
  ; (raise "STOP")
  (define result (datum->syntax #f module-datum))
  ;(printf "debug result of expansion: ~a~n" result)
  result)
(provide read-syntax)
