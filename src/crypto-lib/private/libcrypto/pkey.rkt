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
(require ffi/unsafe
         racket/class
         racket/match
         asn1
         "../common/interfaces.rkt"
         "../common/catalog.rkt"
         "../common/common.rkt"
         "../common/pk-common.rkt"
         "../common/asn1.rkt"
         "../common/error.rkt"
         "ffi.rkt"
         "digest.rkt")
(provide (all-defined-out))

;; My attempts to use EVP_PKEY_paramgen and EVP_PKEY_keygen have
;; caused intermittent crashes (likely memory corruption), so drop
;; down to the lower-level key and parameter generation functions.

;; TODO: check params (eg safe primes) on generate-params, read-params

;; ============================================================

(define libcrypto-read-key%
  (class* impl-base% (pk-read-key<%>)
    (inherit-field factory)
    (super-new (spec 'libcrypto-read-key))

    (define/public (read-key sk fmt)
      (define (check-bytes)
        (unless (bytes? sk)
          (crypto-error "bad value for key format\n  expected: ~s\n  got: ~e\n  format: ~e"
                        'bytes? sk fmt)))
      (case fmt
        [(SubjectPublicKeyInfo)
         (check-bytes)
         (evp->key (d2i_PUBKEY sk (bytes-length sk)) #f)]
        [(PrivateKeyInfo)
         (check-bytes)
         (define p8 (d2i_PKCS8_PRIV_KEY_INFO sk (bytes-length sk)))
         (evp->key (and p8 (EVP_PKCS82PKEY p8)) #t)]
        [(RSAPrivateKey)
         (check-bytes)
         (evp->key (d2i_PrivateKey EVP_PKEY_RSA sk (bytes-length sk)) #t)]
        [(DSAPrivateKey)
         (check-bytes)
         (evp->key (d2i_PrivateKey EVP_PKEY_DSA sk (bytes-length sk)) #t)]
        [(ECPrivateKey)
         (check-bytes)
         (evp->key (read-private-ec-key sk) #t)]
        [else
         (cond [(private-key-format? fmt)
                (define txkey (translate-key sk fmt 'PrivateKeyInfo))
                (read-key txkey 'PrivateKeyInfo)]
               [(public-key-format? fmt)
                (define txkey (translate-key sk fmt 'SubjectPublicKeyInfo))
                (and txkey (read-key txkey 'SubjectPublicKeyInfo))]
               [else #f])]))

    (define/private (evp->key evp private?)
      (define impl (and evp (evp->impl evp)))
      (and evp impl
           (if private?
               (send impl make-private-key evp)
               (send impl make-public-key evp))))

    (define/private (evp->impl evp)
      (define type (EVP->type evp))
      (define spec
        (cond [(assoc type type=>spec) => cdr]
              [else #f]))
      (and spec (send factory get-pk spec)))

    (define/private (read-dh-key params-buf pub-buf priv-buf)
      (define dh (d2i_DHparams params-buf (bytes-length params-buf)))
      ;; FIXME: DH check
      (when (or (DH_st_prefix-pubkey dh) (DH_st_prefix-privkey dh))
        (internal-error "keys found in DH parameters object"))
      (let ([pubkey (BN_bin2bn pub-buf)])
        (set-DH_st_prefix-pubkey! dh pubkey)
        (BN-no-gc pubkey))
      (when priv-buf
        (let ([privkey (BN_bin2bn priv-buf)])
          (set-DH_st_prefix-privkey! dh privkey)
          (BN-no-gc privkey)))
      (define evp (EVP_PKEY_new))
      (EVP_PKEY_set1_DH evp dh)
      (DH_free dh)
      evp)

    (define/private (read-private-ec-key buf)
      (define ec (d2i_ECPrivateKey buf (bytes-length buf)))
      (define evp (EVP_PKEY_new))
      (EVP_PKEY_set1_EC_KEY evp ec)
      (EC_KEY_free ec)
      evp)

    (define/public (read-params buf fmt)
      (define (evp->params evp)
        (define impl (and evp (evp->impl evp)))
        (and impl (send impl make-params evp)))
      (case fmt
        [(AlgorithmIdentifier)
         (match (ensure-keys (bytes->asn1/DER AlgorithmIdentifier/DER buf) '(parameters))
           [(hash-table ['algorithm alg-oid] ['parameters parameters])
            (cond [(equal? alg-oid id-dsa)
                   (read-params parameters 'DSAParameters)] ;; Dss-Parms
                  [(equal? alg-oid dhKeyAgreement)
                   (read-params parameters 'DHParameter)] ;; DHParameter
                  [(equal? alg-oid id-ecPublicKey)
                   (read-params parameters 'EcpkParameters)] ;; PcpkParameters
                  [(equal? alg-oid id-Ed25519)
                   (define impl (send factory get-pk 'eddsa))
                   (and impl (send impl curve->params 'ed25519))]
                  [(equal? alg-oid id-Ed448)
                   (define impl (send factory get-pk 'eddsa))
                   (and impl (send impl curve->params 'ed448))]
                  [(equal? alg-oid id-X25519)
                   (define impl (send factory get-pk 'ecx))
                   (and impl (send impl curve->params 'x25519))]
                  [(equal? alg-oid id-X448)
                   (define impl (send factory get-pk 'ecx))
                   (and impl (send impl curve->params 'x25519))]
                  [else #f])]
           [_ #f])]
        [(DSAParameters)
         (define dsa (d2i_DSAparams buf (bytes-length buf)))
         (define evp (EVP_PKEY_new))
         (EVP_PKEY_set1_DSA evp dsa)
         (DSA_free dsa)
         (evp->params evp)]
        [(DHParameter) ;; PKCS#3 ... not DomainParameters!
         (define dh (d2i_DHparams buf (bytes-length buf)))
         ;; FIXME: DH_check
         (define evp (EVP_PKEY_new))
         (EVP_PKEY_set1_DH evp dh)
         (DH_free dh)
         (evp->params evp)]
        [(EcpkParameters)
         (define group (d2i_ECPKParameters buf (bytes-length buf)))
         ;; FIXME: check?
         (define ec (EC_KEY_new))
         (EC_KEY_set_group ec group)
         (EC_GROUP_free group)
         (define evp (EVP_PKEY_new))
         (EVP_PKEY_set1_EC_KEY evp ec)
         (EC_KEY_free ec)
         (evp->params evp)]
        [(rkt-params)
         (define p (translate-params buf 'rkt-params 'AlgorithmIdentifier))
         (and p (read-params p 'AlgorithmIdentifier))]
        [else #f]))
    ))

;; ============================================================

(define libcrypto-pk-impl%
  (class pk-impl-base%
    (inherit-field factory)
    (super-new)
    (define/public (-known-digest? dspec)
      (or (not dspec) (and (send factory get-digest dspec) #t)))

    (define/override (make-private-key evp)
      (new (get-key-class) (impl this) (evp evp) (private? #t)))
    (define/override (make-public-key evp)
      (new (get-key-class) (impl this) (evp evp) (private? #f)))
    (define/override (make-params evp)
      (new (get-params-class) (impl this) (pevp evp)))
    (abstract get-key-class)
    (define/public (get-params-class) (internal-error "params not supported"))
    ))

;; ------------------------------------------------------------

(define libcrypto-pk-params%
  (class pk-params-base%
    (init-field pevp)
    (super-new)

    (define/override (-write-params fmt)
      (case fmt
        [(rkt-params)
         (define ai (-write-params 'AlgorithmIdentifier))
         (and ai (translate-params ai 'AlgorithmIdentifier 'rkt-params))]
        [else (super -write-params fmt)]))
    ))

;; ------------------------------------------------------------

(define libcrypto-pk-key%
  (class pk-key-base%
    (init-field evp private?)
    (inherit-field impl)
    (super-new)

    (define/override (get-security-bits)
      (or (EVP_PKEY_security_bits evp)
          (super get-security-bits)))

    (define/override (is-private?) private?)

    (define/override (get-public-key)
      (define pub (i2d i2d_PUBKEY evp))
      (define pub-evp (d2i_PUBKEY pub (bytes-length pub)))
      (send impl make-public-key pub-evp))

    (define/override (get-params)
      ;; Note: EVP_PKEY_copy_parameters doesn't work! (Probably used
      ;; to copy params from cert to key).  We treat keys as read-only
      ;; once created, so safe to share evp.
      (send impl make-params evp))

    (define/override (-write-key fmt)
      (case fmt
        [(SubjectPublicKeyInfo)
         (i2d i2d_PUBKEY evp)]
        [(PrivateKeyInfo OneAsymmetricKey)
         (cond [private?
                (define p8 (EVP_PKEY2PKCS8 evp))
                (i2d i2d_PKCS8_PRIV_KEY_INFO p8)]
               [else #f])]
        [(rkt-public)
         (define pub-spki (-write-key 'SubjectPublicKeyInfo))
         (translate-key pub-spki 'SubjectPublicKeyInfo 'rkt-public)]
        [(rkt-private)
         (define pub-spki (-write-key 'SubjectPublicKeyInfo))
         (define priv-pki (-write-key 'PrivateKeyInfo))
         (merge-rkt-private-key (translate-key priv-pki 'PrivateKeyInfo 'rkt-private)
                                (translate-key pub-spki 'SubjectPublicKeyInfo 'rkt-public))]
        [else (super -write-key fmt)]))

    (define/override (equal-to-key? other)
      (and (is-a? other libcrypto-pk-key%)
           (EVP_PKEY_cmp evp (get-field evp other))))

    (define/override (-sign digest dspec pad)
      (define ctx (EVP_PKEY_CTX_new evp))
      (EVP_PKEY_sign_init ctx)
      (-set-sign-options ctx #t pad dspec)
      (define siglen (EVP_PKEY_sign ctx #f 0 digest (bytes-length digest)))
      (define sigbuf (make-bytes siglen))
      (define siglen2 (EVP_PKEY_sign ctx sigbuf siglen digest (bytes-length digest)))
      (EVP_PKEY_CTX_free ctx)
      (shrink-bytes sigbuf siglen2))

    (define/override (-verify digest dspec pad sig)
      (define ctx (EVP_PKEY_CTX_new evp))
      (EVP_PKEY_verify_init ctx)
      (-set-sign-options ctx #f pad dspec)
      (begin0 (EVP_PKEY_verify ctx sig (bytes-length sig) digest (bytes-length digest))
        (EVP_PKEY_CTX_free ctx)))

    (define/public (-set-sign-options ctx sign? pad dspec)
      ;; Default: require pad=#f, ignore digest
      (case pad
        [(#f) (void)]
        [else (err/bad-signature-pad this pad)]))

    (define/override (-encrypt buf pad)
      (*crypt buf pad EVP_PKEY_encrypt_init EVP_PKEY_encrypt))

    (define/override (-decrypt buf pad)
      (*crypt buf pad EVP_PKEY_decrypt_init EVP_PKEY_decrypt))

    (define/private (*crypt buf pad EVP_*crypt_init EVP_*crypt)
      (define ctx (EVP_PKEY_CTX_new evp))
      (EVP_*crypt_init ctx)
      (-set-encrypt-padding ctx pad)
      (define outlen (EVP_*crypt ctx #f 0 buf (bytes-length buf)))
      (define outbuf (make-bytes outlen))
      (define outlen2 (EVP_*crypt ctx outbuf outlen buf (bytes-length buf)))
      (EVP_PKEY_CTX_free ctx)
      (shrink-bytes outbuf outlen2))

    (define/public (-set-encrypt-padding ctx pad)
      (case pad
        [(#f) (void)]
        [else (err/bad-encrypt-pad this pad)]))

    (define/override (-compute-secret peer-pubkey0)
      (define peer-pubkey
        (cond [(and (is-a? peer-pubkey0 libcrypto-pk-key%)
                    (eq? (send peer-pubkey0 get-impl) impl))
               (get-field evp peer-pubkey0)]
              [else (internal-error "bad peer public key")]))
      (define ctx (EVP_PKEY_CTX_new evp))
      (EVP_PKEY_derive_init ctx)
      (EVP_PKEY_derive_set_peer ctx peer-pubkey)
      (define outlen (EVP_PKEY_derive ctx #f 0))
      (define buf (make-bytes outlen))
      (define outlen2 (EVP_PKEY_derive ctx buf (bytes-length buf)))
      (shrink-bytes buf outlen2))

    (define/override (-compatible-for-key-agree? peer-pubkey)
      (EVP_PKEY_cmp_parameters evp (get-field evp peer-pubkey)))
    ))

;; ============================================================

(define libcrypto-rsa-impl%
  (class libcrypto-pk-impl%
    (inherit -known-digest?)
    (super-new (spec 'rsa))

    (define/override (get-key-class) libcrypto-rsa-key%)

    (define/override (can-encrypt? pad) (and (memq pad '(#f pkcs1-v1.5 oaep)) #t))

    (define/override (can-sign pad) 'depends)
    (define/override (can-sign2? pad dspec)
      (and (memq pad '(#f pkcs1-v1.5 pss pss*))
           (-known-digest? dspec)))

    (define/override (generate-key config)
      (define-values (nbits e)
        (check/ref-config '(nbits e) config config:rsa-keygen "RSA key generation"))
      (let ([e (or e 65537)])
        (define rsa (RSA_new))
        (define bn-e (BN_new))
        (BN_add_word bn-e e)
        (RSA_generate_key_ex rsa nbits bn-e #f)
        (define evp (EVP_PKEY_new))
        (EVP_PKEY_set1_RSA evp rsa)
        (RSA_free rsa)
        (new libcrypto-rsa-key% (impl this) (evp evp) (private? #t))))
    ))

(define libcrypto-rsa-key%
  (class libcrypto-pk-key%
    (inherit-field impl evp private?)
    (super-new)

    (define/override (get-security-bits)
      (or (EVP_PKEY_security_bits evp)
          (rsa-security-bits (EVP_PKEY_bits evp))))

    (define/override (-write-key fmt)
      (cond [(and (eq? fmt 'RSAPrivateKey) private?)
             (i2d i2d_PrivateKey evp)]
            [else (super -write-key fmt)]))

    (define/override (-set-sign-options ctx sign? pad dspec)
      (define di (send (send impl get-factory) get-digest dspec))
      (unless (is-a? di libcrypto-digest-impl%) (err/missing-digest dspec))
      (define saltlen (send di get-size))
      (EVP_PKEY_CTX_set_signature_md ctx (get-field md di))
      (case pad
        [(pkcs1-v1.5 #f)
         (EVP_PKEY_CTX_set_rsa_padding ctx RSA_PKCS1_PADDING)]
        [(pss)
         (EVP_PKEY_CTX_set_rsa_padding ctx RSA_PKCS1_PSS_PADDING)
         (when saltlen (EVP_PKEY_CTX_set_rsa_pss_saltlen ctx saltlen))]
        [(pss*)
         (EVP_PKEY_CTX_set_rsa_padding ctx RSA_PKCS1_PSS_PADDING)
         (when sign? (EVP_PKEY_CTX_set_rsa_pss_saltlen ctx saltlen))]
        [else (err/bad-signature-pad this pad)]))

    (define/override (-set-encrypt-padding ctx pad)
      (EVP_PKEY_CTX_set_rsa_padding ctx
        (case pad
          [(pkcs1-v1.5) RSA_PKCS1_PADDING]
          [(oaep #f)  RSA_PKCS1_OAEP_PADDING]
          [else (err/bad-encrypt-pad this pad)])))
    ))

;; ============================================================

(define libcrypto-dsa-impl%
  (class libcrypto-pk-impl%
    (inherit about -known-digest?)
    (super-new (spec 'dsa))

    (define/override (get-params-class) libcrypto-dsa-params%)
    (define/override (get-key-class) libcrypto-dsa-key%)

    (define/override (can-sign pad) (and (memq pad '(#f)) 'ignoredg))
    (define/override (has-params?) #t)

    (define/override (generate-params config)
      (define-values (nbits qbits)
        (check/ref-config '(nbits qbits) config config:dsa-paramgen "DSA parameter generation"))
      (let ()
        (when qbits
          (define actual-qbits (if (< nbits 2048) 160 256))
          (unless (equal? qbits actual-qbits)
            (impl-limit-error "qbits must be ~s for nbits ~a 2048\n  nbits: ~e\n  for: ~a"
                              actual-qbits (if (< nbits 2048) "<" ">=") nbits (about))))
        (define dsa (DSA_new))
        (DSA_generate_parameters_ex dsa nbits)
        (define evp (EVP_PKEY_new))
        (EVP_PKEY_set1_DSA evp dsa)
        (DSA_free dsa)
        (new libcrypto-dsa-params% (impl this) (pevp evp))))
    ))

(define libcrypto-dsa-params%
  (class libcrypto-pk-params%
    (inherit-field impl pevp)
    (super-new)

    (define/override (get-security-bits)
      (or (EVP_PKEY_security_bits pevp)
          (dsa/dh-security-bits (EVP_PKEY_bits pevp))))

    (define/override (generate-key config)
      (check-config config '() "DSA key generation from parameters")
      (define pdsa (EVP_PKEY_get1_DSA pevp))
      (define pder (i2d i2d_DSAparams pdsa))
      (DSA_free pdsa)
      (define kdsa (d2i_DSAparams pder (bytes-length pder)))
      (DSA_generate_key kdsa)
      (define kevp (EVP_PKEY_new))
      (EVP_PKEY_set1_DSA kevp kdsa)
      (DSA_free kdsa)
      (send impl make-private-key kevp))

    (define/override (-write-params fmt)
      (case fmt
        [(AlgorithmIdentifier)
         (asn1->bytes/DER AlgorithmIdentifier/DER
          (hasheq 'algorithm id-dsa
                  'parameters (-write-params 'DSAParameters)))]
        [(DSAParameters)
         (define dsa (EVP_PKEY_get1_DSA pevp))
         (begin0 (i2d i2d_DSAparams dsa)
           (DSA_free dsa))]
        [else (super -write-params fmt)]))
    ))

(define libcrypto-dsa-key%
  (class libcrypto-pk-key%
    (inherit-field impl evp private?)
    (super-new)

    (define/override (-set-sign-options ctx sign? pad dspec)
      (unless (eq? dspec 'none)
        (define di (send (send impl get-factory) get-digest dspec))
        (unless (is-a? di libcrypto-digest-impl%) (err/missing-digest dspec))
        (EVP_PKEY_CTX_set_signature_md ctx (get-field md di)))
      (case pad
        [(#f) (void)]
        [else (err/bad-signature-pad this pad)]))

    (define/override (-write-key fmt)
      (cond [(and (eq? fmt 'DSAPrivateKey) private?)
             (i2d i2d_PrivateKey evp)]
            [else (super -write-key fmt)]))
    ))

;; ============================================================

(define libcrypto-dh-impl%
  (class libcrypto-pk-impl%
    (super-new (spec 'dh))

    (define/override (get-params-class) libcrypto-dh-params%)
    (define/override (get-key-class) libcrypto-dh-key%)

    (define/override (can-key-agree?) #t)
    (define/override (has-params?) #t)

    (define/override (generate-params config)
      (define-values (nbits generator)
        (check/ref-config '(nbits generator) config config:dh-paramgen "DH parameter generation"))
      (let ()
        (define dh (DH_new))
        (DH_generate_parameters_ex dh nbits (or generator 2))
        ;; FIXME: DH_check ???
        (define evp (EVP_PKEY_new))
        (EVP_PKEY_set1_DH evp dh)
        (DH_free dh)
        (new libcrypto-dh-params% (impl this) (pevp evp))))
    ))

(define libcrypto-dh-params%
  (class libcrypto-pk-params%
    (inherit-field impl pevp)
    (super-new)

    (define/override (get-security-bits)
      (or (EVP_PKEY_security_bits pevp)
          (dsa/dh-security-bits (EVP_PKEY_bits pevp))))

    (define/override (-write-params fmt)
      (case fmt
        [(AlgorithmIdentifier)
         (asn1->bytes/DER AlgorithmIdentifier/DER
          (hasheq 'algorithm dhKeyAgreement
                  'parameters (-write-params 'DHParameter)))]
        [(DHParameter)
         (define dh (EVP_PKEY_get1_DH pevp))
         (begin0 (i2d i2d_DHparams dh)
           (DH_free dh))]
        [else (super -write-params fmt)]))

    (define/override (generate-key config)
      (check-config config '() "DH key generation")
      (define kdh
        (let ([dh0 (EVP_PKEY_get1_DH pevp)])
          (begin0 (DHparams_dup dh0)
            (DH_free dh0))))
      (DH_generate_key kdh)
      (define kevp (EVP_PKEY_new))
      (EVP_PKEY_set1_DH kevp kdh)
      (DH_free kdh)
      (send impl make-private-key kevp))
    ))

(define libcrypto-dh-key%
  (class libcrypto-pk-key%
    (inherit-field impl evp private?)
    (super-new)

    (define/override (-convert-for-key-agree peer-pubkey0)
      (define peer-dh
        (let ([dh0 (EVP_PKEY_get1_DH evp)])
          (begin0 (DHparams_dup dh0)
            (DH_free dh0))))
      (let ([pubkey (BN_bin2bn peer-pubkey0)])
        (set-DH_st_prefix-pubkey! peer-dh pubkey)
        (BN-no-gc pubkey))
      (define peer-evp (EVP_PKEY_new))
      (EVP_PKEY_set1_DH peer-evp peer-dh)
      (DH_free peer-dh)
      peer-evp)
    ))

;; ============================================================

(define libcrypto-ec-impl%
  (class libcrypto-pk-impl%
    (inherit -known-digest?)
    (super-new (spec 'ec))

    (define/override (get-params-class) libcrypto-ec-params%)
    (define/override (get-key-class) libcrypto-ec-key%)

    (define/override (can-sign pad) (and (memq pad '(#f)) 'ignoredg))
    (define/override (can-key-agree?) #t)
    (define/override (has-params?) #t)

    (define/override (generate-params config)
      (define-values (curve-name)
        (check/ref-config '(curve) config config:ec-paramgen "EC parameter generation"))
      (define curve-nid (find-curve-nid-by-name curve-name))
      (unless curve-nid (err/no-curve curve-name this))
      (define ec (EC_KEY_new_by_curve_name curve-nid))
      (unless ec (err/no-curve curve-name this))
      (begin
        ;; See http://wiki.openssl.org/index.php/Elliptic_Curve_Diffie_Hellman
        ;; in section "ECDH and Named Curves"
        (EC_KEY_set_asn1_flag ec OPENSSL_EC_NAMED_CURVE))
      (define evp (EVP_PKEY_new))
      (EVP_PKEY_set1_EC_KEY evp ec)
      (EC_KEY_free ec)
      (new libcrypto-ec-params% (impl this) (pevp evp)))
    ))

(define libcrypto-ec-params%
  (class* libcrypto-pk-params% (pk-curve-params<%>)
    (inherit-field impl pevp)
    (super-new)

    (define/public (get-curve)
      (define ec (EVP_PKEY_get0_EC_KEY pevp))
      (define group (and ec (EC_KEY_get0_group ec)))
      (define nid (and group (EC_GROUP_get_curve_name group)))
      (find-curve-name-by-nid nid))

    (define/public (get-curve-oid)
      (curve-alias->oid (get-curve)))

    (define/override (get-security-bits)
      (or (EVP_PKEY_security_bits pevp)
          (ec-security-bits (EVP_PKEY_bits pevp))))

    (define/override (-write-params fmt)
      (case fmt
        [(AlgorithmIdentifier)
         (asn1->bytes/DER AlgorithmIdentifier/DER
          (hasheq 'algorithm id-ecPublicKey
                  'parameters (-write-params 'EcpkParameters)))]
        [(EcpkParameters)
         (define ec (EVP_PKEY_get1_EC_KEY pevp))
         (define group (EC_KEY_get0_group ec))
         (begin0 (i2d i2d_ECPKParameters group)
           (EC_KEY_free ec))]
        [else (super -write-params fmt)]))

    (define/override (generate-key config)
      (check-config config '() "EC key generation")
      (define kec
        (let ([ec0 (EVP_PKEY_get1_EC_KEY pevp)])
          (begin0 (EC_KEY_dup ec0)
            (EC_KEY_free ec0))))
      (EC_KEY_generate_key kec)
      (begin ;; See note in generate-params above.
        (EC_KEY_set_asn1_flag kec OPENSSL_EC_NAMED_CURVE))
      (define kevp (EVP_PKEY_new))
      (EVP_PKEY_set1_EC_KEY kevp kec)
      (EC_KEY_free kec)
      (send impl make-private-key kevp))
    ))

(define libcrypto-ec-key%
  (class libcrypto-pk-key%
    (inherit-field impl evp private?)
    (super-new)

    ;; Check key (only in OpenSSL >= 1.1.1
    (let ()
      (define ctx (EVP_PKEY_CTX_new evp))
      (if private? (EVP_PKEY_check ctx) (EVP_PKEY_public_check ctx))
      (EVP_PKEY_CTX_free ctx))

    (define/override (-write-key fmt)
      (cond [(and (eq? fmt 'ECPrivateKey) private?)
             (define ec (EVP_PKEY_get1_EC_KEY evp))
             (begin0 (i2d i2d_ECPrivateKey ec)
               (EC_KEY_free ec))]
            [else (super -write-key fmt)]))

    (define/override (-convert-for-key-agree peer-pubkey0)
      (define ec (EVP_PKEY_get1_EC_KEY evp))
      (define group (EC_KEY_get0_group ec))
      (define group-degree (EC_GROUP_get_degree group))
      (define buf (make-bytes (ceil/ group-degree 8)))
      (define peer-pubkey-point (EC_POINT_new group))
      (EC_POINT_oct2point group peer-pubkey-point peer-pubkey0 (bytes-length peer-pubkey0))
      (define peer-ec (EC_KEY_new))
      (EC_KEY_set_group peer-ec group)
      (EC_KEY_set_public_key peer-ec peer-pubkey-point)
      (EC_POINT_free peer-pubkey-point)
      (EC_KEY_free ec)
      (define peer-evp (EVP_PKEY_new))
      (EVP_PKEY_set1_EC_KEY peer-evp peer-ec)
      (EC_KEY_free peer-ec)
      peer-evp)
    ))

;; ----------------------------------------

;; find-curve-nid-by-name : Symbol/String -> Nat/#f
(define (find-curve-nid-by-name name0)
  (for/or ([alias (curve-name->aliases name0)])
    (define nid (OBJ_sn2nid (symbol->string alias)))
    (and (positive? nid) nid)))

;; curve-table : Hash[Symbol => (cons Nat String/#f)]
(define curve-table
  (let ()
    ;; Add builtin curves
    (define curve-count (EC_get_builtin_curves #f 0))
    (define ci0 (cast (malloc curve-count _EC_builtin_curve 'atomic)
                      _pointer _EC_builtin_curve-pointer))
    (EC_get_builtin_curves ci0 curve-count)
    (for/hash ([i (in-range curve-count)])
      (define ci (ptr-add ci0 i _EC_builtin_curve))
      (define nid (EC_builtin_curve-nid ci))
      (values (string->symbol (OBJ_nid2sn nid))
              (cons nid (EC_builtin_curve-comment ci))))))

;; find-curve-name-by-nid : Nat -> Symbol/#f
(define (find-curve-name-by-nid nid)
  (hash-ref curve-name=>nid nid #f))

(define curve-name=>nid
  (for/hash ([(name nid+comment) (in-hash curve-table)])
    (values (car nid+comment) name)))

;; ============================================================

(define libcrypto-eddsa-impl%
  (class libcrypto-pk-impl%
    (inherit -known-digest?)
    (super-new (spec 'eddsa))

    (define/override (get-key-class) libcrypto-eddsa-key%)

    (define/override (can-sign pad) (and (memq pad '(#f)) 'nodigest))
    (define/override (has-params?) #t)

    (define/override (generate-params config)
      (define-values (curve-name)
        (check/ref-config '(curve) config config:eddsa-keygen "EdDSA parameter generation"))
      (curve->params curve-name))

    (define/public (curve->params curve)
      (unless (ed-curve->nid curve) (err/no-curve curve this))
      (new pk-eddsa-params% (impl this) (curve curve)))

    (define/public (generate-key-from-params curve)
      (define curve-nid (ed-curve->nid curve))
      (define secret-key-size (ed-curve->key-size curve))
      (define secret-key (crypto-random-bytes secret-key-size))
      (define evp (EVP_PKEY_new_raw_private_key curve-nid secret-key secret-key-size))
      (new libcrypto-eddsa-key% (impl this) (evp evp) (private? #t)))
    ))

(define libcrypto-eddsa-key%
  (class libcrypto-pk-key%
    (inherit-field impl evp private?)
    (super-new)

    (define/public (get-curve)
      (nid->ed-curve (EVP->type evp)))
    (define/public (get-sig-size)
      (ed-curve->sig-size (get-curve)))

    (define/override (get-params)
      (send impl curve->params (get-curve)))

    (define/override (-sign msg _dspec pad)
      (define ctx (EVP_MD_CTX_create))
      (define sig (make-bytes (get-sig-size)))
      (EVP_DigestSignInit ctx #f evp)
      (EVP_DigestSign ctx sig (bytes-length sig) msg (bytes-length msg))
      (EVP_MD_CTX_destroy ctx)
      sig)

    (define/override (-verify msg _dspec pad sig)
      (define ctx (EVP_MD_CTX_create))
      (EVP_DigestVerifyInit ctx #f evp)
      (begin0 (EVP_DigestVerify ctx sig (bytes-length sig) msg (bytes-length msg))
        (EVP_MD_CTX_destroy ctx)))
    ))

;; ----------------------------------------

(define (nid->ed-curve nid)
  (cond [(= nid NID_ED25519) 'ed25519]
        [(= nid NID_ED448)   'ed448]
        [else #f]))

(define (ed-curve->nid curve)
  (case curve
    [(ed25519) NID_ED25519]
    [(ed448)   NID_ED448]
    [else      #f]))

;; ============================================================

(define libcrypto-ecx-impl%
  (class libcrypto-pk-impl%
    (inherit -known-digest?)
    (super-new (spec 'ecx))

    (define/override (get-key-class) libcrypto-ecx-key%)

    (define/override (can-key-agree?) #t)
    (define/override (has-params?) #t)

    (define/override (generate-params config)
      (define-values (curve-name)
        (check/ref-config '(curve) config config:ecx-keygen "EC/X parameters generation"))
      (curve->params curve-name))

    (define/public (curve->params curve)
      (unless (x-curve->nid curve) (err/no-curve curve this))
      (new pk-ecx-params% (impl this) (curve curve)))

    (define/public (generate-key-from-params curve)
      (define curve-nid (x-curve->nid curve))
      (define secret-key-size (ecx-curve->key-size curve))
      (define secret-key (crypto-random-bytes secret-key-size))
      (define evp (EVP_PKEY_new_raw_private_key curve-nid secret-key (bytes-length secret-key)))
      (new libcrypto-ecx-key% (impl this) (evp evp) (private? #t)))
    ))

(define libcrypto-ecx-key%
  (class libcrypto-pk-key%
    (inherit-field impl evp private?)
    (super-new)

    (define/override (get-params)
      (send impl curve->params (nid->x-curve (EVP->type evp))))

    (define/override (-convert-for-key-agree peer-pubkey)
      (EVP_PKEY_new_raw_public_key (EVP->type evp) peer-pubkey (bytes-length peer-pubkey)))

    (define/override (-write-key fmt)
      (super -write-key fmt))
    ))

;; ----------------------------------------

(define (nid->x-curve nid)
  (cond [(= nid NID_X25519) 'x25519]
        [(= nid NID_X448)   'x448]
        [else #f]))

(define (x-curve->nid curve)
  (case curve
    [(x25519) NID_X25519]
    [(x448)   NID_X448]
    [else     #f]))
