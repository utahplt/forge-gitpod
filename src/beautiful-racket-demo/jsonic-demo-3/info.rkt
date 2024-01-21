#lang info
(define collection "jsonic")
(define version "1.0")
(define scribblings-demo '(("scribblings/jsonic.scrbl")))
(define test-omit-paths '("jsonic-test.rkt"))
(define deps '("base"
               "beautiful-racket-lib"
               "brag"
               "draw-lib"
               "gui-lib"
               "br-parser-tools-lib"
               "rackunit-lib"
               "syntax-color-lib"))
(define build-deps '("scribble-lib"))