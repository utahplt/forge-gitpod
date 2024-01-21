#lang forge

/*$
(pre-declare-sig abstract-cat)
(pre-declare-sig kitty #:extends abstract-cat)
(pre-declare-sig kittyBacon #:extends abstract-cat)

(declare-sig abstract-cat ((friends abstract-cat)))

(declare-sig kitty #:extends abstract-cat)

(declare-one-sig kittyBacon #:extends abstract-cat)

(pred no-self-loops (no (& iden friends)))

(pred two-way-street (= friends (~ friends)))

(run "kittyBacon" (no-self-loops two-way-street) ((kitty 2 3)))
*/