#lang br
(provide (all-defined-out))

(struct end-program-signal ())
(struct change-line-signal (val))

(struct line-error (msg))