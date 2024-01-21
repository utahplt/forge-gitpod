#lang racket
(require "DMux.hdl.rkt")
(require rackunit)

(DMux-in-write 0)
(DMux-sel-write 0)
(check-equal? (DMux-a) 0)
(check-equal? (DMux-b) 0)

(DMux-in-write 0)
(DMux-sel-write 1)
(check-equal? (DMux-a) 0)
(check-equal? (DMux-b) 0)

(DMux-in-write 1)
(DMux-sel-write 0)
(check-equal? (DMux-a) 1)
(check-equal? (DMux-b) 0)

(DMux-in-write 1)
(DMux-sel-write 1)
(check-equal? (DMux-a) 0)
(check-equal? (DMux-b) 1)
