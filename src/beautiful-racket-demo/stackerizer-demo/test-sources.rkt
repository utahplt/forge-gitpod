#lang br
(require br/test rackunit)
 
(check-equal? (run-source "stackerizer-test.rkt") "4
8
+
3
*
")
