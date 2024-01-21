1771
((3) 0 () 1 ((q lib "predicates/main.rkt")) () (h ! (equal) ((c def c (c (? . 0) q and?*)) q (260 . 3)) ((c def c (c (? . 0) q and?)) q (0 . 3)) ((c def c (c (? . 0) q >?)) q (780 . 3)) ((c def c (c (? . 0) q first?)) q (1404 . 3)) ((c def c (c (? . 0) q fourth?)) q (1736 . 3)) ((c def c (c (? . 0) q equal??)) q (596 . 3)) ((c def c (c (? . 0) q nonsingular-list?)) q (1078 . 3)) ((c def c (c (? . 0) q all?)) q (1937 . 3)) ((c def c (c (? . 0) q eqv??)) q (534 . 3)) ((c def c (c (? . 0) q while?)) q (2588 . 4)) ((c def c (c (? . 0) q eq??)) q (473 . 3)) ((c def c (c (? . 0) q or?*)) q (367 . 3)) ((c def c (c (? . 0) q listof?)) q (2021 . 3)) ((c def c (c (? . 0) q length<?)) q (1316 . 3)) ((c def c (c (? . 0) q list-with-head?)) q (2113 . 3)) ((c def c (c (? . 0) q third?)) q (1621 . 3)) ((c def c (c (? . 0) q without-truthiness)) q (3088 . 3)) ((c def c (c (? . 0) q do-until?)) q (2924 . 4)) ((c def c (c (? . 0) q true?)) q (3038 . 3)) ((c def c (c (? . 0) q not?)) q (177 . 3)) ((c def c (c (? . 0) q <?)) q (719 . 3)) ((c def c (c (? . 0) q length>?)) q (1140 . 3)) ((c def c (c (? . 0) q unless?)) q (2476 . 4)) ((c def c (c (? . 0) q if?)) q (2213 . 5)) ((c def c (c (? . 0) q =?)) q (660 . 3)) ((c def c (c (? . 0) q do-while?)) q (2810 . 4)) ((c def c (c (? . 0) q or?)) q (89 . 3)) ((c def c (c (? . 0) q length=?)) q (1228 . 3)) ((c def c (c (? . 0) q >=?)) q (903 . 3)) ((c def c (c (? . 0) q not-null?)) q (965 . 3)) ((c def c (c (? . 0) q in-range?)) q (3149 . 5)) ((c def c (c (? . 0) q rest?)) q (1852 . 3)) ((c def c (c (? . 0) q nonempty-list?)) q (1019 . 3)) ((c def c (c (? . 0) q when?)) q (2366 . 4)) ((c def c (c (? . 0) q until?)) q (2699 . 4)) ((c def c (c (? . 0) q <=?)) q (841 . 3)) ((c def c (c (? . 0) q second?)) q (1505 . 3))))
procedure
(and? pred ...+) -> (-> any? boolean?)
  pred : (-> any? boolean?)
procedure
(or? pred ...+) -> (-> any? boolean?)
  pred : (-> any? boolean?)
procedure
(not? pred) -> (-> any? boolean?)
  pred : (-> any? boolean?)
procedure
(and?* pred ...+) -> (->* () () #:rest any? boolean?)
  pred : (-> any? boolean?)
procedure
(or?* pred ...+) -> (->* () () #:rest any? boolean?)
  pred : (-> any? boolean?)
procedure
(eq?? v) -> (-> any? boolean?)
  v : any?
procedure
(eqv?? v) -> (-> any? boolean?)
  v : any?
procedure
(equal?? v) -> (-> any? boolean?)
  v : any?
procedure
(=? v) -> (-> any? boolean?)
  v : any?
procedure
(<? v) -> (-> real? boolean?)
  v : real?
procedure
(>? v) -> (-> real? boolean?)
  v : real?
procedure
(<=? v) -> (-> real? boolean?)
  v : real?
procedure
(>=? v) -> (-> real? boolean?)
  v : real?
procedure
(not-null? v) -> boolean?
  v : any?
procedure
(nonempty-list? v) -> boolean?
  v : any?
procedure
(nonsingular-list? v) -> boolean?
  v : any?
procedure
(length>? n) -> (-> list? boolean?)
  n : exact-nonnegative-integer?
procedure
(length=? n) -> (-> list? boolean?)
  n : exact-nonnegative-integer?
procedure
(length<? n) -> (-> list? boolean?)
  n : exact-nonnegative-integer?
procedure
(first? pred ...+) -> (-> nonempty-list? boolean?)
  pred : (-> any? boolean?)
procedure
(second? pred ...+) -> (-> (and? list? (length>? 1)) boolean?)
  pred : (-> any? boolean?)
procedure
(third? pred ...+) -> (-> (and? list? (length>? 2)) boolean?)
  pred : (-> any? boolean?)
procedure
(fourth? pred ...+) -> (-> (and? list? (length>? 3)) boolean?)
  pred : (-> any? boolean?)
procedure
(rest? pred) -> (-> list? boolean?)
  pred : (-> any? boolean?)
procedure
(all? pred) -> (-> list? boolean?)
  pred : (-> any? boolean?)
procedure
(listof? pred ...+) -> (-> any? boolean?)
  pred : (-> any? boolean?)
procedure
(list-with-head? pred ...+) -> (-> any? boolean?)
  pred : (-> any? boolean?)
procedure
(if? pred f [g]) -> (-> any? any?)
  pred : (-> any? boolean?)
  f : (-> any? any?)
  g : (-> any? any?) = identity
procedure
(when? pred f) -> (-> any? any?)
  pred : (-> any? boolean?)
  f : (-> any? any?)
procedure
(unless? pred f) -> (-> any? any?)
  pred : (-> any? boolean?)
  f : (-> any? any?)
procedure
(while? pred f) -> (-> any? any?)
  pred : (-> any? boolean?)
  f : (-> any? any?)
procedure
(until? pred f) -> (-> any? any?)
  pred : (-> any? boolean?)
  f : (-> any? any?)
procedure
(do-while? pred f) -> (-> any? any?)
  pred : (-> any? boolean?)
  f : (-> any? any?)
procedure
(do-until? pred f) -> (-> any? any?)
  pred : (-> any? boolean?)
  f : (-> any? any?)
procedure
(true? v) -> boolean?
  v : any?
procedure
(without-truthiness f) -> proc?
  f : proc?
procedure
(in-range? low high [exclusive?]) -> (-> any? boolean?)
  low : real?
  high : real?
  exclusive? : boolean? = #f
