;; Copyright 2017-2019 Ryan Culpepper
;; SPDX-License-Identifier: Apache-2.0 OR MIT

#lang racket/base
(require racket/contract/base
         "private/bytes.rkt")

(provide (contract-out

          [read-bytes*
           (->* [exact-nonnegative-integer?]
                [input-port? #:who symbol?]
                bytes?)]

          [write-null-terminated-bytes
           (->* [bytes?]
                [output-port? exact-nonnegative-integer? exact-nonnegative-integer? #:who symbol?]
                void?)]
          [read-null-terminated-bytes
           (->* [] [input-port? #:limit (or/c exact-nonnegative-integer? +inf.0) #:who symbol?]
                bytes?)]))
