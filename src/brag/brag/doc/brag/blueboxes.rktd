2257
((3) 0 () 4 ((q lib "brag/support.rkt") (q lib "brag/main.rkt") (q 1064 . 11) (q 1482 . 8)) () (h ! (equal) ((c def c (c (? . 1) q parse-to-datum)) q (183 . 5)) ((c def c (c (? . 0) q apply-port-proc)) q (1806 . 4)) ((c form c (c (? . 0) q ::)) q (2601 . 2)) ((c def c (c (? . 0) q struct:exn:fail:parsing)) c (? . 3)) ((c form c (c (? . 1) q make-rule-parser)) q (363 . 2)) ((c form c (c (? . 0) q :-)) q (2666 . 2)) ((c form c (c (? . 0) q :~)) q (2687 . 2)) ((c def c (c (? . 0) q token-struct-column)) c (? . 2)) ((c def c (c (? . 1) q all-token-types)) q (395 . 2)) ((c form c (c (? . 0) q :=)) q (2502 . 2)) ((c form c (c (? . 0) q :**)) q (2551 . 2)) ((c form c (c (? . 0) q :*)) q (2439 . 2)) ((c form c (c (? . 0) q :?)) q (2481 . 2)) ((c def c (c (? . 0) q trim-ends)) q (2307 . 5)) ((c def c (c (? . 0) q token-struct?)) c (? . 2)) ((c def c (c (? . 1) q parse)) q (0 . 5)) ((c form c (c (? . 0) q :>=)) q (2526 . 2)) ((c def c (c (? . 0) q token-struct-line)) c (? . 2)) ((c form c (c (? . 0) q :&)) q (2645 . 2)) ((c def c (c (? . 0) q token-struct-skip?)) c (? . 2)) ((c def c (c (? . 0) q token-struct-val)) c (? . 2)) ((c def c (c (? . 0) q exn:fail:parsing-message)) c (? . 3)) ((c def c (c (? . 0) q exn:fail:parsing?)) c (? . 3)) ((c form c (c (? . 0) q from/to)) q (2741 . 2)) ((c form c (c (? . 0) q :/)) q (2708 . 2)) ((c def c (c (? . 0) q make-token-struct)) c (? . 2)) ((c def c (c (? . 0) q token-struct-span)) c (? . 2)) ((c def c (c (? . 0) q apply-tokenizer-maker)) q (2092 . 5)) ((c form c (c (? . 0) q :seq)) q (2622 . 2)) ((c def c (c (? . 0) q exn:fail:parsing)) c (? . 3)) ((c form c (c (? . 0) q :+)) q (2460 . 2)) ((c def c (c (? . 0) q token)) q (438 . 15)) ((c def c (c (? . 0) q token-struct-position)) c (? . 2)) ((c def c (c (? . 0) q apply-lexer)) q (1950 . 4)) ((c def c (c (? . 0) q token-struct)) c (? . 2)) ((c form c (c (? . 0) q :or)) q (2579 . 2)) ((c form c (c (? . 0) q from/stop-before)) q (2771 . 2)) ((c def c (c (? . 0) q exn:fail:parsing-continuation-marks)) c (? . 3)) ((c def c (c (? . 0) q token-struct-type)) c (? . 2)) ((c def c (c (? . 0) q exn:fail:parsing-srclocs)) c (? . 3)) ((c def c (c (? . 0) q struct:token-struct)) c (? . 2)) ((c def c (c (? . 0) q make-exn:fail:parsing)) c (? . 3))))
procedure
(parse [source-path] token-source) -> syntax?
  source-path : any/c = #f
  token-source : (or/c (sequenceof token)
                       (-> token))
procedure
(parse-to-datum [source] token-source) -> list?
  source : any/c = #f
  token-source : (or/c (sequenceof token)
                       (-> token))
syntax
(make-rule-parser name)
value
all-token-types : (setof symbol?)
procedure
(token  type                    
       [val                     
        #:line line             
        #:column column         
        #:position position     
        #:span span             
        #:skip? skip?])     -> token-struct?
  type : (or/c string? symbol?)
  val : any/c = #f
  line : (or/c exact-positive-integer? #f) = #f
  column : (or/c exact-nonnegative-integer? #f) = #f
  position : (or/c exact-positive-integer? #f) = #f
  span : (or/c exact-nonnegative-integer? #f) = #f
  skip? : boolean? = #f
struct
(struct token-struct (type val position line column span skip?)
    #:extra-constructor-name make-token-struct
    #:transparent)
  type : symbol?
  val : any/c
  position : (or/c exact-positive-integer? #f)
  line : (or/c exact-nonnegative-integer? #f)
  column : (or/c exact-positive-integer? #f)
  span : (or/c exact-nonnegative-integer? #f)
  skip? : boolean?
struct
(struct exn:fail:parsing exn:fail (message
                                   continuation-marks
                                   srclocs)
    #:extra-constructor-name make-exn:fail:parsing)
  message : string?
  continuation-marks : continuation-mark-set?
  srclocs : (listof srcloc?)
procedure
(apply-port-proc proc [port]) -> list?
  proc : procedure?
  port : (or/c string? input-port?) = (current-input-port)
procedure
(apply-lexer lexer [port]) -> list?
  lexer : procedure?
  port : (or/c string? input-port?) = (current-input-port)
procedure
(apply-tokenizer-maker  tokenizer-maker     
                       [port])          -> list?
  tokenizer-maker : procedure?
  port : (or/c string? input-port?) = (current-input-port)
procedure
(trim-ends left-str str right-str) -> string?
  left-str : string?
  str : string?
  right-str : string?
syntax
(:* re ...)
syntax
(:+ re ...)
syntax
(:? re ...)
syntax
(:= n re ...)
syntax
(:>= n re ...)
syntax
(:** n m re ...)
syntax
(:or re ...)
syntax
(:: re ...)
syntax
(:seq re ...)
syntax
(:& re ...)
syntax
(:- re ...)
syntax
(:~ re ...)
syntax
(:/ char-or-string ...)
syntax
(from/to open close)
syntax
(from/stop-before open close)
