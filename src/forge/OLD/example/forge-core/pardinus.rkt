#lang forge/core

(set-verbosity 10)

(sig A)
(sig AA #:one #:extends A)
(sig B)
(relation r (A B))

(run my-run
     #:preds [(= (join AA r) B)]
     #:backend pardinus)

(define result (forge:get-result my-run))
(display my-run)
(define t (tree:get-value (tree:get-child result 'next)))

(run my-run2
     #:preds [(= (join AA r) B)]
     #:target t
     #:target-contrast
     #:solver TargetSATSolver
     #:backend pardinus)
(display my-run2)

