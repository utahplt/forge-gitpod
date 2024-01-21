#lang racket

(read-accept-reader #t)
(call-with-input-file "bf-hash.rkt" read)

(syntax->datum (call-with-input-file "bf-hash.rkt" (curry read-syntax #f)))