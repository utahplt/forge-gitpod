#lang br
;http://www.multigesture.net/articles/how-to-write-an-emulator-chip-8-interpreter/
; http://devernay.free.fr/hacks/chip8/C8TECH10.HTM
; http://mattmik.com/files/chip8/mastering/chip8.html

(define (split-bytes val)
  (cond
    [(zero? val) (list 0)]
    [else
     (define-values (bytes residual)
       (for/fold ([bytes empty][residual val])
                 ([i (in-naturals)]
                  #:break (zero? residual))
         (define m (modulo residual 16))
         (values (cons m bytes) (arithmetic-shift residual -4))))
     bytes]))

(module+ test
  (require rackunit)
  (check-equal? (split-bytes #x2B45) (list #x2 #xB #x4 #x5))
  (check-equal? (split-bytes #xCD) (list #xC #xD))
  (check-equal? (split-bytes #xA) (list #xA))
  (check-equal? (split-bytes #x0) (list #x0)))

(define (join-bytes bytes)
  (for/sum ([b (in-list (reverse bytes))]
            [i (in-naturals)])
           (* b (expt 16 i))))

(module+ test
  (check-equal? #x2B45 (join-bytes (list #x2 #xB #x4 #x5)))
  (check-equal? #xCD (join-bytes (list #xC #xD)))
  (check-equal? #xA (join-bytes (list #xA)))
  (check-equal? #x0 (join-bytes (list #x0))))

(define-macro (define-memory-vector ID [FIELD LENGTH SIZE] ...)
  (with-pattern
   ([(PREFIXED-ID ...)  (prefix-id #'ID "-" #'(FIELD ...))]
    [(PREFIXED-ID-REF ...) (suffix-id #'(PREFIXED-ID ...) "-ref")]
    [(PREFIXED-ID-SET! ...) (suffix-id #'(PREFIXED-ID ...) "-set!")]
    [(FIELD-OFFSET ...) (reverse (cdr
                                  (for/fold ([accum-stxs (list #'0)])
                                            ([len-size-stx (in-list (syntax->list #'((LENGTH SIZE) ...)))])
                                    (cons (with-pattern
                                           ([accum (car accum-stxs)]
                                            [(len size) len-size-stx])
                                           #'(+ (* len size) accum)) accum-stxs))))])
   #'(begin
       (define ID (make-vector (+ (* LENGTH SIZE) ...)))
       (define (PREFIXED-ID-REF idx)
         (unless (< idx LENGTH)
           (raise-argument-error 'PREFIXED-ID-REF (format "index less than field length ~a" LENGTH) idx))
         (join-bytes
          (for/list ([i (in-range SIZE)])
                    (vector-ref ID (+ FIELD-OFFSET i idx)))))
       ...
       (define (PREFIXED-ID-SET! idx val)
         (unless (< idx LENGTH)
           (raise-argument-error 'PREFIXED-ID-SET! (format "index less than field length ~a" LENGTH) idx))
         (unless (< val (expt 16 SIZE))
           (raise-argument-error 'PREFIXED-ID-SET! (format "value less than field size ~a" (expt 16 SIZE)) val))
         (for ([i (in-range SIZE)]
               [b (in-list (split-bytes val))])
              (vector-set! ID (+ FIELD-OFFSET i idx) b))) ...)))

(define-memory-vector chip8 
  [opcode 1 2] ; two bytes
  [memory 4096 1] ; one byte per
  [V 16 1] ; one byte per
  [I 2 1] ; index register, 0x000 to 0xFFF (1.5 bytes)
  [pc 2 1] ; program counter, 0x000 to 0xFFF (1.5 bytes)
  [gfx (* 64 32) 1] ; pixels
  [delay_timer 1 1]
  [sound_timer 1 1]
  [stack 16 2] ; 2 bytes each
  [sp 1 2] ; stack pointer
  [key 16 1]) ; keys

;; Set up render system and register input callbacks
;(setup-graphics chip8)
;(setup-input chip8)

;; Initialize the Chip8 system and load the game into the memory
#;(define (initialize c)
  ;; Initialize registers and memory once
  )

;(initialize chip8)
;(load-game chip8 "pong")


#;(define (emulate-cycle c)
;    // Fetch Opcode
;  // Decode Opcode
;  // Execute Opcode
; 
;  // Update timers

    )

;; Emulation loop
#;(let loop ()
  ;; Emulate one cycle
  (emulate-cycle chip8)
  ;; If the draw flag is set, update the screen
  (when (draw-flag? chip8)
    (draw-graphics chip8))
  
  ;; Store key press state (Press and Release)
  (set-keys chip8)
  (loop))