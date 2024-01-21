#lang racket
(require "DMux4Way.hdl.rkt")
(require rackunit)

(DMux4Way-in (random 2))
(DMux4Way-sel #b00)
(check-equal? (DMux4Way-a) (DMux4Way-in))
(check-equal? (DMux4Way-b) 0)
(check-equal? (DMux4Way-c) 0)
(check-equal? (DMux4Way-d) 0)

(DMux4Way-sel #b01)
(check-equal? (DMux4Way-a) 0)
(check-equal? (DMux4Way-b) (DMux4Way-in))
(check-equal? (DMux4Way-c) 0)
(check-equal? (DMux4Way-d) 0)

(DMux4Way-sel #b10)
(check-equal? (DMux4Way-a) 0)
(check-equal? (DMux4Way-b) 0)
(check-equal? (DMux4Way-c) (DMux4Way-in))
(check-equal? (DMux4Way-d) 0)

(DMux4Way-sel #b11)
(check-equal? (DMux4Way-a) 0)
(check-equal? (DMux4Way-b) 0)
(check-equal? (DMux4Way-c) 0)
(check-equal? (DMux4Way-d) (DMux4Way-in))
