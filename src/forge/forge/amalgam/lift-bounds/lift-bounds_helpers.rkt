#lang racket/base

(require (only-in racket first second cartesian-product filter-map
                         last take rest remove-duplicates))
(provide transposeTup joinTuple buildClosureOfTupleSet)

; input: tuple - tuple to be flipped
;
; output: flipped tuple
;
; Helper used to flip the currentTupleIfAtomic in the transpose case 
(define (transposeTup tuple)
  (cond 
    [(equal? (length tuple) 2) (list (second tuple) (first tuple))]
    [else (error "transpose tuple for tup ~a isn't arity 2. It has arity ~a"
                 tuple (length tuple))]))

; input: leftTS - left hand side of tuple to be joined
;        rightTS - right hand side of tuple to be joined
;
; output: joined tuple
;
; Helper used to flip the currentTupleIfAtomic in the transpose case 
; list<tuple>, list<tuple> -> list<tuple>
(define (joinTuple leftTS rightTS)
  (define allPairs (cartesian-product leftTS rightTS))
  (filter-map (lambda (combo)
                (define-values (t1 t2) (values (first combo) (second combo)))
                (cond [(equal? (last t1) (first t2))
                       (append (take t1 (- (length t1) 1)) (rest t2))]
                      [else #f]))
              allPairs))

; input: tuples - tuples to be used for closure being built
;
; output: closure that is built
;
; This helper is used for transitive and reflexive transtivie closure.
;   Helper used to build a closure of tuple sets.
(define (buildClosureOfTupleSet tuples)
  (define selfJoin (joinTuple tuples tuples))
  
  ; appending tuples always keep the prior-hop-count tuples in the set
  (define newCandidate (remove-duplicates (append tuples selfJoin)))
  (cond [(equal? (length newCandidate) (length tuples))
         tuples]
        [else
         (buildClosureOfTupleSet newCandidate)]))
