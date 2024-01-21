;; Copyright 2013-2018 Ryan Culpepper
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

(require (for-syntax racket/base)
         ffi/unsafe
         ffi/unsafe/alloc
         (only-in '#%foreign ffi-obj)
         ffi/unsafe/define
         (rename-in gmp/unsafe [_mpz _mpz_t])
         racket/runtime-path
         "../common/ffi.rkt")

(provide (protect-out (all-defined-out)))

;; Cooperate with `raco distribute`.
(define-runtime-path libnettle-so
  '(so "libnettle" ("8" "7" "6" #f)))

(define-values (libnettle nettle-load-error)
  (ffi-lib-or-why-not libnettle-so '("8" "7" "6" #f)))

(define-ffi-definer define-nettle libnettle
  #:default-make-fail make-not-available)

(define nettle-ok? (and libnettle #t))

(define-nettle nettle_version_major (_fun -> _int))
(define-nettle nettle_version_minor (_fun -> _int))

(define (get-ok? fun-name)
  (and libnettle (get-ffi-obj fun-name libnettle _fpointer (lambda () #f)) #t))

;; ----

(define-cpointer-type _HASH_CTX)

(define _nettle_hash_init_func
  (_fun _HASH_CTX -> _void))
(define _nettle_hash_update_func
  (_fun _HASH_CTX _size _pointer -> _void))
(define _nettle_hash_digest_func
  (_fun _HASH_CTX _size _pointer -> _void))

(define-cstruct _nettle_hash
  ([name         _string/utf-8]
   [context_size _uint]
   [digest_size  _uint]
   [block_size   _uint]
   [init         _nettle_hash_init_func]
   [update       _nettle_hash_update_func]
   [digest       _nettle_hash_digest_func]))

(define-nettle nettle_get_hashes (_fun -> _pointer) #:fail (lambda () #f))

(define nettle-hashes
  (let ()
    (define (get-regular-hashes ptr)
      (let loop ([i 0])
        (define next (and ptr (ptr-ref ptr _nettle_hash-pointer/null i)))
        (if next (cons (list (nettle_hash-name next) next) (loop (add1 i))) null)))
    (define (get-named-hash name)
      (let ([obj (get-ffi-obj name libnettle _nettle_hash (lambda () #f))])
        (and obj (list (nettle_hash-name obj) obj))))
    (cond [(not libnettle) #f]
          [nettle_get_hashes
           (get-regular-hashes (nettle_get_hashes))]
          ;; Before Nettle 3.5:
          ;; struct nettle_hash *nettle_hashes[] // NULL-terminated array
          [(ffi-obj #"nettle_hashes" libnettle)
           => (lambda (ptr)
                (append (get-regular-hashes ptr)
                        (filter values
                                (map get-named-hash
                                     '(#"nettle_sha3_224"
                                       #"nettle_sha3_256"
                                       #"nettle_sha3_384"
                                       #"nettle_sha3_512")))))]
          [else null])))

;; ----

(define-nettle nettle_hmac_set_key
  (_fun (outer inner state hash key) ::
        (outer : _HASH_CTX)
        (inner : _HASH_CTX)
        (state : _HASH_CTX)
        (hash  : _nettle_hash-pointer)
        (keylen : _size = (bytes-length key))
        (key   : _pointer)
        -> _void))

(define-nettle nettle_hmac_update
  (_fun (state hash inbuf inlen) ::
        (state : _HASH_CTX)
        (hash  : _nettle_hash-pointer)
        (inlen : _size)
        (inbuf : _pointer)
        -> _void))

(define-nettle nettle_hmac_digest
  (_fun (outer inner state hash outbuf outlen) ::
        (outer  : _HASH_CTX)
        (inner  : _HASH_CTX)
        (state  : _HASH_CTX)
        (hash   : _nettle_hash-pointer)
        (outlen : _size)
        (outbuf : _pointer)
        -> _void))

;; ----

(define-cpointer-type _CIPHER_CTX)

(define _nettle_set_key_func (_fun _CIPHER_CTX _pointer -> _void))
(define _nettle_crypt_func   _fpointer)
(define _rkt_crypt_func      (_fun _CIPHER_CTX _size _pointer _pointer -> _void))

(define _nettle_set_key/len_func
  (_fun (ctx key) ::
        (ctx : _CIPHER_CTX) (_size = (bytes-length key)) (key : _pointer) -> _void))

(define-cstruct _nettle_cipher
  ([name            _string/utf-8]
   [context_size    _uint]
   [block_size      _uint]
   [key_size        _uint]
   [set_encrypt_key _nettle_set_key_func]
   [set_decrypt_key _nettle_set_key_func]
   [encrypt         _nettle_crypt_func]
   [decrypt         _nettle_crypt_func]))

;; Want to create cipher records for "irregular" ciphers; easiest way
;; to handle mix of static, foreign-allocated records and dynamic,
;; racket-allocated records is to copy.

(struct nettle-cipher (name
                       context-size block-size key-size
                       set-encrypt-key set-decrypt-key
                       encrypt decrypt
                       rkt-encrypt rkt-decrypt
                       extras))
(define (nettle-cipher-ref nc key)
  (cond [(assq key (nettle-cipher-extras nc)) => cadr] [else #f]))

(define-nettle nettle_get_ciphers (_fun -> _pointer) #:fail (lambda () #f))

(define nettle-regular-ciphers
  (let ([ptr (cond [nettle_get_ciphers (nettle_get_ciphers)]
                   [(and libnettle (ffi-obj #"nettle_ciphers" libnettle))
                    => values]
                   [else #f])])
    (let loop ([i 0])
      (let ([next (and ptr (ptr-ref ptr _nettle_cipher-pointer/null i))])
        (if next
            (cons (nettle-cipher (nettle_cipher-name next)
                                 (nettle_cipher-context_size next)
                                 (max 1 (nettle_cipher-block_size next))
                                 (nettle_cipher-key_size next)
                                 (nettle_cipher-set_encrypt_key next)
                                 (nettle_cipher-set_decrypt_key next)
                                 (nettle_cipher-encrypt next)
                                 (nettle_cipher-decrypt next)
                                 (cast (nettle_cipher-encrypt next) _fpointer _rkt_crypt_func)
                                 (cast (nettle_cipher-decrypt next) _fpointer _rkt_crypt_func)
                                 null)
                  (loop (add1 i)))
            null)))))

;; nettle_ciphers omits ciphers with any irregularity; create entries for them too

(define BLOWFISH_ROUNDS 16)
(define BLOWFISH_CONTEXT_SIZE (+ (* 4 4 256) (* 4 (+ 2 BLOWFISH_ROUNDS))))
(define BLOWFISH_BLOCK_SIZE 8)
(define BLOWFISH_KEY_SIZE 16) ;; reasonable default
(define-nettle nettle_blowfish_set_key _nettle_set_key/len_func)
(define-nettle nettle_blowfish_encrypt _nettle_crypt_func)
(define-nettle nettle_blowfish_decrypt _nettle_crypt_func)

(define blowfish-cipher
  (and (get-ok? #"nettle_blowfish_encrypt")
       (nettle-cipher "blowfish"
                      BLOWFISH_CONTEXT_SIZE BLOWFISH_BLOCK_SIZE BLOWFISH_KEY_SIZE
                      nettle_blowfish_set_key nettle_blowfish_set_key
                      nettle_blowfish_encrypt nettle_blowfish_decrypt
                      (cast nettle_blowfish_encrypt _fpointer _rkt_crypt_func)
                      (cast nettle_blowfish_decrypt _fpointer _rkt_crypt_func)
                      null)))

(define _nettle_set_iv/nonce_func (_fun _CIPHER_CTX _pointer -> _void))

(define SALSA20_CONTEXT_SIZE (* 4 16))
(define SALSA20_KEY_SIZE 32)
(define SALSA20_BLOCK_SIZE 64)
(define SALSA20_IV_SIZE 8)
(define-nettle nettle_salsa20_set_key _nettle_set_key/len_func)
(define-nettle nettle_salsa20_set_nonce _nettle_set_iv/nonce_func)
(define-nettle nettle_salsa20_crypt _nettle_crypt_func)
(define-nettle nettle_salsa20r12_crypt _nettle_crypt_func)

(define salsa20-cipher
  (and (get-ok? #"nettle_salsa20_crypt")
       (nettle-cipher "salsa20"
                      SALSA20_CONTEXT_SIZE SALSA20_BLOCK_SIZE SALSA20_KEY_SIZE
                      nettle_salsa20_set_key nettle_salsa20_set_key
                      nettle_salsa20_crypt nettle_salsa20_crypt
                      (cast nettle_salsa20_crypt _fpointer _rkt_crypt_func)
                      (cast nettle_salsa20_crypt _fpointer _rkt_crypt_func)
                      `((set-iv ,nettle_salsa20_set_nonce)))))

(define salsa20r12-cipher
  (and (get-ok? #"nettle_salsa20r12_crypt")
       (nettle-cipher "salsa20r12"
                      SALSA20_CONTEXT_SIZE SALSA20_BLOCK_SIZE SALSA20_KEY_SIZE
                      nettle_salsa20_set_key nettle_salsa20_set_key
                      nettle_salsa20r12_crypt nettle_salsa20r12_crypt
                      (cast nettle_salsa20r12_crypt _fpointer _rkt_crypt_func)
                      (cast nettle_salsa20r12_crypt _fpointer _rkt_crypt_func)
                      `((set-iv ,nettle_salsa20_set_nonce)))))

(define CHACHA_CONTEXT_SIZE (* 4 16))
(define CHACHA_KEY_SIZE 32)
(define CHACHA_BLOCK_SIZE 64)
(define CHACHA_NONCE_SIZE 8)
(define CHACHA_NONCE96_SIZE 12)
(define-nettle nettle_chacha_set_key _nettle_set_key_func)
(define-nettle nettle_chacha_set_nonce _nettle_set_iv/nonce_func)
(define-nettle nettle_chacha_set_nonce96 _nettle_set_iv/nonce_func)
(define-nettle nettle_chacha_crypt _nettle_crypt_func)

(define chacha-cipher
  (and (get-ok? #"nettle_chacha_crypt")
       (nettle-cipher "chacha"
                      CHACHA_CONTEXT_SIZE CHACHA_BLOCK_SIZE CHACHA_KEY_SIZE
                      nettle_chacha_set_key nettle_chacha_set_key
                      nettle_chacha_crypt nettle_chacha_crypt
                      (cast nettle_chacha_crypt _fpointer _rkt_crypt_func)
                      (cast nettle_chacha_crypt _fpointer _rkt_crypt_func)
                      `((set-iv ,nettle_chacha_set_nonce)))))

(define POLY1305_CONTEXT_SIZE
  (ctype-sizeof
   (make-cstruct-type
    (list (_union (_array _uint32 6) (_array _uint64 3))
          (_array _uint32 3)
          _uint32
          (_union (_array _uint32 4) (_array _uint64 2))))))
(define POLY1305_BLOCK_SIZE 16)

(define CHACHA_POLY1305_CONTEXT_SIZE
  (ctype-sizeof
   (make-cstruct-type
    (list (_array _byte CHACHA_CONTEXT_SIZE)
          (_array _byte POLY1305_CONTEXT_SIZE)
          (_array _ulong (/ 16 (ctype-sizeof _ulong))) ;; nettle_block16
          _uint64
          _uint64
          (_array _uint8 POLY1305_BLOCK_SIZE)
          _uint))))
(define CHACHA_POLY1305_KEY_SIZE 32)
(define CHACHA_POLY1305_BLOCK_SIZE 64)
(define CHACHA_POLY1305_NONCE96_SIZE 12)
(define-nettle nettle_chacha_poly1305_set_key _nettle_set_key_func)
(define-nettle nettle_chacha_poly1305_set_nonce _nettle_set_iv/nonce_func)
(define-nettle nettle_chacha_poly1305_update (_fun _CIPHER_CTX _size _pointer -> _void))
(define-nettle nettle_chacha_poly1305_encrypt _nettle_crypt_func)
(define-nettle nettle_chacha_poly1305_decrypt _nettle_crypt_func)
(define-nettle nettle_chacha_poly1305_digest (_fun _CIPHER_CTX _size _pointer -> _void))

(define chacha-poly1305-cipher
  (and (get-ok? #"nettle_chacha_poly1305_encrypt")
       (nettle-cipher "chacha-poly1305"
                      CHACHA_POLY1305_CONTEXT_SIZE CHACHA_POLY1305_BLOCK_SIZE CHACHA_POLY1305_KEY_SIZE
                      nettle_chacha_poly1305_set_key nettle_chacha_poly1305_set_key
                      nettle_chacha_poly1305_encrypt nettle_chacha_poly1305_decrypt
                      (cast nettle_chacha_poly1305_encrypt _fpointer _rkt_crypt_func)
                      (cast nettle_chacha_poly1305_decrypt _fpointer _rkt_crypt_func)
                      `((set-iv ,nettle_chacha_poly1305_set_nonce)
                        (update-aad ,nettle_chacha_poly1305_update)
                        (get-auth-tag ,nettle_chacha_poly1305_digest)))))

(define nettle-all-ciphers
  (let* ([more-ciphers
          (append nettle-regular-ciphers
                  (filter values
                          (list blowfish-cipher
                                salsa20-cipher
                                salsa20r12-cipher
                                chacha-cipher
                                chacha-poly1305-cipher)))])
    (for/list ([cipher (in-list more-ciphers)])
      (list (nettle-cipher-name cipher) cipher))))

;; ----

(define-nettle nettle_cbc_encrypt
  (_fun (ctx     : _CIPHER_CTX)
        (encrypt : _nettle_crypt_func)
        (blksize : _size)
        (iv      : _pointer)
        (length  : _size)
        (dst     : _pointer)
        (src     : _pointer)
        -> _void))

(define-nettle nettle_cbc_decrypt
  (_fun (ctx     : _CIPHER_CTX)
        (decrypt : _nettle_crypt_func)
        (blksize : _size)
        (iv      : _pointer)
        (length  : _size)
        (dst     : _pointer)
        (src     : _pointer)
        -> _void))

(define-nettle nettle_ctr_crypt
  (_fun (ctx     : _CIPHER_CTX)
        (crypt   : _nettle_crypt_func)
        (blksize : _size)
        (ctr     : _pointer)
        (length  : _size)
        (dst     : _pointer)
        (src     : _pointer)
        -> _void))

(define EAX_BLOCK_SIZE 16)
(define EAX_DIGEST_SIZE 16)
(define EAX_KEY_SIZE (* 2 16))
(define EAX_CTX_SIZE (* 4 16))
(define-cpointer-type _eax_key)
(define-cpointer-type _eax_ctx)

(define eax-ok? (get-ok? #"nettle_eax_set_key"))

(define-nettle nettle_eax_set_key
  (_fun _eax_key _CIPHER_CTX _nettle_crypt_func -> _void))
(define-nettle nettle_eax_set_nonce
  (_fun _eax_ctx _eax_key _CIPHER_CTX _nettle_crypt_func _size _pointer -> _void))
(define-nettle nettle_eax_update
  (_fun _eax_ctx _eax_key _CIPHER_CTX _nettle_crypt_func _size _pointer -> _void))
(define-nettle nettle_eax_encrypt
  (_fun _eax_ctx _eax_key _CIPHER_CTX _nettle_crypt_func _size _pointer _pointer -> _void))
(define-nettle nettle_eax_decrypt
  (_fun _eax_ctx _eax_key _CIPHER_CTX _nettle_crypt_func _size _pointer _pointer -> _void))
(define-nettle nettle_eax_digest
  (_fun _eax_ctx _eax_key _CIPHER_CTX _nettle_crypt_func _size _pointer -> _void))

(define GCM_BLOCK_SIZE 16)
(define GCM_IV_SIZE (- GCM_BLOCK_SIZE 4))
(define GCM_TABLE_BITS 8)
;; gcm_block = GCM_BLOCK_SIZE bytes, ulong-aligned
;; gcm_key = array of 1<<GCM_TABLE_BITS gcm_blocks
;; gcm_ctx = { 3 * gcm_block ; 2 * uint64 }
(define GCM_KEY_SIZE (* GCM_BLOCK_SIZE (expt 2 GCM_TABLE_BITS)))
(define GCM_CTX_SIZE (+ (* 3 GCM_BLOCK_SIZE) (* 2 (ctype-sizeof _uint64))))
(define-cpointer-type _gcm_key)
(define-cpointer-type _gcm_ctx)

(define gcm-ok? (get-ok? #"nettle_gcm_set_key"))

(define-nettle nettle_gcm_set_key
  (_fun _gcm_key _CIPHER_CTX _nettle_crypt_func -> _void))
(define-nettle nettle_gcm_set_iv
  (_fun _gcm_ctx _gcm_key _size _pointer -> _void))
(define-nettle nettle_gcm_update
  (_fun _gcm_ctx _gcm_key _uint _pointer -> _void))
(define-nettle nettle_gcm_encrypt
  (_fun _gcm_ctx _gcm_key _CIPHER_CTX _nettle_crypt_func _size _pointer _pointer -> _void))
(define-nettle nettle_gcm_decrypt
  (_fun _gcm_ctx _gcm_key _CIPHER_CTX _nettle_crypt_func _size _pointer _pointer -> _void))
(define-nettle nettle_gcm_digest
  (_fun _gcm_ctx _gcm_key _CIPHER_CTX _nettle_crypt_func _size _pointer -> _void))

;; ----

(define-nettle nettle_pbkdf2
  (_fun (mac_ctx update_func digest_func digest_size iterations salt out) ::
        (mac_ctx : _HASH_CTX) ;; 3 * digest_size !
        (update_func : _fpointer) ;; Note: hmac udpate func, not hash update func!
        (digest_func : _fpointer) ;; ditto
        (digest_size : _size)
        (iterations : _uint)
        (salt_length : _size = (bytes-length salt))
        (salt : _bytes)
        (outlen : _size = (bytes-length out))
        (out : _bytes)
        -> _void))

(define-nettle nettle_pbkdf2_hmac_sha1
  (_fun (key salt iters outlen) ::
        (_size = (bytes-length key))
        (key : _bytes)
        (iters : _uint)
        (_size = (bytes-length salt))
        (salt : _bytes)
        (outlen : _size)
        (out : _bytes = (make-bytes outlen))
        -> _void -> out))

(define-nettle nettle_pbkdf2_hmac_sha256
  (_fun (key salt iters outlen) ::
        (_size = (bytes-length key))
        (key : _bytes)
        (iters : _uint)
        (_size = (bytes-length salt))
        (salt : _bytes)
        (outlen : _size)
        (out : _bytes = (make-bytes outlen))
        -> _void -> out))

;; ----

(define YARROW256_CTX_SIZE 496)
(define YARROW_SOURCE_SIZE 12)
(define YARROW256_SEED_FILE_SIZE 32)   ;; = 2 * AES_BLOCK_SIZE

(define-cpointer-type _yarrow256_ctx)
(define-cpointer-type _yarrow_source)

(define-nettle nettle_yarrow256_init
  (_fun _yarrow256_ctx _uint _yarrow_source/null -> _void))

(define-nettle nettle_yarrow256_seed
  (_fun (ctx buf) ::
        (ctx : _yarrow256_ctx)
        (len : _size = (bytes-length buf))
        (buf : _bytes)
        -> _void))

(define-nettle nettle_yarrow256_update
  (_fun (ctx src entropy buf) ::
        (ctx : _yarrow256_ctx)
        (src : _uint)
        (entropy : _uint)
        (len : _size = (bytes-length buf))
        (buf : _bytes)
        -> _int))

(define-nettle nettle_yarrow256_random
  (_fun _yarrow256_ctx _size _pointer
        -> _void))

(define-nettle nettle_yarrow256_is_seeded
  (_fun _yarrow256_ctx -> _bool))

(define-nettle nettle_yarrow256_needed_sources
  (_fun _yarrow256_ctx -> _uint))

(define-nettle nettle_yarrow256_fast_reseed
  (_fun _yarrow256_ctx -> _void))
(define-nettle nettle_yarrow256_slow_reseed
  (_fun _yarrow256_ctx -> _void))

(define-nettle yarrow_random _fpointer
  #:c-id nettle_yarrow256_random)

;; ============================================================

(define-runtime-path libhogweed-so
  '(so "libhogweed" ("6" "5" "4" #f)))

(define-values (libhogweed hogweed-load-error)
  (ffi-lib-or-why-not libhogweed-so '("6" "5" "4" #f)))

(define-ffi-definer define-nettleHW libhogweed
  #:default-make-fail make-not-available)

(define (get-hw-ok? fun)
  (and libhogweed (get-ffi-obj fun libhogweed _fpointer (lambda () #f)) #t))

;; ----------------------------------------
;; RSA

(define rsa-ok? (get-hw-ok? #"nettle_rsa_public_key_init"))

(define-cstruct _rsa_public_key_struct
  ([size _uint]  ;; size of modulo in octets, also size in sigs
   [n    _mpz_struct]
   [e    _mpz_struct]))

(define-cstruct _rsa_private_key_struct
  ([size _uint]
   [d    _mpz_struct]
   [p    _mpz_struct]
   [q    _mpz_struct]
   [a    _mpz_struct]
   [b    _mpz_struct]
   [c    _mpz_struct]))

(define _rsa_public_key _rsa_public_key_struct-pointer)
(define _rsa_private_key _rsa_private_key_struct-pointer)

(define-nettleHW nettle_rsa_public_key_init
  (_fun _rsa_public_key -> _void))
(define-nettleHW nettle_rsa_private_key_init
  (_fun _rsa_private_key -> _void))

(define-nettleHW nettle_rsa_public_key_clear
  (_fun _rsa_public_key -> _void)
  #:wrap (deallocator))
(define-nettleHW nettle_rsa_private_key_clear
  (_fun _rsa_private_key -> _void)
  #:wrap (deallocator))

(define new-rsa_public_key
  ((allocator nettle_rsa_public_key_clear)
   (lambda ()
     (define k (malloc _rsa_public_key_struct 'atomic-interior))
     (cpointer-push-tag! k rsa_public_key_struct-tag)
     (nettle_rsa_public_key_init k)
     k)))

(define new-rsa_private_key
  ((allocator nettle_rsa_private_key_clear)
   (lambda ()
     (define k (malloc _rsa_private_key_struct 'atomic-interior))
     (cpointer-push-tag! k rsa_private_key_struct-tag)
     (nettle_rsa_private_key_init k)
     k)))

(define-nettleHW nettle_rsa_public_key_prepare
  (_fun _rsa_public_key -> _bool))
(define-nettleHW nettle_rsa_private_key_prepare
  (_fun _rsa_private_key -> _bool))

(define-nettleHW nettle_rsa_md5_sign_digest    (_fun _rsa_private_key _bytes _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha1_sign_digest   (_fun _rsa_private_key _bytes _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha256_sign_digest (_fun _rsa_private_key _bytes _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha512_sign_digest (_fun _rsa_private_key _bytes _mpz_t -> _bool))

(define sign-digest-type
  (_fun _rsa_public_key _rsa_private_key _pointer (_fpointer = yarrow_random)
        _bytes _mpz_t -> _bool))
(define (((make-sign-fallback f)) pub priv randctx digest sig) (f priv digest sig))

;; timing-resistant functions added in Nettle 3.2
(define-nettleHW nettle_rsa_md5_sign_digest_tr sign-digest-type
  #:fail (make-sign-fallback nettle_rsa_md5_sign_digest))
(define-nettleHW nettle_rsa_sha1_sign_digest_tr sign-digest-type
  #:fail (make-sign-fallback nettle_rsa_sha1_sign_digest))
(define-nettleHW nettle_rsa_sha256_sign_digest_tr sign-digest-type
  #:fail (make-sign-fallback nettle_rsa_sha256_sign_digest))
(define-nettleHW nettle_rsa_sha512_sign_digest_tr sign-digest-type
  #:fail (make-sign-fallback nettle_rsa_sha512_sign_digest))

;; PSS functions added in Nettle 3.4
(define pss-ok? (get-hw-ok? #"nettle_rsa_pss_sha256_sign_digest_tr"))
(define pss-sign-digest-type
  (_fun _rsa_public_key _rsa_private_key _pointer (_fpointer = yarrow_random)
        _size _bytes _bytes _mpz_t -> _bool))

(define-nettleHW nettle_rsa_pss_sha256_sign_digest_tr pss-sign-digest-type)
(define-nettleHW nettle_rsa_pss_sha384_sign_digest_tr pss-sign-digest-type)
(define-nettleHW nettle_rsa_pss_sha512_sign_digest_tr pss-sign-digest-type)

(define-nettleHW nettle_rsa_md5_verify_digest    (_fun _rsa_public_key _pointer _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha1_verify_digest   (_fun _rsa_public_key _pointer _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha256_verify_digest (_fun _rsa_public_key _pointer _mpz_t -> _bool))
(define-nettleHW nettle_rsa_sha512_verify_digest (_fun _rsa_public_key _pointer _mpz_t -> _bool))

(define-nettleHW nettle_rsa_pss_sha256_verify_digest (_fun _rsa_public_key _size _bytes _mpz_t -> _bool))
(define-nettleHW nettle_rsa_pss_sha384_verify_digest (_fun _rsa_public_key _size _bytes _mpz_t -> _bool))
(define-nettleHW nettle_rsa_pss_sha512_verify_digest (_fun _rsa_public_key _size _bytes _mpz_t -> _bool))

(define-nettleHW nettle_rsa_generate_keypair
  (_fun _rsa_public_key
        _rsa_private_key
        (random-ctx : _pointer)
        (_fpointer = yarrow_random)
        (_pointer = #f)
        (_fpointer = #f)
        (n_size : _uint)
        (e_size : _uint)
        -> _int))

(define-nettleHW nettle_rsa_encrypt  ;; PKCS1 v1.5 padding
  (_fun (pub random-ctx cleartext ciphertext) ::
        (pub : _rsa_public_key)
        (random-ctx : _pointer)
        (_fpointer = yarrow_random)
        (_uint = (bytes-length cleartext))
        (cleartext : _bytes)
        (ciphertext : _mpz_t)
        -> _bool))

(define-nettleHW nettle_rsa_decrypt ;; PKCS1 v1.5 padding
  (_fun (priv cleartext ciphertext) ::
        (priv : _rsa_private_key)
        (len : (_ptr io _size) = (bytes-length cleartext))
        (cleartext : _bytes)
        (ciphertext : _mpz_t)
        -> (result : _bool)
        -> (and result len)))

(define-nettleHW nettle_rsa_decrypt_tr
  (_fun (pub priv randomctx cleartext ciphertext) ::
        (pub : _rsa_public_key)
        (priv : _rsa_private_key)
        (randomctx : _pointer)
        (_fpointer = yarrow_random)
        (len : (_ptr io _size) = (bytes-length cleartext))
        (cleartext : _bytes)
        (ciphertext : _mpz_t)
        -> (result : _bool)
        -> (and result len))
  #:fail (lambda () (lambda (pub priv randomctx cleartext ciphertext)
                      (nettle_rsa_decrypt priv cleartext ciphertext))))

;; ----------------------------------------
;; DSA

(define-cstruct _dsa_signature_struct
  ([r    _mpz_struct]
   [s    _mpz_struct]))

(define _dsa_signature _dsa_signature_struct-pointer)

(define-nettleHW nettle_dsa_signature_init (_fun _dsa_signature -> _void))
(define-nettleHW nettle_dsa_signature_clear (_fun _dsa_signature -> _void)
  #:wrap (deallocator))

(define new-dsa_signature
  ((allocator nettle_dsa_signature_clear)
   (lambda ()
     (define k (malloc _dsa_signature_struct 'atomic-interior))
     (cpointer-push-tag! k mpz_struct-tag)
     (cpointer-push-tag! k dsa_signature_struct-tag)
     (nettle_dsa_signature_init k)
     k)))

;; -- Nettle 3.0 has new DSA api

(define new-dsa-ok? (get-hw-ok? #"nettle_dsa_params_init"))

(define-cstruct _dsa_params_struct
  ([p    _mpz_struct]
   [q    _mpz_struct]
   [g    _mpz_struct]))
(define _dsa_params _dsa_params_struct-pointer)

(define-nettleHW nettle_dsa_params_init (_fun _dsa_params -> _void))
(define-nettleHW nettle_dsa_params_clear (_fun _dsa_params -> _void)
  #:wrap (deallocator))

(define new-dsa_params
  ((allocator nettle_dsa_params_clear)
   (lambda ()
     (define p (malloc _dsa_params_struct 'atomic-interior))
     (cpointer-push-tag! p mpz_struct-tag)
     (cpointer-push-tag! p dsa_params_struct-tag)
     (nettle_dsa_params_init p)
     p)))

(define-nettleHW nettle_dsa_generate_params
  (_fun (params randctx pbits qbits) ::
        (params : _dsa_params)
        (randctx : _pointer)
        (_fpointer = yarrow_random)
        (_pointer = #f)
        (_fpointer = #f)
        (pbits : _uint)
        (qbits : _uint)
        -> _bool))

(define-nettleHW nettle_dsa_sign
  (_fun (params priv randctx digest sig) ::
        (params : _dsa_params)
        (priv : _mpz_t)
        (randctx : _pointer)
        (_fpointer = yarrow_random)
        (_size = (bytes-length digest))
        (digest : _bytes)
        (sig : _dsa_signature)
        -> _bool))

(define-nettleHW nettle_dsa_verify
  (_fun (params pub digest sig) ::
        (params : _dsa_params)
        (pub : _mpz_t)
        (_size = (bytes-length digest))
        (digest : _bytes)
        (sig : _dsa_signature)
        -> _bool))

(define-nettleHW nettle_dsa_generate_keypair
  (_fun (params pub priv randctx) ::
        (params : _dsa_params)
        (pub : _mpz_t)
        (priv : _mpz_t)
        (randctx : _pointer)
        (_fpointer = yarrow_random)
        -> _void))

;; ----------------------------------------
;; EC

(define-cpointer-type _ecc_curve)

(define-cstruct _ecc_point_struct ([ecc _ecc_curve] [p _pointer])
  #:malloc-mode 'atomic-interior)
(define-cstruct _ecc_scalar_struct ([ecc _ecc_curve] [p _pointer])
  #:malloc-mode 'atomic-interior)

(define _ecc_point _ecc_point_struct-pointer)
(define _ecc_scalar _ecc_scalar_struct-pointer)

(define-nettleHW nettle_ecc_point_clear (_fun _ecc_point -> _void))
(define-nettleHW nettle_ecc_point_init (_fun _ecc_point _ecc_curve -> _void))

(define new-ecc_point
  ((allocator nettle_ecc_point_clear)
   (lambda (ecc)
     (define p (make-ecc_point_struct ecc #f))
     (nettle_ecc_point_init p ecc)
     p)))

(define-nettleHW nettle_ecc_point_set (_fun _ecc_point _mpz_t _mpz_t -> _bool)) ;; 0 = err
(define-nettleHW nettle_ecc_point_get (_fun _ecc_point _mpz_t _mpz_t -> _void))

(define-nettleHW nettle_ecc_scalar_clear (_fun _ecc_scalar -> _void))
(define-nettleHW nettle_ecc_scalar_init (_fun _ecc_scalar _ecc_curve -> _void))

(define new-ecc_scalar
  ((allocator nettle_ecc_scalar_clear)
   (lambda (ecc)
     (define s (make-ecc_scalar_struct ecc #f))
     (nettle_ecc_scalar_init s ecc)
     s)))

(define-nettleHW nettle_ecc_scalar_set (_fun _ecc_scalar _mpz_t -> _bool)) ;; #f=err
(define-nettleHW nettle_ecc_scalar_get (_fun _ecc_scalar _mpz_t -> _void))

(define-nettleHW nettle_ecc_scalar_random
  (_fun _ecc_scalar _pointer (_fpointer = yarrow_random) -> _void))

(define-nettleHW nettle_ecc_point_mul (_fun _ecc_point _ecc_scalar _ecc_point -> _void))
(define-nettleHW nettle_ecc_point_mul_g (_fun _ecc_point _ecc_scalar -> _void))

(define-nettleHW nettle_ecc_bit_size (_fun _ecc_curve -> _uint))

(define-nettleHW nettle_get_secp_192r1 (_fun -> _ecc_curve) #:fail (lambda () (lambda () #f)))
(define-nettleHW nettle_get_secp_224r1 (_fun -> _ecc_curve) #:fail (lambda () (lambda () #f)))
(define-nettleHW nettle_get_secp_256r1 (_fun -> _ecc_curve) #:fail (lambda () (lambda () #f)))
(define-nettleHW nettle_get_secp_384r1 (_fun -> _ecc_curve) #:fail (lambda () (lambda () #f)))
(define-nettleHW nettle_get_secp_521r1 (_fun -> _ecc_curve) #:fail (lambda () (lambda () #f)))

(define nettle-curves
  (filter cadr
          `([secp192r1 ,(nettle_get_secp_192r1)]
            [secp224r1 ,(nettle_get_secp_224r1)]
            [secp256r1 ,(nettle_get_secp_256r1)]
            [secp384r1 ,(nettle_get_secp_384r1)]
            [secp521r1 ,(nettle_get_secp_521r1)])))

(define ec-ok? (and (get-hw-ok? #"nettle_ecc_point_init") (pair? nettle-curves)))

(define-nettleHW nettle_ecdsa_sign
  (_fun (key randctx digest sig) ::
        (key : _ecc_scalar)
        (randctx : _pointer)
        (_fpointer = yarrow_random)
        (_size = (bytes-length digest))
        (digest : _bytes)
        (sig : _dsa_signature)
        -> _void))

(define-nettleHW nettle_ecdsa_verify
  (_fun (pubkey digest sig) ::
        (pubkey : _ecc_point)
        (_size = (bytes-length digest))
        (digest : _bytes)
        (sig : _dsa_signature)
        -> _bool))

(define-nettleHW nettle_ecdsa_generate_keypair
  (_fun _ecc_point _ecc_scalar _pointer (_fpointer = yarrow_random) -> _void))

;; ----------------------------------------
;; Ed25519

(define ED25519_KEY_SIZE 32)
(define ED25519_SIGNATURE_SIZE 64)

(define-nettleHW nettle_ed25519_sha512_public_key
  (_fun (pub : _pointer)
        (priv : _pointer)
        -> _void))

(define-nettleHW nettle_ed25519_sha512_sign
  (_fun (pub : _pointer)
        (priv : _pointer)
        (len : _size)
        (msg : _pointer)
        (sig : _pointer)
        -> _void))

(define-nettleHW nettle_ed25519_sha512_verify
  (_fun (pub : _pointer)
        (len : _size)
        (msg : _pointer)
        (sig : _pointer)
        -> _bool))

(define ed25519-ok? (get-hw-ok? #"nettle_ed25519_sha512_sign"))

;; ----------------------------------------
;; Ed448 (since 3.6)

(define ED448_KEY_SIZE 57)
(define ED448_SIGNATURE_SIZE 114)

(define-nettleHW nettle_ed448_shake256_public_key
  (_fun (pub : _pointer)
        (priv : _pointer)
        -> _void))

(define-nettleHW nettle_ed448_shake256_sign
  (_fun (pub : _pointer) (priv : _pointer)
        (len : _size) (msg : _pointer) (sig : _pointer)
        -> _void))

(define-nettleHW nettle_ed448_shake256_verify
  (_fun (pub : _pointer)
        (len : _size)
        (msg : _pointer)
        (sig : _pointer)
        -> _bool))

(define ed448-ok? (get-hw-ok? #"nettle_ed448_shake256_sign"))

;; ----------------------------------------
;; X25519

(define X25519_KEY_SIZE 32)

(define-nettleHW nettle_curve25519_mul_g
  (_fun (pub : _pointer) (priv : _pointer) -> _void))
(define-nettleHW nettle_curve25519_mul
  (_fun (key : _pointer) (priv : _pointer) (peer : _pointer) -> _void))

(define x25519-ok? (get-hw-ok? #"nettle_curve25519_mul"))

;; ----------------------------------------
;; X448 (since 3.6)

(define X448_KEY_SIZE 56)

(define-nettleHW nettle_curve448_mul_g
  (_fun (pub : _pointer) (priv : _pointer) -> _void))

(define-nettleHW nettle_curve448_mul
  (_fun (key : _pointer) (priv : _pointer) (peer : _pointer) -> _void))

(define x448-ok? (get-hw-ok? #"nettle_curve448_mul"))
