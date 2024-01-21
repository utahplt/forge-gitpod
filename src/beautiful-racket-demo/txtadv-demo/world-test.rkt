#lang racket
(require rackunit)
(require "world.rkt")

(check-equal? (with-output-to-string (λ _ (do-place)))
              "You're standing in a meadow. There is a house to the north.\n")

(define-syntax-rule (check-cmd? cmd result)
  (check-equal? (with-output-to-string (λ _ (do-verb cmd))) result))

(check-cmd?
 "s"
 "You're in a desert. There is nothing for miles around.\nThere is a cactus here.\nThere is a key here.\n")

(check-cmd?
 "get cactus"
 "Ouch!\n")

(check-cmd?
 "get key"
 "You now have the key.\n")

(check-cmd?
 "n"
 "You're standing in a meadow. There is a house to the north.\n")

(check-cmd?
 "n"
 "You are standing in front of a house.\nThere is a door here.\n")

(check-cmd?
 "open door"
 "The door is now unlocked and open.\n")

(check-cmd?
 "enter"
 "You're in the house.\nThere is a trophy here.\n")

(check-cmd?
 "get trophy"
 "You win!\n")