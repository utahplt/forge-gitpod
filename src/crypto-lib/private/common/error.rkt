;; Copyright 2012-2018 Ryan Culpepper
;; Copyright 2007-2009 Dimitris Vyzovitis <vyzo at media.mit.edu>
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
(require racket/list
         racket/class)
(provide (all-from-out (submod "." logger))
         crypto-entry-point
         with-crypto-entry
         crypto-who
         crypto-error
         internal-error
         impl-limit-error

         check-bytes-length
         err/no-impl
         err/bad-signature-pad
         err/bad-encrypt-pad
         err/missing-digest
         err/crypt-failed
         err/auth-decrypt-failed
         err/no-curve
         err/off-curve)

(module logger racket/base
  (provide (all-defined-out))
  (define-logger crypto))
(require (submod "." logger))

;; Error conventions:
;; - use (about) for reporting context
;; - order: EXPECTED, GIVEN, CONTEXT

(define crypto-entry-point (gensym))

(define-syntax-rule (with-crypto-entry who body ...)
  (with-continuation-mark crypto-entry-point who (let () body ...)))

(define (crypto-who)
  (define entry-points
    (continuation-mark-set->list (current-continuation-marks) crypto-entry-point))
  (if (pair? entry-points) (last entry-points) 'crypto))

(define (crypto-error fmt . args)
  (apply error (crypto-who) fmt args))

(define (internal-error fmt . args)
  (apply error (crypto-who) (string-append "internal error: " fmt) args))

(define (impl-limit-error fmt . args)
  (apply error (crypto-who) (string-append "implementation limitation: " fmt) args))

;; ----

(define (check-bytes-length what wantlen buf [obj #f] #:fmt [fmt ""] #:args [args null])
  (unless (= (bytes-length buf) wantlen)
    (crypto-error "wrong size for ~a\n  expected: ~s bytes\n  given: ~s bytes~a~a"
                  what wantlen (bytes-length buf)
                  (apply format fmt (if (list? args) args (list args)))
                  (if obj (format "\n  for: ~a" (send obj about)) ""))))

(define (err/no-impl [obj #f])
  (internal-error "unimplemented~a" (if obj (format "\n  in: ~a" (send obj about)) "")))

(define (err/bad-*-pad kind impl pad)
  (define factory (send impl get-factory))
  (crypto-error "~a padding not supported\n  padding: ~e\n  key: ~a key"
                kind pad (send impl -about)))
(define (err/bad-signature-pad impl pad)
  (err/bad-*-pad "signature" impl pad))
(define (err/bad-encrypt-pad impl pad)
  (err/bad-*-pad "encryption" impl pad))

(define (err/missing-digest spec)
  (crypto-error "could not get digest implementation\n  digest: ~e" spec))

(define (err/crypt-failed enc? auth?)
  (crypto-error "~a~a failed"
                (if auth? "authenticated " "")
                (if enc? "encryption" "decryption")))

(define (err/auth-decrypt-failed)
  (err/crypt-failed #f #t))

(define (err/no-curve curve [obj #f])
  (crypto-error "given named curve not supported\n  curve: ~e~a"
                curve
                (if obj (format "\n  for: ~a" (send obj about)) "")))

(define (err/off-curve what)
  (crypto-error "invalid ~a (point not on curve)" what))
