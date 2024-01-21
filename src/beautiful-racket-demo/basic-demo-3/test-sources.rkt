#lang at-exp br
(require br/test rackunit)
 
(check-equal? (run-source "sample.rkt") "one

three
4
")

(check-equal? (run-source "sample-cond.rkt") "1
1
1

")

(check-equal? (run-source "sample-def.rkt") "60
600
3
")

(check-equal? (run-source "sample-exporter.rkt") "1
2
3
")

(check-equal? (run-source "sample-for.rkt") "1
9
1
8
1
7
2
9
2
8
2
7
3
9
3
8
3
7
")

(check-equal? (run-source "sample-gosub.rkt") "first
second
third
fourth
")

(check-equal? (run-source "sample-import.rkt") "53
0
10
")

(check-equal? (run-source "sample-importer.rkt") "#<procedure:div>
20
2
")

(check-equal? (run-source "sample-math.rkt") "1
1
1
1
1
1
1
")

(check-equal? (run-source "sample-shell.rkt") "got shell args: 000\n")

