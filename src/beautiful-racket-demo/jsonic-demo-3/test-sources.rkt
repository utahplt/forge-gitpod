#lang at-exp br
(require br/test rackunit json)

;; don't compare string output directly because
;; hash element isn't converted in a reliable order
(check-equal? (string->jsexpr (run-source "jsonic-test.rkt"))
              '(null
  42
  #t
  ("array" "of" "strings")
  #hasheq((key-1 . null) (key-2 . #f) (key-3 . #hasheq((subkey . 21))))))