;; Copyright 2018 Ryan Culpepper
;; 
;; This library is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Lesser General Public License as published
;; by the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; 
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Lesser General Public License for more details.
;; 
;; You should have received a copy of the GNU Lesser General Public License
;; along with this library.  If not, see <http://www.gnu.org/licenses/>.

#lang racket/base
(require "main.rkt"
         "libcrypto.rkt"
         "gcrypt.rkt"
         "nettle.rkt"
         "argon2.rkt"
         "b2.rkt"
         "decaf.rkt"
         "sodium.rkt")
(provide all-factories
         use-all-factories!

         libcrypto-factory
         gcrypt-factory
         nettle-factory
         argon2-factory
         b2-factory
         decaf-factory
         sodium-factory)

(define all-factories
  (list nettle-factory
        libcrypto-factory
        gcrypt-factory
        b2-factory
        argon2-factory
        sodium-factory
        decaf-factory))

(define (use-all-factories!)
  (crypto-factories all-factories))
