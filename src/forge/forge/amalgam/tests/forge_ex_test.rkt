#lang forge/core

(require "forge_ex.rkt")  
(require "../desugar/desugar.rkt")
;----------------------------------------------
; Testing (TODO: move into Racket test module + rackunit)

; udt: run isUndirectedTree for 7 Node
; a run in forge/core doesn't automatically send to Sterling
(run udt
     #:preds [isUndirectedTree]
     #:scope [(Node 7)]) ; run macro does a lot, including binding udt identifier
;(display udt) ; this, if run, would send to Sterling

(define edgeTuple1 '(Node0 Node1))
(define edgeTuple2 '(Node1 Node2))

;(printf "tup2Expr test ~n")
;(tup2Expr edgeTuple1 udt) ; udt is in scope, because the name is def'd in the forge module

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define f-symmetric (= edges (~ edges)))
(define f-irreflexive (no (& edges iden)))
(define f-some-reaches-all (some ([x Node]) (all ([y Node]) (in y (join x (^ edges))))))

; Removed; function no longer exists
;(desugar-formula f-symmetric '() udt true)




