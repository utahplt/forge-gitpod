#lang br
(require (for-syntax racket/string))

(provide define-verbs
         define-thing
         define-place
         define-everywhere
         
         show-current-place
         show-inventory
         
         have-thing?
         take-thing!
         drop-thing!
         thing-state
         set-thing-state!
         
         (except-out (all-from-out br) #%module-begin)
         (rename-out [module-begin #%module-begin]))

;; ============================================================
;; Overall module:

(define-macro (module-begin LINES ...)
  #'(#%module-begin
     LINES ...
     
     (provide do-verb do-place)
     (module+ main
       (parameterize ([cmd-line-mode? #t])
         (do-place)))))


;; ==============================================================
;; Process parse trees from the reader:

(provide txtadv-program)
(define-macro txtadv-program #'module-begin)

(provide verb-section)
(define-macro-cases verb-section
  [(_ ((NAME0 . TRANSITIVE0?) (NAME . _) ... DESC) ...)
   (with-shared-id
    (in-verbs)
    #'(define-verbs in-verbs
        [(NAME0 . TRANSITIVE0?) (= NAME ...) DESC] ...))])

(provide everywhere-section)
(define-macro (everywhere-section [ID DESC] ...)
  #'(define-everywhere everywhere-actions
      ([ID DESC] ...)))

(provide things-section)
(define-macro (things-section (THINGNAME (ACTIONNAME ACTIONDESC) ...) ...)
  #'(begin (define-thing THINGNAME [ACTIONNAME ACTIONDESC] ...) ...))

(provide places-section)
(define-macro (places-section (PLACE-ID PLACE-DESC [PLACE-ITEM ...] [ACTIONNAME ACTIONDESC] ...) ...)
  #'(begin (define-place PLACE-ID PLACE-DESC [PLACE-ITEM ...] ([ACTIONNAME ACTIONDESC] ...)) ...))


;; todo: consolidate the game-starters.
;; `start-game-at` works with s-exp language,
;; `start-section` works with text lang. 
(provide start-game-at)
(define-macro (start-game-at WHERE)
  #'(init-game WHERE
               in-verbs
               everywhere-actions))

(provide start-section)
(define-macro (start-section WHERE)
  (with-shared-id
   (in-verbs)
   #'(init-game WHERE
                in-verbs
                everywhere-actions)))

;; ============================================================
;; Model:

;; Elements of the world:
(struct verb (aliases       ; list of symbols
              desc          ; string
              transitive?) #:transparent) ; boolean
(struct thing (name         ; symbol
               [state #:mutable] ; any value
               actions) #:transparent)    ; list of verb--thunk pairs

(struct place (desc         ; string
               [things #:mutable] ; list of things
               actions) #:transparent)    ; list of verb--thunk pairs

(define action-verb car)
(define action-response cdr)

;; Tables mapping names<->things for save and load
(define names (make-hash))
(define elements (make-hash))

(define (record-element! name val)
  (hash-set! names name val)
  (hash-set! elements val name))

(define (name->element name) (hash-ref names name #f))
(define (element->name obj) (hash-ref elements obj #f))

;; ============================================================
;; Macros for constructing and registering elements:

(define-macro (define-verbs ALL-ID [(ID . MAYBE-UNDERSCORE) SPEC ...] ...)
  #'(begin
      (define-one-verb (ID . MAYBE-UNDERSCORE) SPEC ...) ...
      (record-element! 'ID ID) ...
      (define ALL-ID (list ID ...))))


;; todo: the underscore arguments in cases 2 & 4 should be literal underscores, not wildcards
(define-macro (define-one-verb (ID . MAYBE-UNDERSCORE) . REST)
  (with-pattern
   ([TRANSITIVE? (equal? '("_") (syntax->datum #'MAYBE-UNDERSCORE))]
    [VERB-ARGS (syntax-case #'REST ()
                 [((= ALIAS ...) DESC)
                  #'((list 'ID 'ALIAS ...) DESC TRANSITIVE?)]
                 [else
                  #'((list 'ID) (symbol->string 'ID) TRANSITIVE?)])])
   #'(define ID (verb . VERB-ARGS))))


(define-macro (define-thing ID [VERB-ARG EXPR] ...)
  #'(begin
      (define ID
        (thing 'ID #f (list (cons VERB-ARG (λ () EXPR)) ...)))
      (record-element! 'ID ID)))


(define-macro (define-place ID DESC (THING-ARG ...) ([VERB-ARG EXPR] ...))
  #'(begin
      (define ID (place DESC
                        (list THING-ARG ...)
                        (list (cons VERB-ARG (λ () EXPR)) ...)))
      (record-element! 'ID ID)))


(define-macro (define-everywhere ID ([VERB-ARG EXPR] ...))
  #'(define ID (list (cons VERB-ARG (λ () EXPR)) ...)))

;; ============================================================
;; Game state

(define cmd-line-mode? (make-parameter #f))

;; Initialized on startup:
(define game-verbs null)          ; list of verbs
(define everywhere-actions null) ; list of verb--thunk pairs

;; Things carried by the player:
(define player-inventory null) ; list of things

;; Current location:
(define current-place #f) ; place (or #f until started)

;; Fuctions to be used by verb responses:
(define (have-thing? thing)
  (memq thing player-inventory))
(define (take-thing! thing) 
  (set-place-things! current-place (remq thing (place-things current-place)))
  (set! player-inventory (cons thing player-inventory)))
(define (drop-thing! thing) 
  (set-place-things! current-place (cons thing (place-things current-place)))
  (set! player-inventory (remq thing player-inventory)))

;; ============================================================
;; Game execution

;; Show the player the current place, then get a command:
(define (do-place)
  (show-current-place)
  (when (cmd-line-mode?) (do-verb)))

;; Show the current place:
(define (show-current-place)
  (printf "~a\n" (place-desc current-place))
  (for-each
   (λ (thing) (printf "There is a ~a here.\n" (thing-name thing)))
   (place-things current-place)))

;; Get and handle a command:

(define (get-line)
  (printf "> ")
  (flush-output)
  (read-line))

(define (do-verb [line (and (cmd-line-mode?) (get-line))])
  (define input (if (eof-object? line)
                    '(quit)
                    (let ([port (open-input-string line)])
                      (for/list ([v (in-port read port)]) v))))  
  (if (and (list? input)
           (andmap symbol? input)
           (<= 1 (length input) 2))
      (let* ([verb (car input)]
             [response
              (case (length input)
                [(2) (handle-transitive-verb verb (cadr input))]
                [(1) (handle-intransitive-verb verb)])]
             [result (response)])
        (cond
          [(place? result)
           (set! current-place result)
           (do-place)]
          [(string? result)
           (printf "~a\n" result)
           (when (cmd-line-mode?) (do-verb))]
          [else (when (cmd-line-mode?) (do-verb))]))
      (begin
        (printf "I don't undertand what you mean.\n")
        (when (cmd-line-mode?) (do-verb)))))

;; Handle an intransitive-verb command:
(define (handle-intransitive-verb verb)
  (or
   (find-verb verb (place-actions current-place))
   (find-verb verb everywhere-actions)
   (using-verb 
    verb game-verbs
    (λ (verb)
      (λ () (if (verb-transitive? verb)
                (format "~a what?" (string-titlecase (verb-desc verb)))
                (format "Can't ~a here." (verb-desc verb))))))
   (λ () (format "I don't know how to ~a." verb))))

;; Handle a transitive-verb command:
(define (handle-transitive-verb verb-in obj)
  (or (using-verb 
       verb-in game-verbs
       (λ (verb)
         (and 
          (verb-transitive? verb)
          (cond
            [(for/first ([thing (in-list (append (place-things current-place)
                                                 player-inventory))]
                         #:when (eq? (thing-name thing) obj))
                        thing)
             => (λ (thing)
                  (or (find-verb verb-in (thing-actions thing))
                      (λ ()
                        (format "Don't know how to ~a ~a."
                                (verb-desc verb) obj))))]
            [else
             (λ () (format "There's no ~a here to ~a." obj 
                           (verb-desc verb)))]))))
      (λ () (format "I don't know how to ~a ~a." verb-in obj))))

;; Show what the player is carrying:
(define (show-inventory)
  (printf "You have")
  (if (zero? (length player-inventory))
      (printf " no items.")
      (for-each (λ (thing)
                  (printf "\n  a ~a" (thing-name thing)))
                player-inventory))
  (printf "\n"))

;; Look for a command match in a list of verb--response pairs,
;; and returns the response thunk if a match is found:
(define (find-verb cmd actions)
  (for/first ([action (in-list actions)]
              #:when (memq cmd (verb-aliases (action-verb action))))
             (action-response action)))

;; Looks for a command in a list of verbs, and
;; applies `success-func' to the verb if one is found:
(define (using-verb cmd verbs success-func)
  (for/first ([verb (in-list verbs)]
              #:when (memq cmd (verb-aliases verb)))
             (success-func verb)))


;; ============================================================
;; To go:

(define (init-game in-place
                   in-verbs
                   in-everywhere-actions)
  (set! current-place in-place)
  (set! game-verbs in-verbs)
  (set! everywhere-actions in-everywhere-actions))
