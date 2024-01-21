;; Copyright 2014-2018 Ryan Culpepper
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
(require ffi/unsafe
         asn1
         racket/class
         racket/match
         "../common/common.rkt"
         "../common/pk-common.rkt"
         "../common/catalog.rkt"
         "../common/error.rkt"
         gmp gmp/unsafe
         "ffi.rkt")
(provide (all-defined-out))

(define DSA-Sig-Val (SEQUENCE [r INTEGER] [s INTEGER]))

(define (new-mpz) (mpz))
(define (integer->mpz n) (mpz n))
(define (mpz->integer z) (mpz->number z))
(define (mpz->bin z) (mpz->bytes z #f #f #t))
(define (bin->mpz buf) (bytes->mpz buf #f #t))

;; ============================================================

(define nettle-read-key%
  (class pk-read-key-base%
    (inherit-field factory)
    (super-new (spec 'nettle-read-key))
    ))

;; ============================================================

(define nettle-pk-impl%
  (class pk-impl-base%
    (inherit-field factory)
    (super-new)
    (define/public (get-random-ctx)
      (send factory get-random-ctx))
    ))

;; ============================================================

(define allowed-rsa-keygen
  `((nbits ,exact-positive-integer? "exact-positive-integer?")
    (e     ,exact-positive-integer? "exact-positive-integer?")))

(define nettle-rsa-impl%
  (class nettle-pk-impl%
    (inherit-field spec factory)
    (inherit get-random-ctx)
    (super-new (spec 'rsa))

    (define/override (can-encrypt? pad) (and (memq pad '(#f pkcs1-v1.5)) #t))
    (define/override (can-sign pad) 'depends)
    (define/override (can-sign2? pad dspec)
      (case pad
        [(pkcs1-v1.5 #f) (and (memq dspec '(#f md5 sha1 sha256 sha512)) #t)]
        [(pss) (and pss-ok? (memq dspec '(#f sha256 sha384 sha512)) #t)]
        [else #f]))

    (define/override (generate-key config)
      (define-values (nbits e)
        (check/ref-config '(nbits e) config config:rsa-keygen "RSA key generation"))
      (let ([e (or e 65537)])
        (define pub (new-rsa_public_key))
        (define priv (new-rsa_private_key))
        (mpz_set_si (rsa_public_key_struct-e pub) e)
        (or (nettle_rsa_generate_keypair pub priv (get-random-ctx) nbits 0)
            (crypto-error "RSA key generation failed"))
        (new nettle-rsa-key% (impl this) (pub pub) (priv priv))))

    ;; ----

    (define/override (make-public-key n e)
      (define pub (new-rsa_public_key))
      (mpz_set (rsa_public_key_struct-n pub) (integer->mpz n))
      (mpz_set (rsa_public_key_struct-e pub) (integer->mpz e))
      (unless (nettle_rsa_public_key_prepare pub) (crypto-error "bad public key"))
      (new nettle-rsa-key% (impl this) (pub pub) (priv #f)))

    (define/override (make-private-key n e d p q dp dq qInv)
      (define pub (new-rsa_public_key))
      (define priv (new-rsa_private_key))
      (mpz_set (rsa_public_key_struct-n pub) (integer->mpz n))
      (mpz_set (rsa_public_key_struct-e pub) (integer->mpz e))
      (mpz_set (rsa_private_key_struct-d priv) (integer->mpz d))
      (mpz_set (rsa_private_key_struct-p priv) (integer->mpz p))
      (mpz_set (rsa_private_key_struct-q priv) (integer->mpz q))
      (mpz_set (rsa_private_key_struct-a priv) (integer->mpz dp))
      (mpz_set (rsa_private_key_struct-b priv) (integer->mpz dq))
      (mpz_set (rsa_private_key_struct-c priv) (integer->mpz qInv))
      (unless (nettle_rsa_public_key_prepare pub)
        (crypto-error "bad public key"))
      (unless (nettle_rsa_private_key_prepare priv)
        (crypto-error "bad private key"))
      (new nettle-rsa-key% (impl this) (pub pub) (priv priv)))
    ))

(define nettle-rsa-key%
  (class pk-key-base%
    (init-field pub priv)
    (inherit-field impl)
    (inherit about)
    (super-new)

    (define/override (get-security-bits)
      (rsa-security-bits (* 8 (rsa_public_key_struct-size pub))))

    (define/override (is-private?) (and priv #t))

    (define/override (get-public-key)
      (if priv (new nettle-rsa-key% (impl impl) (pub pub) (priv #f)) this))

    (define/override (-write-private-key fmt)
      (encode-priv-rsa fmt
                       (mpz->integer (rsa_public_key_struct-n pub))
                       (mpz->integer (rsa_public_key_struct-e pub))
                       (mpz->integer (rsa_private_key_struct-d priv))
                       (mpz->integer (rsa_private_key_struct-p priv))
                       (mpz->integer (rsa_private_key_struct-q priv))
                       (mpz->integer (rsa_private_key_struct-a priv))
                       (mpz->integer (rsa_private_key_struct-b priv))
                       (mpz->integer (rsa_private_key_struct-c priv))))

    (define/override (-write-public-key fmt)
      (encode-pub-rsa fmt
                      (mpz->integer (rsa_public_key_struct-n pub))
                      (mpz->integer (rsa_public_key_struct-e pub))))

    (define/override (equal-to-key? other)
      (and (is-a? other nettle-rsa-key%)
           (= (rsa_public_key_struct-size pub)
              (rsa_public_key_struct-size (get-field pub other)))
           (mpz=? (rsa_public_key_struct-n pub)
                  (rsa_public_key_struct-n (get-field pub other)))
           (mpz=? (rsa_public_key_struct-e pub)
                  (rsa_public_key_struct-e (get-field pub other)))))

    (define/override (-sign digest digest-spec pad)
      (define randctx (send impl get-random-ctx))
      (define sigz (new-mpz))
      (define signed-ok?
        (case pad
          [(pkcs1-v1.5 #f)
           (case digest-spec
             [(md5)    (nettle_rsa_md5_sign_digest_tr    pub priv randctx digest sigz)]
             [(sha1)   (nettle_rsa_sha1_sign_digest_tr   pub priv randctx digest sigz)]
             [(sha256) (nettle_rsa_sha256_sign_digest_tr pub priv randctx digest sigz)]
             [(sha512) (nettle_rsa_sha512_sign_digest_tr pub priv randctx digest sigz)]
             [else (nosupport/digest+pad "signing" digest-spec pad)])]
          [(pss)
           (unless pss-ok? (err/bad-signature-pad impl pad))
           (define saltlen (digest-spec-size digest-spec))
           (define salt (crypto-random-bytes saltlen))
           (case digest-spec
             [(sha256) (nettle_rsa_pss_sha256_sign_digest_tr pub priv randctx saltlen salt digest sigz)]
             [(sha384) (nettle_rsa_pss_sha384_sign_digest_tr pub priv randctx saltlen salt digest sigz)]
             [(sha512) (nettle_rsa_pss_sha512_sign_digest_tr pub priv randctx saltlen salt digest sigz)]
             [else (nosupport/digest+pad "signing" digest-spec pad)])]
          [else (err/bad-signature-pad impl pad)]))
      (unless signed-ok? (crypto-error "signing failed\n  key: ~a" (about)))
      (mpz->bin sigz))

    (define/private (nosupport/digest+pad op digest-spec pad)
      (impl-limit-error (string-append "unsupported digest and padding combination for ~a"
                                       "\n  digest: ~s\n  padding: ~s\n  key: ~a")
                        op digest-spec (or pad 'pkcs1-v1.5) (about)))

    (define/override (-verify digest digest-spec pad sig)
      (define sigz (bin->mpz sig))
      (define verified-ok?
        (case pad
          [(pkcs1-v1.5 #f)
           (case digest-spec
             [(md5)    (nettle_rsa_md5_verify_digest    pub digest sigz)]
             [(sha1)   (nettle_rsa_sha1_verify_digest   pub digest sigz)]
             [(sha256) (nettle_rsa_sha256_verify_digest pub digest sigz)]
             [(sha512) (nettle_rsa_sha512_verify_digest pub digest sigz)]
             [else (nosupport/digest+pad "verification" digest-spec pad)])]
          [(pss)
           (unless pss-ok? (err/bad-signature-pad impl pad))
           (define saltlen (digest-spec-size digest-spec))
           (case digest-spec
             [(sha256) (nettle_rsa_pss_sha256_verify_digest pub saltlen digest sigz)]
             [(sha384) (nettle_rsa_pss_sha384_verify_digest pub saltlen digest sigz)]
             [(sha512) (nettle_rsa_pss_sha512_verify_digest pub saltlen digest sigz)]
             [else (nosupport/digest+pad "verification" digest-spec pad)])]
          [else (err/bad-signature-pad impl pad)]))
      verified-ok?)

    (define/override (-encrypt buf pad)
      (case pad
        [(pkcs1-v1.5 #f)
         (define enc-z (new-mpz))
         (or (nettle_rsa_encrypt pub (send impl get-random-ctx) buf enc-z)
             (crypto-error "encryption failed"))
         (mpz->bin enc-z)]
        [else (err/bad-encrypt-pad impl pad)]))

    (define/override (-decrypt buf pad)
      (case pad
        [(pkcs1-v1.5 #f)
         (define randctx (send impl get-random-ctx))
         (define enc-z (bin->mpz buf))
         (define dec-buf (make-bytes (rsa_public_key_struct-size pub)))
         (define dec-size (nettle_rsa_decrypt_tr pub priv randctx dec-buf enc-z))
         (unless dec-size (crypto-error "decryption failed"))
         (shrink-bytes dec-buf dec-size)]
        [else (err/bad-encrypt-pad impl pad)]))
    ))

;; ============================================================
;; DSA

(define (dsa_signature->der sig)
  (asn1->bytes/DER DSA-Sig-Val
    (hasheq 'r (mpz->integer (dsa_signature_struct-r sig))
            's (mpz->integer (dsa_signature_struct-s sig)))))

(define (der->dsa_signature der)
  (match (with-handlers ([exn:fail:asn1? void])
           (bytes->asn1/DER DSA-Sig-Val der))
    [(hash-table ['r (? exact-nonnegative-integer? r)]
                 ['s (? exact-nonnegative-integer? s)])
     (define sig (new-dsa_signature))
     (mpz_set (dsa_signature_struct-r sig) (integer->mpz r))
     (mpz_set (dsa_signature_struct-s sig) (integer->mpz s))
     sig]
    [_ #f]))

;; ----------------------------------------
;; New DSA API (Nettle >= 3.0)

(define nettle-dsa-impl%
  (class nettle-pk-impl%
    (inherit-field spec factory)
    (inherit get-random-ctx)
    (super-new (spec 'dsa))

    (define/override (can-sign pad) (and (memq pad '(#f)) 'ignoredg))
    (define/override (has-params?) #t)

    (define/override (generate-params config)
      (define-values (nbits qbits)
        (check/ref-config '(nbits qbits) config config:dsa-paramgen "DSA parameters generation"))
      (let ([qbits (or qbits 256)])
        (define params (-genparams nbits qbits))
        (new nettle-dsa-params% (impl this) (params params))))

    (define/private (-genparams nbits qbits)
      (define params (new-dsa_params))
      (or (nettle_dsa_generate_params params (get-random-ctx) nbits qbits)
          (crypto-error "failed to generate parameters"))
      params)

    ;; ----

    (define/override (make-params p q g)
      (new nettle-dsa-params% (impl this) (params (-params-dsa p q g))))

    (define/override (make-public-key p q g y)
      (define params (-params-dsa p q g))
      (define pub (integer->mpz y))
      (new nettle-dsa-key% (impl this) (params params) (pub pub) (priv #f)))

    (define/override (make-private-key p q g y x)
      (define params (-params-dsa p q g))
      (define priv (integer->mpz x))
      (define pub
        (cond [y (integer->mpz y)]
              [else ;; must recompute public key, y = g^x mod p
               (define yz (new-mpz))
               (mpz_powm yz
                         (dsa_params_struct-g params)
                         priv
                         (dsa_params_struct-p params))
               yz]))
      (new nettle-dsa-key% (impl this) (params params) (pub pub) (priv priv)))

    (define/private (-params-dsa p q g)
      (define params (new-dsa_params))
      (mpz_set (dsa_params_struct-p params) (integer->mpz p))
      (mpz_set (dsa_params_struct-q params) (integer->mpz q))
      (mpz_set (dsa_params_struct-g params) (integer->mpz g))
      params)
    ))

(define nettle-dsa-params%
  (class pk-params-base%
    (init-field params)
    (inherit-field impl)
    (super-new)

    (define/override (generate-key config)
      (check-config config '() "DSA key generation from parameters")
      (define pub (new-mpz))
      (define priv (new-mpz))
      (nettle_dsa_generate_keypair params pub priv (send impl get-random-ctx))
      (new nettle-dsa-key% (impl impl) (params params) (pub pub) (priv priv)))

    (define/override (-write-params fmt)
      (encode-params-dsa fmt
                         (mpz->integer (dsa_params_struct-p params))
                         (mpz->integer (dsa_params_struct-q params))
                         (mpz->integer (dsa_params_struct-g params))))
    ))

(define nettle-dsa-key%
  (class pk-key-base%
    (init-field params pub priv)
    (inherit-field impl)
    (super-new)

    (define/override (get-security-bits)
      (dsa/dh-security-bits (mpz_sizeinbase (dsa_params_struct-p params) 2)
                            (mpz_sizeinbase (dsa_params_struct-q params) 2)))

    (define/override (is-private?) (and priv #t))

    (define/override (get-public-key)
      (if priv (new nettle-dsa-key% (impl impl) (params params) (pub pub) (priv #f)) this))

    (define/override (get-params)
      (new nettle-dsa-params% (impl impl) (params params)))

    (define/override (-write-key fmt)
      (define p (mpz->integer (dsa_params_struct-p params)))
      (define q (mpz->integer (dsa_params_struct-q params)))
      (define g (mpz->integer (dsa_params_struct-g params)))
      (define y (mpz->integer pub))
      (cond [priv (let ([x (mpz->integer priv)]) (encode-priv-dsa fmt p q g y x))]
            [else (encode-pub-dsa fmt p q g y)]))

    (define/override (equal-to-key? other)
      (and (is-a? other nettle-dsa-key%)
           (mpz=? (dsa_params_struct-p params)
                  (dsa_params_struct-p (get-field params other)))
           (mpz=? (dsa_params_struct-q params)
                  (dsa_params_struct-q (get-field params other)))
           (mpz=? (dsa_params_struct-g params)
                  (dsa_params_struct-g (get-field params other)))
           (mpz=? pub (get-field pub other))))

    (define/override (-sign digest digest-spec pad)
      (define sig (new-dsa_signature))
      (or (nettle_dsa_sign params priv (send impl get-random-ctx) digest sig)
          (crypto-error "signing failed"))
      (dsa_signature->der sig))

    (define/override (-verify digest digest-spec pad sig-der)
      (define sig (der->dsa_signature sig-der))
      (and sig (nettle_dsa_verify params pub digest sig)))
    ))

;; ============================================================
;; EC

;; On rejecting points not on curve as (untrusted) public keys:
;; nettle_ecc_point_set checks the point, indicates whether okay.

(define nettle-ec-impl%
  (class nettle-pk-impl%
    (inherit-field spec factory)
    (inherit get-random-ctx)
    (super-new (spec 'ec))

    (define/override (can-sign pad) (and (memq pad '(#f)) 'ignoredg))
    (define/override (can-key-agree?) #t)
    (define/override (has-params?) #t)

    (define/override (generate-params config)
      (check-config config config:ec-paramgen "EC parameter generation")
      (define curve-name (alias->curve-name (config-ref config 'curve)))
      (define ecc (curve-name->ecc curve-name))
      (unless ecc (err/no-curve (config-ref config 'curve) this))
      (new nettle-ec-params% (impl this) (ecc ecc)))

    (define/public (generate-key-from-params params)
      (define ecc (get-field ecc params))
      (define pub (new-ecc_point ecc))
      (define priv (new-ecc_scalar ecc))
      (nettle_ecdsa_generate_keypair pub priv (get-random-ctx))
      (new nettle-ec-key% (impl this) (pub pub) (priv priv)))

    ;; ---- EC ----

    (define/override (make-params curve-oid)
      (define ecc (curve-oid->ecc curve-oid))
      (and ecc (new nettle-ec-params% (impl this) (ecc ecc))))

    (define/override (make-public-key curve-oid qB)
      (define ecc (curve-oid->ecc curve-oid))
      (define pub (and ecc (make-ec-public-key ecc qB)))
      (and ecc pub (new nettle-ec-key% (impl this) (pub pub) (priv #f))))

    (define/override (make-private-key curve-oid qB d)
      (define ecc (curve-oid->ecc curve-oid))
      (cond [ecc
             (define priv (new-ecc_scalar ecc))
             (unless (nettle_ecc_scalar_set priv (integer->mpz d))
               (crypto-error "invalid private key"))
             (define pub (recompute-ec-q ecc priv))
             (when qB (check-recomputed-qB (ecc_point->bytes ecc pub) qB))
             (new nettle-ec-key% (impl this) (pub pub) (priv priv))]
            [else #f]))

    (define/private (make-ec-public-key ecc qB)
      (cond [(bytes->ec-point qB)
             => (lambda (x+y)
                  (define x (integer->mpz (car x+y)))
                  (define y (integer->mpz (cdr x+y)))
                  (define pub (new-ecc_point ecc))
                  (unless (nettle_ecc_point_set pub x y)
                    (err/off-curve "public key"))
                  pub)]
            [else #f]))

    (define/private (recompute-ec-q ecc priv)
      (define pub (new-ecc_point ecc))
      (nettle_ecc_point_mul_g pub priv)
      pub)
    ))

(define nettle-ec-params%
  (class pk-ec-params%
    (init-field ecc)
    (super-new)

    (define/override (get-curve) (ecc->curve-name ecc))
    (define/override (get-curve-oid) (ecc->curve-oid ecc))
    ))

(define nettle-ec-key%
  (class pk-key-base%
    (init-field pub priv)
    (inherit-field impl)
    (super-new)

    (define/override (is-private?) (and priv #t))

    (define/override (get-public-key)
      (if priv (new nettle-ec-key% (impl impl) (pub pub) (priv #f)) this))

    (define/override (get-params)
      (new nettle-ec-params% (impl impl) (ecc (ecc_point_struct-ecc pub))))

    (define/override (-write-key fmt)
      (define ecc (ecc_point_struct-ecc pub))
      (define curve-oid (ecc->curve-oid ecc))
      (define mlen (ecc->mlen ecc))
      (define qB (ecc_point->bytes ecc pub))
      (cond [priv
             (define dz (new-mpz))
             (nettle_ecc_scalar_get priv dz)
             (encode-priv-ec fmt curve-oid qB (mpz->integer dz))]
            [else
             (encode-pub-ec fmt curve-oid qB)]))

    (define/override (equal-to-key? other)
      (and (is-a? other nettle-ec-key%)
           (ecc_point=? pub (get-field pub other))))

    (define/override (-sign digest digest-spec pad)
      (define randctx (send impl get-random-ctx))
      (define sig (new-dsa_signature))
      (nettle_ecdsa_sign priv randctx digest sig)
      (dsa_signature->der sig))

    (define/override (-verify digest digest-spec pad sig-der)
      (define sig (der->dsa_signature sig-der))
      (and sig (nettle_ecdsa_verify pub digest sig)))

    (define/override (-compute-secret peer-pubkey)
      (define ecc (ecc_scalar_struct-ecc priv))
      (define peer-ecp (get-field pub peer-pubkey))
      (define shared-ecp (new-ecc_point ecc))
      (nettle_ecc_point_mul shared-ecp priv peer-ecp)
      (define x (mpz)) (define y (mpz))
      (nettle_ecc_point_get shared-ecp x y)
      (define ecc-size (ceil/ (nettle_ecc_bit_size ecc) 8))
      (mpz->bytes x ecc-size #f #t))

    (define/override (-compatible-for-key-agree? peer-pubkey)
      (ptr-equal? (ecc_point_struct-ecc pub)
                  (ecc_point_struct-ecc (get-field pub peer-pubkey))))

    (define/override (-convert-for-key-agree bs)
      (define curve-oid (ecc->curve-oid (ecc_point_struct-ecc pub)))
      (send impl make-public-key curve-oid bs))
    ))

(define (ecc_point=? a b)
  (and (ptr-equal? (ecc_point_struct-ecc a) (ecc_point_struct-ecc b))
       (let ([ax (new-mpz)] [ay (new-mpz)]
             [bx (new-mpz)] [by (new-mpz)])
         (nettle_ecc_point_get a ax ay)
         (nettle_ecc_point_get b bx by)
         (and (mpz=? ax bx)
              (mpz=? ay by)))))

(define (ecc_point->bytes ecc pub)
  (let ([xz (new-mpz)] [yz (new-mpz)])
    (nettle_ecc_point_get pub xz yz)
    (ec-point->bytes (ecc->mlen ecc) (mpz->integer xz) (mpz->integer yz))))

(define (ecc_scalar=? a b)
  (and (ptr-equal? (ecc_scalar_struct-ecc a) (ecc_scalar_struct-ecc b))
       (let ([az (new-mpz)] [bz (new-mpz)])
         (nettle_ecc_scalar_get a az)
         (nettle_ecc_scalar_get b bz)
         (mpz=? az bz))))

(define (ecc->curve-name ecc)
  (for/first ([e (in-list nettle-curves)] #:when (ptr-equal? ecc (cadr e)))
    (car e)))

(define (ecc->curve-oid ecc)
  (define curve-name (ecc->curve-name ecc))
  (and curve-name (curve-name->oid curve-name)))

(define (ecc->mlen ecc)
  (ceil/ (nettle_ecc_bit_size ecc) 8))

(define (curve-name->ecc curve-name)
  (cond [(assq curve-name nettle-curves) => cadr] [else #f]))

(define (curve-oid->ecc curve-oid)
  (curve-name->ecc (curve-oid->name curve-oid)))

;; ============================================================
;; Ed25519 and Ed448

(define nettle-eddsa-impl%
  (class nettle-pk-impl%
    (inherit-field spec factory)
    (inherit get-random-ctx)
    (super-new (spec 'eddsa))

    (define/override (can-sign pad) (and (memq pad '(#f)) 'nodigest))
    (define/override (has-params?) #t)

    (define/override (generate-params config)
      (check-config config config:eddsa-keygen "EdDSA parameter generation")
      (curve->params (config-ref config 'curve)))

    (define/public (curve->params curve)
      (or (make-params curve)
          (err/no-curve curve this)))

    (define/public (generate-key-from-params curve)
      (case curve
        [(ed25519) (and ed25519-ok? (generate-ed25519-key))]
        [(ed448) (and ed448-ok? (generate-ed448-key))]))

    (define/private (generate-ed25519-key)
      (define priv (crypto-random-bytes ED25519_KEY_SIZE))
      (define pub (make-bytes ED25519_KEY_SIZE))
      (nettle_ed25519_sha512_public_key pub priv)
      (new nettle-ed25519-key% (impl this) (pub pub) (priv priv)))
    (define/private (generate-ed448-key)
      (define priv (crypto-random-bytes ED448_KEY_SIZE))
      (define pub (make-bytes ED448_KEY_SIZE))
      (nettle_ed448_shake256_public_key pub priv)
      (new nettle-ed448-key% (impl this) (pub pub) (priv priv)))

    ;; ----

    (define/override (make-params curve)
      (and (case curve [(ed25519) ed25519-ok?] [(ed448) ed448-ok?] [else #f])
           (new pk-eddsa-params% (impl this) (curve curve))))

    (define/override (make-public-key curve qB)
      (case curve
        [(ed25519) (and ed25519-ok? (make-ed25519-public-key qB))]
        [(ed448) (and ed448-ok? (make-ed448-public-key qB))]
        [else #f]))

    (define/private (make-ed25519-public-key qB)
      (define pub (make-sized-copy ED25519_KEY_SIZE qB))
      (new nettle-ed25519-key% (impl this) (pub pub) (priv #f)))
    (define/private (make-ed448-public-key qB)
      (define pub (make-sized-copy ED448_KEY_SIZE qB))
      (new nettle-ed448-key% (impl this) (pub pub) (priv #f)))

    (define/override (make-private-key curve _qB dB)
      ;; Note: qB (public key) might be missing, so just recompute
      (case curve
        [(ed25519) (and ed25519-ok? (make-ed25519-private-key dB))]
        [(ed448) (and ed448-ok? (make-ed448-private-key dB))]
        [else #f]))

    (define/private (make-ed25519-private-key dB)
      (define priv (make-sized-copy ED25519_KEY_SIZE dB))
      (define pub (make-bytes ED25519_KEY_SIZE))
      (bytes-copy! priv 0 dB 0 (min (bytes-length dB) ED25519_KEY_SIZE))
      (nettle_ed25519_sha512_public_key pub priv)
      (new nettle-ed25519-key% (impl this) (pub pub) (priv priv)))
    (define/private (make-ed448-private-key dB)
      (define priv (make-sized-copy ED448_KEY_SIZE dB))
      (define pub (make-bytes ED448_KEY_SIZE))
      (bytes-copy! priv 0 dB 0 (min (bytes-length dB) ED448_KEY_SIZE))
      (nettle_ed448_shake256_public_key pub priv)
      (new nettle-ed448-key% (impl this) (pub pub) (priv priv)))
    ))

(define nettle-ed25519-key%
  (class pk-key-base%
    (init-field pub priv)
    (inherit-field impl)
    (super-new)

    (define/override (is-private?) (and priv #t))

    (define/override (get-params)
      (send impl curve->params 'ed25519))

    (define/override (get-public-key)
      (if priv (new nettle-ed25519-key% (impl impl) (pub pub) (priv #f)) this))

    (define/override (-write-public-key fmt)
      (encode-pub-eddsa fmt 'ed25519 pub))
    (define/override (-write-private-key fmt)
      (encode-priv-eddsa fmt 'ed25519 pub priv))

    (define/override (equal-to-key? other)
      (and (is-a? other nettle-ed25519-key%)
           (equal? pub (get-field pub other))))

    (define/override (-sign msg _dspec pad)
      (define sig (make-bytes ED25519_SIGNATURE_SIZE))
      (nettle_ed25519_sha512_sign pub priv (bytes-length msg) msg sig)
      sig)

    (define/override (-verify msg _dspec pad sig)
      (and (= (bytes-length sig) ED25519_SIGNATURE_SIZE)
           (nettle_ed25519_sha512_verify pub (bytes-length msg) msg sig)))
    ))

(define nettle-ed448-key%
  (class pk-key-base%
    (init-field pub priv)
    (inherit-field impl)
    (super-new)

    (define/override (is-private?) (and priv #t))

    (define/override (get-params)
      (send impl curve->params 'ed448))

    (define/override (get-public-key)
      (if priv (new nettle-ed448-key% (impl impl) (pub pub) (priv #f)) this))

    (define/override (-write-public-key fmt)
      (encode-pub-eddsa fmt 'ed448 pub))
    (define/override (-write-private-key fmt)
      (encode-priv-eddsa fmt 'ed448 pub priv))

    (define/override (equal-to-key? other)
      (and (is-a? other nettle-ed448-key%)
           (equal? pub (get-field pub other))))

    (define/override (-sign msg _dspec pad)
      (define sig (make-bytes ED448_SIGNATURE_SIZE))
      (nettle_ed448_shake256_sign pub priv (bytes-length msg) msg sig)
      sig)

    (define/override (-verify msg _dspec pad sig)
      (and (= (bytes-length sig) ED448_SIGNATURE_SIZE)
           (nettle_ed448_shake256_verify pub (bytes-length msg) msg sig)))
    ))

;; ============================================================
;; X25519 and X448

(define nettle-ecx-impl%
  (class nettle-pk-impl%
    (inherit-field spec factory)
    (inherit get-random-ctx)
    (super-new (spec 'ecx))

    (define/override (can-key-agree?) #t)
    (define/override (has-params?) #t)

    (define/override (generate-params config)
      (check-config config config:ecx-keygen "EC/X parameter generation")
      (curve->params (config-ref config 'curve)))

    (define/public (curve->params curve)
      (or (make-params curve)
          (err/no-curve curve this)))

    (define/public (generate-key-from-params curve)
      (case curve
        [(x25519) (and x25519-ok? (generate-x25519-key))]
        [(x448) (and x448-ok? (generate-x448-key))]))

    (define/private (generate-x25519-key)
      (define priv (crypto-random-bytes X25519_KEY_SIZE))
      (define pub (make-bytes X25519_KEY_SIZE))
      (nettle_curve25519_mul_g pub priv)
      (new nettle-x25519-key% (impl this) (priv priv) (pub pub)))
    (define/private (generate-x448-key)
      (define priv (crypto-random-bytes X448_KEY_SIZE))
      (define pub (make-bytes X448_KEY_SIZE))
      (nettle_curve448_mul_g pub priv)
      (new nettle-x448-key% (impl this) (priv priv) (pub pub)))

    ;; ---- ECX ----

    (define/override (make-params curve)
      (and (case curve [(x25519) x25519-ok?] [(x448) x448-ok?] [else #f])
           (new pk-ecx-params% (impl this) (curve curve))))

    (define/override (make-public-key curve qB)
      (case curve
        [(x25519) (and x25519-ok? (make-x25519-public-key qB))]
        [(x448) (and x448-ok? (make-x448-public-key qB))]
        [else #f]))

    (define/private (make-x25519-public-key qB)
      (define pub (make-sized-copy X25519_KEY_SIZE qB))
      (new nettle-x25519-key% (impl this) (pub pub) (priv #f)))
    (define/private (make-x448-public-key qB)
      (define pub (make-sized-copy X448_KEY_SIZE qB))
      (new nettle-x448-key% (impl this) (pub pub) (priv #f)))

    (define/override (make-private-key curve _qB dB)
      ;; Note: qB (public key) might be missing, so just recompute
      (case curve
        [(x25519) (and x25519-ok? (make-x25519-private-key dB))]
        [(x448) (and x448-ok? (make-x448-private-key dB))]
        [else #f]))

    (define/private (make-x25519-private-key dB)
      (define priv (make-sized-copy X25519_KEY_SIZE dB))
      (define pub (make-bytes X25519_KEY_SIZE))
      (nettle_curve25519_mul_g pub priv)
      (new nettle-x25519-key% (impl this) (pub pub) (priv priv)))
    (define/private (make-x448-private-key dB)
      (define priv (make-sized-copy X448_KEY_SIZE dB))
      (define pub (make-bytes X448_KEY_SIZE))
      (nettle_curve448_mul_g pub priv)
      (new nettle-x448-key% (impl this) (pub pub) (priv priv)))
    ))

(define nettle-x25519-key%
  (class pk-key-base%
    (init-field pub priv)
    (inherit-field impl)
    (super-new)

    (define/override (is-private?) (and priv #t))

    (define/override (get-params)
      (send impl curve->params 'x25519))

    (define/override (get-public-key)
      (if priv (new nettle-x25519-key% (impl impl) (pub pub) (priv #f)) this))

    (define/override (-write-public-key fmt)
      (encode-pub-ecx fmt 'x25519 pub))
    (define/override (-write-private-key fmt)
      (encode-priv-ecx fmt 'x25519 pub priv))

    (define/override (equal-to-key? other)
      (and (is-a? other nettle-x25519-key%)
           (equal? pub (get-field pub other))))

    (define/override (-compute-secret peer-pubkey)
      (define peer-pub (get-field pub peer-pubkey))
      (define secret (make-bytes X25519_KEY_SIZE))
      (nettle_curve25519_mul secret priv peer-pub)
      secret)

    (define/override (-compatible-for-key-agree? peer-pubkey)
      (is-a? peer-pubkey nettle-x25519-key%))

    (define/override (-convert-for-key-agree bs)
      (send impl make-public-key 'x25519 bs))
    ))

(define nettle-x448-key%
  (class pk-key-base%
    (init-field pub priv)
    (inherit-field impl)
    (super-new)

    (define/override (is-private?) (and priv #t))

    (define/override (get-params)
      (send impl curve->params 'x448))

    (define/override (get-public-key)
      (if priv (new nettle-x448-key% (impl impl) (pub pub) (priv #f)) this))

    (define/override (-write-public-key fmt)
      (encode-pub-ecx fmt 'x448 pub))
    (define/override (-write-private-key fmt)
      (encode-priv-ecx fmt 'x448 pub priv))

    (define/override (equal-to-key? other)
      (and (is-a? other nettle-x448-key%)
           (equal? pub (get-field pub other))))

    (define/override (-compute-secret peer-pubkey)
      (define peer-pub (get-field pub peer-pubkey))
      (define secret (make-bytes X448_KEY_SIZE))
      (nettle_curve448_mul secret priv peer-pub)
      secret)

    (define/override (-compatible-for-key-agree? peer-pubkey)
      (is-a? peer-pubkey nettle-x448-key%))

    (define/override (-convert-for-key-agree bs)
      (send impl make-public-key 'x448 bs))
    ))
