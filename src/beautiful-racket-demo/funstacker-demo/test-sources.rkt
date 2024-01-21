#lang br
(require br/test rackunit)
 
(check-equal? (run-source "funstacker-test.rkt") "36")
