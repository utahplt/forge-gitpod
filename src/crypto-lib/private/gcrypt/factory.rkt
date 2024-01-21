;; Copyright 2012-2018 Ryan Culpepper
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
(require racket/class
         racket/match
         "../common/interfaces.rkt"
         "../common/catalog.rkt"
         "../common/common.rkt"
         "../common/factory.rkt"
         "ffi.rkt"
         "digest.rkt"
         "cipher.rkt"
         "pkey.rkt"
         "kdf.rkt")
(provide gcrypt-factory)

;; ----------------------------------------

(define digests
  `(;;[Name     AlgId               BlockSize]
    (sha1       ,GCRY_MD_SHA1       64)
    (md2        ,GCRY_MD_MD2        16)
    (md5        ,GCRY_MD_MD5        64)
    (sha224     ,GCRY_MD_SHA224     64)
    (sha256     ,GCRY_MD_SHA256     64)
    (sha384     ,GCRY_MD_SHA384     128)
    (sha512     ,GCRY_MD_SHA512     128)
    (md4        ,GCRY_MD_MD4        64)
    (whirlpool  ,GCRY_MD_WHIRLPOOL  64)
    (sha3-224   ,GCRY_MD_SHA3_224   144)
    (sha3-256   ,GCRY_MD_SHA3_256   136)
    (sha3-384   ,GCRY_MD_SHA3_384   104)
    (sha3-512   ,GCRY_MD_SHA3_512   72)
    ;; Fail on gcry_md_hash_buffer; need ctx and gcry_md_extract
    ;; (shake128   ,GCRY_MD_SHAKE128   168)
    ;; (shake256   ,GCRY_MD_SHAKE256   136)
    (blake2b-512 ,GCRY_MD_BLAKE2B_512 128)
    (blake2b-384 ,GCRY_MD_BLAKE2B_384 128)
    (blake2b-256 ,GCRY_MD_BLAKE2B_256 128)
    (blake2b-160 ,GCRY_MD_BLAKE2B_160 128)
    (blake2s-256 ,GCRY_MD_BLAKE2S_256 64)
    (blake2s-224 ,GCRY_MD_BLAKE2S_224 64)
    (blake2s-160 ,GCRY_MD_BLAKE2S_160 64)
    (blake2s-128 ,GCRY_MD_BLAKE2S_128 64)
    #|
    (ripemd160  ,GCRY_MD_RMD160     64) ;; Doesn't seem to be available!
    (haval      ,GCRY_MD_HAVAL      128)
    (tiger      ,GCRY_MD_TIGER      #f) ;; special old GnuPG-compat output order
    (tiger1     ,GCRY_MD_TIGER1     64)
    (tiger2     ,GCRY_MD_TIGER2     64)
    |#))

;; ----------------------------------------

(define block-ciphers
  `(;;[Name   ([KeySize AlgId] ...)]
    [cast128  ([128 ,GCRY_CIPHER_CAST5])]
    [blowfish ([128 ,GCRY_CIPHER_BLOWFISH])]
    [aes      ([128 ,GCRY_CIPHER_AES]
               [192 ,GCRY_CIPHER_AES192]
               [256 ,GCRY_CIPHER_AES256])]
    [twofish  ([128 ,GCRY_CIPHER_TWOFISH128]
               [256 ,GCRY_CIPHER_TWOFISH])]
    [serpent  ([128 ,GCRY_CIPHER_SERPENT128]
               [192 ,GCRY_CIPHER_SERPENT192]
               [256 ,GCRY_CIPHER_SERPENT256])]
    [camellia ([128 ,GCRY_CIPHER_CAMELLIA128]
               [192 ,GCRY_CIPHER_CAMELLIA192]
               [256 ,GCRY_CIPHER_CAMELLIA256])]
    [des      ([64  ,GCRY_CIPHER_DES])] ;; takes key as 64 bits, high bits ignored
    [des-ede3 ([192 ,GCRY_CIPHER_3DES])] ;; takes key as 192 bits, high bits ignored
    [idea     ([128 ,GCRY_CIPHER_IDEA])]
    ))

(define stream-ciphers
  `(;;[Name ([KeySize AlgId] ...) Mode]
    [rc4        ,GCRY_CIPHER_ARCFOUR            ,GCRY_CIPHER_MODE_STREAM]
    [salsa20    ([256 ,GCRY_CIPHER_SALSA20])    ,GCRY_CIPHER_MODE_STREAM]
    [salsa20r12 ([256 ,GCRY_CIPHER_SALSA20R12]) ,GCRY_CIPHER_MODE_STREAM]
    [chacha20   ([256 ,GCRY_CIPHER_CHACHA20])   ,GCRY_CIPHER_MODE_STREAM]
    [chacha20-poly1305 ([256 ,GCRY_CIPHER_CHACHA20]) ,GCRY_CIPHER_MODE_POLY1305]))

(define block-modes
  `(;;[Mode ModeId]
    [ecb    ,GCRY_CIPHER_MODE_ECB]
    [cbc    ,GCRY_CIPHER_MODE_CBC]
    [cfb    ,GCRY_CIPHER_MODE_CFB]
    [ofb    ,GCRY_CIPHER_MODE_OFB]
    [ctr    ,GCRY_CIPHER_MODE_CTR]
    ;; [ccm ,GCRY_CIPHER_MODE_CCM]
    [gcm    ,GCRY_CIPHER_MODE_GCM]
    [ocb    ,GCRY_CIPHER_MODE_OCB]
    ;; [xts ,GCRY_CIPHER_MODE_XTS]
    ))

;; GCrypt does not seem to have a function to test whether a cipher
;; mode is supported, so try using it and catch the error.
(define (mode-ok? mode)
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (begin (gcry_cipher_close (gcry_cipher_open GCRY_CIPHER_AES mode 0)) #t)))
(define gcm-ok? (mode-ok? GCRY_CIPHER_MODE_GCM))
(define ocb-ok? (mode-ok? GCRY_CIPHER_MODE_OCB))

(define (spec-ok? spec)
  ;; Additional mode compat checks
  (match-define (list cipher mode) spec)
  (and (case mode
         [(gcm) gcm-ok?]
         [(ocb) ocb-ok?]
         [else #t])
       (case mode
         [(ccm gcm ocb xts) (memq cipher '(aes twofish serpent camellia))]
         [else #t])))

;; ----------------------------------------

(define gcrypt-factory%
  (class* factory-base% (factory<%>)
    (inherit print-avail get-digest get-cipher)
    (super-new [ok? gcrypt-ok?] [load-error gcrypt-load-error])

    (define/override (get-name) 'gcrypt)
    (define/override (get-version)
      (version->list (gcry_check_version #f)))

    (define/override (-get-digest info)
      (define spec (send info get-spec))
      (match (assq spec digests)
        [(list _ algid blocksize)
         (and (gcry_md_test_algo algid)
              (new gcrypt-digest-impl%
                   (info info)
                   (factory this)
                   (md algid)
                   (blocksize blocksize)))]
        [_ #f]))

    (define/override (-get-cipher info)
      (define spec (send info get-spec))
      (define (algid->cipher algid mode-id)
        (and (gcry_cipher_test_algo algid)
             (new gcrypt-cipher-impl%
                  (info info)
                  (factory this)
                  (cipher algid)
                  (mode mode-id))))
      (define (multi->cipher keylens+algids mode-id)
        (cond [(list? keylens+algids)
               (for/list ([keylen+algid (in-list keylens+algids)])
                 (cons (quotient (car keylen+algid) 8)
                       (algid->cipher (cadr keylen+algid) mode-id)))]
              [else (let ([algid keylens+algids])
                      (algid->cipher algid mode-id))]))
      (define (search ciphers modes)
        (match (assq (cipher-spec-algo spec) ciphers)
          [(list _ keylens+algids mode-id)
           (multi->cipher keylens+algids mode-id)]
          [(list _ keylens+algids)
           (match (assq (cipher-spec-mode spec) modes)
             [(list _ mode-id)
              (multi->cipher keylens+algids mode-id)]
             [_ #f])]
          [_ #f]))
      (and (spec-ok? spec)
           (or (search block-ciphers block-modes)
               (search stream-ciphers '()))))

    (define/override (-get-pk-reader)
      (new gcrypt-read-key% (factory this)))

    (define/override (-get-pk spec)
      (case spec
        [(rsa) (new gcrypt-rsa-impl% (factory this))]
        [(dsa) (new gcrypt-dsa-impl% (factory this))]
        [(ec)  (new gcrypt-ec-impl%  (factory this))]
        [(eddsa) (and ed25519-ok? (new gcrypt-eddsa-impl% (factory this)))]
        [(ecx) (and x25519-ok? (new gcrypt-ecx-impl% (factory this)))]
        [else #f]))

    (define/override (-get-kdf spec)
      (match spec
        [(list 'pbkdf2 'hmac di-spec)
         (and (version>=? (get-version) '(1 5))
              (let ([di (get-digest di-spec)])
                (and di (new gcrypt-pbkdf2-impl% (spec spec) (factory this) (di di)))))]
        ['scrypt
         (and (version>=? (get-version) '(1 6))
              (new gcrypt-scrypt-impl% (spec spec) (factory this)))]
        [_ (super -get-kdf spec)]))

    ;; ----

    (define/override (info key)
      (case key
        [(all-ec-curves) gcrypt-curves]
        [(all-eddsa-curves) (if ed25519-ok? '(ed25519) '())]
        [(all-ecx-curves) (if x25519-ok? '(x25519) '())]
        [else (super info key)]))

    (define/override (print-lib-info)
      (super print-lib-info)
      (printf " version string: ~s\n" (gcry_check_version #f)))
    ))

(define gcrypt-factory (new gcrypt-factory%))
