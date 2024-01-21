#lang br
(require (for-syntax racket/list sugar/debug))
(provide (except-out (all-from-out br) #%module-begin)
         (rename-out [quicklang-mb #%module-begin])
         (for-syntax (all-from-out sugar/debug)))

(define-macro (quicklang-mb . EXPRS)
  #'(#%module-begin
     (provide #%top #%app #%datum #%top-interaction)
     . EXPRS))

(module reader racket/base
  (provide (rename-out
            [br-read read]
            [br-read-syntax read-syntax]
            [at:get-info get-info]))

  (module at-reader syntax/module-reader
    #:language 'br/quicklang
    #:info br-get-info
    #:read at:read
    #:read-syntax at:read-syntax
    (require br/get-info (prefix-in at: scribble/reader)))

  (require debug/reader (prefix-in at: 'at-reader))

  #|
Use wrap-reader on the whole-module read function that would be exported
by the reader module, not the single-expression read function like
at:read-syntax that you deal with within syntax/module-reader or normal use.
|#

  (define br-read (wrap-reader at:read))
  (define br-read-syntax (wrap-reader at:read-syntax)))