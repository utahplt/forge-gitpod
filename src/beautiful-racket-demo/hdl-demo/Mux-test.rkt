#lang racket
(require "Mux.hdl.rkt")
(require rackunit)

(Mux-sel-write 0)

(Mux-a-write 0)
(Mux-b-write 0)
(check-equal? (Mux-out) (Mux-a))

(Mux-a-write 0)
(Mux-b-write 1)
(check-equal? (Mux-out) (Mux-a))

(Mux-a-write 1)
(Mux-b-write 0)
(check-equal? (Mux-out) (Mux-a))

(Mux-a-write 1)
(Mux-b-write 1)
(check-equal? (Mux-out) (Mux-a))

(Mux-sel-write 1)

(Mux-a-write 0)
(Mux-b-write 0)
(check-equal? (Mux-out) (Mux-b))

(Mux-a-write 0)
(Mux-b-write 1)
(check-equal? (Mux-out) (Mux-b))

(Mux-a-write 1)
(Mux-b-write 0)
(check-equal? (Mux-out) (Mux-b))

(Mux-a-write 1)
(Mux-b-write 1)
(check-equal? (Mux-out) (Mux-b))
