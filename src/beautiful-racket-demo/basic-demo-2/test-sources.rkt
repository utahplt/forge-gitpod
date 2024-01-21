#lang at-exp br
(require br/test rackunit)
 
(check-equal? (run-source "sample.rkt") "one

three
4
")
(check-equal? (run-source "sample-var.rkt") "15
75
")
(check-equal? (run-source "sample-math.rkt") "1
1
1
1
1
1
1
")
(check-equal? (run-source "sample-gosub.rkt") "hello
world
third
hi
")
(check-equal? (run-source "sample-for.rkt") "19
18
17
29
28
27
39
38
37
")