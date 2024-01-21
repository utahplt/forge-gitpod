#lang at-exp br/quicklang
(require brag/support racket/runtime-path racket/file)

(module reader syntax/module-reader
  pl-checklist-lang-maker/main)

(provide (rename-out [plc-mb #%module-begin]))

(define-macro (plc-mb . ARGS)
  #'(#%module-begin
     (module+ main
       (displayln "My new #lang technique is unstoppable"))
     (module+ reader
       (provide (rename-out [plc-rs read-syntax])))))


(define (plc-rs path ip)
  (strip-context
   (with-syntax ([PT (parse (λ () (plc-lexer ip)))])
     #'(module _ (submod pl-checklist-lang-maker expander)
         PT))))

(define plc-lexer
  (lexer
   [whitespace (token 'WHITE #:skip? #t)]
   [(:: "(" (:? " ") ")") (token 'VALUE #f)]
   [(:: "(" any-char ")") (token 'VALUE #t)]
   [(:+ alphabetic punctuation) (token 'WORD lexeme)]))


@module/lang[parser]{
 #lang brag

 plc-top : (/WORD | plc-field)*
 /plc-field : VALUE WORD
}

(require 'parser)

(module+ expander
  (provide #%module-begin plc-top))

(define-runtime-path checklist "checklist.txt")

(define-macro-cases plc-top
  [(_) #'(displayln (string-append "\n" (file->string checklist)))]
  [(_ (VAL NAME) ...)
   #'(let ([adjectives (map cdr (filter car (list '(VAL . NAME) ...)))])
       (stringify adjectives))])

(define (stringify adjectives)
  (displayln "")
  (display
   (if (pair? adjectives)
       (string-append
        "You appear to be proposing a new "
        (string-join adjectives ", ")
        " language. "
        (if (< (length adjectives) 6)
            "\n\nThat will never work."
            "\n\nNow you're showing some ambition! Welcome to Racket School!"))
       "No language proposed. You are in danger of flunking out.")))

