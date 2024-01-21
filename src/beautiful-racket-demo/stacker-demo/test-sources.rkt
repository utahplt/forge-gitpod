#lang br
(require br/test rackunit)
 
(check-equal? (run-source "stacker-test.rkt") "36")
