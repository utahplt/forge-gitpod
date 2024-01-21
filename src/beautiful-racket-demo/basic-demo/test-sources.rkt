#lang at-exp br
(require br/test rackunit)
 
(check-equal? (run-source "sample.rkt") "one

three
4
")