#lang racket/base

(require (only-in racket/function thunk)
         (only-in racket/list first rest empty empty? flatten)
         (only-in racket/pretty pretty-print)
         (prefix-in @ (only-in racket/base display max min -)) 
         (prefix-in @ racket/set)
         (prefix-in @ (only-in racket/contract ->))
         (only-in racket/contract define/contract))
(require syntax/parse/define
         syntax/srcloc)
(require (for-syntax racket/base racket/syntax syntax/srcloc syntax/strip-context
                     (only-in racket/pretty pretty-print)))

(require forge/shared)
(require forge/lang/ast 
         forge/lang/bounds 
         forge/breaks)
(require (only-in forge/lang/reader [read-syntax read-surface-syntax]))
(require forge/server/eval-model)
(require forge/server/forgeserver)
(require forge/translate-to-kodkod-cli
         forge/translate-from-kodkod-cli
         forge/sigs-structs
         forge/evaluator
         (prefix-in tree: forge/lazy-tree)
         forge/send-to-kodkod)
(require (only-in forge/lang/alloy-syntax/parser [parse forge-lang:parse])
         (only-in forge/lang/alloy-syntax/tokenizer [make-tokenizer forge-lang:make-tokenizer]))
(require (only-in forge/sigs-functional
                  make-sig
                  make-relation
                  make-inst
                  run-from-state
                  ; the next ones are not used in this file
                  ; but are required so that they can be provided,
                  ; allowing users to use them in forge/core programs
                  make-run
                  check-from-state
                  make-check
                  test-from-state
                  make-test))
(require forge/choose-lang-specific)

; Commands
(provide sig relation fun const pred inst with)
(provide run check test example display execute)
(provide instance-diff solution-diff evaluate)

; Instance analysis functions
(provide is-unsat? is-sat?)

; export AST macros and struct definitions (for matching)
; Make sure that nothing is double-provided
(provide (all-from-out forge/lang/ast))

; Racket stuff
(provide let quote)

; Technical stuff
(provide set-verbosity VERBOSITY_LOW VERBOSITY_HIGH)
(provide set-path!)
(provide set-option!)
(define (set-path! path) #f)

; Data structures
(provide (prefix-out forge: (struct-out Sig))
         (prefix-out forge: (struct-out Relation))
         (prefix-out forge: (struct-out Range))
         (prefix-out forge: (struct-out Scope))
         (prefix-out forge: (struct-out Bound))
         (prefix-out forge: (struct-out Options))
         (prefix-out forge: (struct-out State))
         (prefix-out forge: (struct-out Run-spec))
         (prefix-out forge: (struct-out Run))         
         (prefix-out forge: (struct-out sbound)))

; Let forge/core work with the model tree without having to require helpers
; Don't prefix with tree:, that's already been done when importing
(provide (all-from-out forge/lazy-tree))

(provide (prefix-out forge: (all-from-out forge/sigs-structs)))

; Export these from structs without forge: prefix
(provide implies iff <=> ifte int>= int<= ni != !in !ni <: :>)
(provide Int succ min max)

; Export these from sigs-functional
; so that they can be used for scripting in forge/core
(provide make-sig
         make-relation
         make-inst
         run-from-state
         make-run
         check-from-state
         make-check
         test-from-state
         make-test)

; Export everything for doing scripting
(provide (prefix-out forge: (all-defined-out)))
(provide (prefix-out forge: (struct-out bound)))
(provide (prefix-out forge: relation-name))

(provide (prefix-out forge: curr-state)
         (prefix-out forge: update-state!))

(provide (struct-out Sat)
         (struct-out Unsat))

(provide (for-syntax add-to-execs))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; State Updaters  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; state-add-runmap :: State, Symbol, Run -> State
(define (state-add-runmap state name r)
  (struct-copy State state
               [runmap (hash-set (State-runmap state) name r)]))

; state-add-sig :: State, Symbol, Sig, (Symbol | #f) -> State
; Adds a new Sig to the given State; if new Sig extends some
; other Sig, then updates that Sig with extension.
(define (state-add-sig state name new-sig extends)
  (when (member name (State-sig-order state))
    (raise-user-error (format "tried to add sig ~a, but it already existed" name)))
  ;(define new-sig (Sig name rel one abstract extends))
  (when (and extends (not (member extends (State-sig-order state))))
    (raise-user-error "Can't extend nonexistent sig."))

  (define new-state-sigs (hash-set (State-sigs state) name new-sig))
  (define new-state-sig-order (append (State-sig-order state) (list name)))

  (struct-copy State state
               [sigs new-state-sigs]
               [sig-order new-state-sig-order]))

; state-add-relation :: State, Symbol, Relation -> State
; Adds a new relation to the given State.
(define (state-add-relation state name new-relation)
  (when (member name (State-relation-order state))
    (error (format "tried to add relation ~a, but it already existed" name)))
  ;(define new-relation (Relation name rel rel-sigs breaker))
  (define new-state-relations (hash-set (State-relations state) name new-relation))
  (define new-state-relation-order (append (State-relation-order state) (list name)))
  (struct-copy State state
               [relations new-state-relations]
               [relation-order new-state-relation-order]))

; state-add-pred :: State, Symbol, Predicate -> State
; Adds a new predicate to the given State.
(define (state-add-pred state name pred)
  (define new-state-pred-map (hash-set (State-pred-map state) name pred))
  (struct-copy State state
               [pred-map new-state-pred-map]))

; state-add-fun :: State, Symbol, Function -> State
; Adds a new function to the given State.
(define (state-add-fun state name fun)
  (define new-state-fun-map (hash-set (State-fun-map state) name fun))
  (struct-copy State state
               [fun-map new-state-fun-map]))

; state-add-const :: State, Symbol, Constant -> State
; Adds a new constant to the given State.
(define (state-add-const state name const)
  (define new-state-const-map (hash-set (State-const-map state) name const))
  (struct-copy State state
               [const-map new-state-const-map]))

; state-add-inst :: State, Symbol, Inst -> State
; Adds a new inst to the given State.
(define (state-add-inst state name inst)
  (define new-state-inst-map (hash-set (State-inst-map state) name inst))
  (struct-copy State state
               [inst-map new-state-inst-map]))

(define (set-option! option value #:original-path [original-path #f])
  (cond [(or (equal? option 'verbosity)
             (equal? option 'verbose))
         (set-verbosity value)]
        [else
         (update-state! (state-set-option curr-state option value #:original-path original-path))]))

; state-set-option :: State, Symbol, Symbol -> State
; Sets option to value for state.
(define (state-set-option state option value #:original-path [original-path #f])
  (define options (State-options state))

  (unless ((hash-ref option-types option) value)
    (raise-user-error (format "Setting option ~a requires ~a; received ~a"
                              option (hash-ref option-types option) value)))
  
  (define new-options
    (cond
      [(equal? option 'eval-language)
       (unless (or (equal? value 'surface) (equal? value 'core))
         (raise-user-error (format "Invalid evaluator language ~a; must be surface or core.~n"
                                   value)))
       (struct-copy Options options
                    [eval-language value])]
      [(equal? option 'solver)
       (struct-copy Options options
                    [solver
                     (if (and (string? value) original-path)
                         (path->string (build-path original-path (string->path value)))
                         value)])]
      [(equal? option 'backend)
       (struct-copy Options options
                    [backend value])]
      [(equal? option 'sb)
       (struct-copy Options options
                    [sb value])]
      [(equal? option 'coregranularity)
       (struct-copy Options options
                    [coregranularity value])]
      [(equal? option 'logtranslation)
       (struct-copy Options options
                    [logtranslation value])]
      [(equal? option 'local_necessity)
       (struct-copy Options options
                    [local_necessity value])]
      [(equal? option 'min_tracelength)
       (let ([max-trace-length (get-option state 'max_tracelength)])
         (if (> value max-trace-length)
             (raise-user-error (format "Cannot set min_tracelength to ~a because min_tracelength cannot be greater than max_tracelength. Current max_tracelength is ~a."
                                       value max-trace-length))
             (struct-copy Options options
                          [min_tracelength value])))]
      [(equal? option 'max_tracelength)
       (let ([min-trace-length (get-option state 'min_tracelength)])
         (if (< value min-trace-length)
             (raise-user-error (format "Cannot set max_tracelength to ~a because max_tracelength cannot be less than min_tracelength. Current min_tracelength is ~a."
                                       value min-trace-length))
             (struct-copy Options options
                          [max_tracelength value])))]
      [(equal? option 'problem_type)
       (struct-copy Options options
                    [problem_type value])]
      [(equal? option 'target_mode)
       (struct-copy Options options
                    [target_mode value])]
      [(equal? option 'core_minimization)
       (struct-copy Options options
                    [core_minimization value])]
      [(equal? option 'skolem_depth)
       (struct-copy Options options
                    [skolem_depth value])]
      [(equal? option 'run_sterling)
       (struct-copy Options options
                    [run_sterling
                     (if (and (string? value) original-path)
                         (path->string (build-path original-path (string->path value)))
                         value)])]
      [(equal? option 'sterling_port)
       (struct-copy Options options
                    [sterling_port value])]
      [(equal? option 'engine_verbosity)
       (struct-copy Options options
                    [engine_verbosity value])]))

  (struct-copy State state
               [options new-options]))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Forge Commands  ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; The environment threaded through commands
(define curr-state init-state)
(define (update-state! new-state) 
  (set! curr-state new-state))

; check-temporal-for-var :: Boolean String -> void
; raises an error if is-var is true and the problem_type option is 'temporal
; uses the given name in the error message
; meant to only allow var sigs and relations in temporal specs
(define (check-temporal-for-var is-var name)
  (cond
    [(and is-var
          (not (equal? (get-option curr-state 'problem_type)
            'temporal)))
     (raise-user-error (format "Can't have var ~a unless problem_type option is temporal"
                               name))]))

; Declare a new sig.
; (sig name [|| [#:one] [#:abstract]] [#:is-var isv] [[|| #:in #:extends] parent])
; Extending a sig with #:in does NOT work yet,
; it's only been added here so that it throws the correct error
; when the Expander tries to do that
(define-syntax (sig stx)
  (syntax-parse stx
    [(sig (~optional (#:lang check-lang) #:defaults ([check-lang #''checklangNoCheck]))
          name:id
          (~alt (~optional (~seq #:in super-sig:expr)) ;check if this supports "sig A in B + C + D ..."
                (~optional (~seq #:extends parent:expr))
                (~optional (~or (~seq (~and #:one one-kw))
                                (~seq (~and #:lone lone-kw))
                                (~seq (~and #:abstract abstract-kw))))
                (~optional (~seq #:is-var isv) #:defaults ([isv #'#f]))) ...)
     (quasisyntax/loc stx
       (begin
         (define true-name 'name)
         (define true-one (~? (~@ (or #t 'one-kw)) (~@ #f)))
         (define true-lone (~? (~@ (or #t 'lone-kw)) (~@ #f)))
         (define true-abstract (~? (~@ (or #t 'abstract-kw)) (~@ #f)))
         (define true-parent (~? (get-sig curr-state parent)
                                 #f))
         (define true-parent-name
           (if true-parent (Sig-name true-parent) #f))
         (define name (make-sig true-name
                                #:one true-one
                                #:lone true-lone
                                #:abstract true-abstract
                                #:is-var isv
                                ;let #:in default to #f until it is implemented
                                #:extends true-parent
                                #:info (nodeinfo #,(build-source-location stx) check-lang)))
         ;make sure it isn't a var sig if not in temporal mode
         (~@ (check-temporal-for-var isv true-name))
         ;Currently when lang/expander.rkt calls sig with #:in,
         ;super-sig is #'(raise "Extending with in not yet implemented.")
         ;This is just here for now to make sure that error is raised.
         (~? super-sig)
         (update-state! (state-add-sig curr-state true-name name true-parent-name))))]))

; Declare a new relation
; (relation name (sig1 sig2 sigs ...) [|| [#:is breaker] [#:is-var isv]])
(define-syntax (relation stx)
  (syntax-parse stx
    [(relation name:id (sig1:id sig2:id sigs ...)
               (~optional (~seq #:is breaker:id))
               (~optional (~seq #:is-var isv) #:defaults ([isv #'#f])))
     (quasisyntax/loc stx
       (begin
         (define true-name 'name)
         (define true-sigs (list (thunk (get-sig curr-state sig1))
                                 (thunk (get-sig curr-state sig2))
                                 (thunk (get-sig curr-state sigs)) ...))
         ;(printf "relatoin sigs: ~a~n" (list sig1 sig2 sigs ...))
         ; (define true-sigs (map (compose Sig-name ;;; Bugged since relation before sig in #lang forge
         ;                                 (curry get-sig curr-state ))
         ;                        (list sig1 sig2 sigs ...)))
         (define true-breaker (~? breaker #f))
         ;(printf "relatoin breaker: ~a~n" true-breaker)
         (define checker-hash (get-ast-checker-hash))
         (when (hash-has-key? checker-hash 'field-decl) ((hash-ref checker-hash 'field-decl) true-breaker))
         (define name (make-relation true-name
                                     true-sigs
                                     #:is true-breaker
                                     #:is-var isv
                                     #:info (nodeinfo #,(build-source-location stx) 'checklangNoCheck)))
         ;make sure it isn't a var sig if not in temporal mode
         (~@ (check-temporal-for-var isv true-name))
         (update-state! (state-add-relation curr-state true-name name))))]
    ; Case: check-lang
    [(relation (#:lang check-lang) name:id (sig1:id sig2:id sigs ...)
               (~optional (~seq #:is breaker:id))
               (~optional (~seq #:is-var isv) #:defaults ([isv #'#f])))
     (quasisyntax/loc stx
       (begin
         (define true-name 'name)
         (define true-sigs (list (thunk (get-sig curr-state sig1))
                                 (thunk (get-sig curr-state sig2))
                                 (thunk (get-sig curr-state sigs)) ...))
         ;(printf "relatoin sigs: ~a~n" (list sig1 sig2 sigs ...))
         ; (define true-sigs (map (compose Sig-name ;;; Bugged since relation before sig in #lang forge
         ;                                 (curry get-sig curr-state ))
         ;                        (list sig1 sig2 sigs ...)))
         (define true-breaker (~? breaker #f))
         ;(printf "relatoin breaker: ~a~n" true-breaker)
         (define checker-hash (get-ast-checker-hash))
         (when (hash-has-key? checker-hash 'field-decl) ((hash-ref checker-hash 'field-decl) true-breaker))
         (define name (make-relation true-name
                                     true-sigs
                                     #:is true-breaker
                                     #:is-var isv
                                     #:info (nodeinfo #,(build-source-location stx) check-lang)))
         ;make sure it isn't a var sig if not in temporal mode
         (~@ (check-temporal-for-var isv true-name))
         (update-state! (state-add-relation curr-state true-name name))))]))

; Used for sealing formula structs that come from wheats, which should be obfuscated
(begin-for-syntax  
  (define-splicing-syntax-class pred-type
    #:description "optional pred flag"
    #:attributes ((seal 0))
    ; If this is a "wheat pred", wrap in a make-wheat call
    (pattern (~datum #:wheat)
      #:attr seal #'make-wheat)
    ; Otherwise, just pass-through
    (pattern (~seq)
      #:attr seal #'values))

  ; [v] | [v expr] | [v expr mult]
  ; We want to enable arbitrary code within the expr portion
  (define-splicing-syntax-class param-decl-class
    #:description "predicate or function variable declaration"
    #:attributes (mexpr name)
    (pattern name:id                            
      #:attr expr #'univ ; default domain
      #:attr mexpr #'(mexpr expr (if (> (node/expr-arity expr) 1) 'set 'one)))
    (pattern (name:id expr)
      #:attr mexpr #'(mexpr expr (if (> (node/expr-arity expr) 1) 'set 'one)))
    (pattern (name:id expr mult)
      #:attr mexpr #'(mexpr expr mult)))

  ; No variable ID, just a "result type":
  ; expr | [expr mult]
  (define-splicing-syntax-class codomain-class
    #:description "codomain expression in helper function declaration"
    #:attributes (mexpr)
    (pattern (expr mult:id)
      #:attr mexpr #'(mexpr expr 'mult))
    (pattern (expr mult)
      #:attr mexpr #'(mexpr expr mult))
    ; Catch expr without mult (but must come last, or will match both of above)
    (pattern expr                            
      #:attr mexpr #'(mexpr expr (if (> (node/expr-arity expr) 1) 'set 'one))))
  )

; Declare a new predicate
; Two cases: one with args, and one with no args
(define-syntax (pred stx)
  (syntax-parse stx
    ; no decls: predicate is already the AST node value, without calling it
    [(pred pt:pred-type
           (~optional (#:lang check-lang) #:defaults ([check-lang #''checklangNoCheck]))
           name:id conds:expr ...+)
     (with-syntax ([the-info #`(nodeinfo #,(build-source-location stx) check-lang)])
       (quasisyntax/loc stx
         (begin
           ; use srcloc of actual predicate, not this location in sigs
           ; "pred spacer" still present, even if no arguments, to consistently record use of a predicate
           (define name
             (pt.seal (node/fmla/pred-spacer the-info 'name '() (&&/info the-info conds ...))))
           (update-state! (state-add-pred curr-state 'name name)))))]

    ; some decls: predicate must be called to evaluate it
    [(pred pt:pred-type
           (~optional (#:lang check-lang) #:defaults ([check-lang #''checklangNoCheck]))
           (name:id decls:param-decl-class  ...+) conds:expr ...+)
     (with-syntax ([the-info #`(nodeinfo #,(build-source-location stx) check-lang)])
       (quasisyntax/loc stx
         (begin
           ; "pred spacer" added to record use of predicate along with original argument declarations etc.           
           (define (name decls.name ...)
             (unless (or (integer? decls.name) (node/expr? decls.name) (node/int? decls.name))
               (error (format "Argument '~a' to pred ~a was not a Forge expression, integer-expression, or Racket integer. Got ~v instead."
                              'decls.name 'name decls.name)))
             ...
             (pt.seal (node/fmla/pred-spacer the-info 'name (list (apply-record 'decls.name decls.mexpr decls.name) ...)
                                             (&&/info the-info conds ...))))                      
           (update-state! (state-add-pred curr-state 'name name)))))]))

(define/contract (repeat-product expr count)
  [@-> node/expr? number? node/expr?]
  (cond [(> count 1)
         (-> expr (repeat-product expr (@- count 1)))]
        [else expr]))

; Declare a new function
; (fun (name var ...) body)
; (fun (name (var expr <multiplicity>]) ...) body)
(define-syntax (fun stx)
  (syntax-parse stx
    [(fun (name:id decls:param-decl-class ...+)
          result:expr
          ; Note: default for *attribute*
          (~optional (~seq #:codomain codomain:codomain-class)
                     #:defaults ([codomain.mexpr #'(mexpr (repeat-product univ (node/expr-arity result))
                                                          (if (> (node/expr-arity result) 1) 'set 'one))])))
     ; TODO: there is no check-lang in this macro; does that mean that language-level details are lost within a helper fun?
     (with-syntax ([the-info #`(nodeinfo #,(build-source-location stx) 'checklangNoCheck)])
       #'(begin
           ; "fun spacer" added to record use of function along with original argument declarations etc.           
           (define (name decls.name ...)
             (unless (or (integer? decls.name) (node/expr? decls.name) (node/int? decls.name))
               (error (format "Argument '~a' to fun ~a was not a Forge expression, integer-expression, or Racket integer. Got ~v instead."
                              'decls.name 'name decls.name)))
             ...
             ; maintain the invariant that helper functions are always rel-expression valued
             (define safe-result
               (cond [(node/int? result)
                      (node/expr/op/sing (node-info result) 1 (list result))]
                     [else result]))
             (node/expr/fun-spacer
              the-info                      ; from node
              (node/expr-arity safe-result) ; from node/expr
              'name
              (list (apply-record 'decls.name decls.mexpr decls.name) ...)
              codomain.mexpr
              safe-result))
           (update-state! (state-add-fun curr-state 'name name))))]))

; Declare a new constant
; (const name value)
(define-syntax (const stx)
  (syntax-parse stx
    [(const name:id value:expr) 
      #'(begin 
          (define name value)
          (update-state! (state-add-const curr-state 'name name)))]))

; Define a new bounding instance
; (inst name binding ...)
(define-syntax (inst stx)
  (syntax-parse stx
    [(inst name:id binds:expr ...)
     (syntax/loc stx
       (begin
         (define name (make-inst (flatten (list binds ...))))
         (update-state! (state-add-inst curr-state 'name name))))]))

; Run a given spec
; (run name
;      [#:pred [(pred ...)]] 
;      [#:scope [((sig [lower 0] upper) ...)]]
;      [#:inst instance-name])
(define-syntax (run stx)
  (define command stx)
  (syntax-parse stx
    [(run name:id
          (~alt
            (~optional (~or (~seq #:preds (preds ...))
                            (~seq #:preds pred)))
            (~optional (~seq #:scope ((sig:id (~optional lower:nat) upper:nat) ...)))
            (~optional (~or (~seq #:bounds (boundss ...))
                            (~seq #:bounds bound)))
            (~optional (~seq #:solver solver-choice)) ;unused
            (~optional (~seq #:backend backend-choice)) ;unused
            (~optional (~seq #:target target-instance))
            ;the last 3 appear to be unused in functional forge
            (~optional (~seq #:target-distance target-distance))
            (~optional (~or (~and #:target-compare target-compare)
                            (~and #:target-contrast target-contrast)))) ...)
     #`(begin
         ;(define checker-hash (get-ast-checker-hash))
         ;(printf "sigs run ~n ch= ~a~n" checker-hash)
         (define run-state curr-state)
         (define run-name (~? (~@ 'name) (~@ 'no-name-provided)))
         (define run-preds (~? (list preds ...) (~? (list pred) (list))))         
         (define run-scope
           (~? (~@ (list (~? (~@ (list sig lower upper))
                             (~@ (list sig upper))) ...))
               (~@ (list))))
         #;(define run-scope
           (~? (list (list sig (~? lower) upper) ...) (list)))
         #;(define run-scope
           (~? (list (~? (list sig lower upper) (list sig upper)) ...) (list)))
         (define run-bounds (~? (list boundss ...) (~? (list bound) (list))))                  
         (define run-solver (~? 'solver-choice #f))
         (define run-backend (~? 'backend #f))
         (define run-target
           (~? (Target (cdr target-instance)
                       (~? 'target-distance 'close))
               #f))
         (define run-command #'#,command)         
         (define name
           (run-from-state run-state
                           #:name run-name
                           #:preds run-preds
                           #:scope run-scope
                           #:bounds run-bounds
                           #:solver run-solver
                           #:backend run-backend
                           #:target run-target
                           #:command run-command))
         (update-state! (state-add-runmap curr-state 'name name)))]))

; Test that a spec is sat or unsat
; (test name
;       [#:preds [(pred ...)]] 
;       [#:scope [((sig [lower 0] upper) ...)]]
;       [#:bounds [bound ...]]
;       [|| sat unsat]))
(define-syntax (test stx)
  (syntax-case stx ()
    [(test name args ... #:expect expected)  
     (add-to-execs
       (syntax/loc stx 
         (cond 
          [(member 'expected '(sat unsat))           
           (run name args ...)
           (define first-instance (tree:get-value (Run-result name)))
           (unless (equal? (if (Sat? first-instance) 'sat 'unsat) 'expected)
             (when (> (get-verbosity) 0)
               (printf "Unexpected result found, with statistics and metadata:~n")
               (pretty-print first-instance))
             (display name) ;; Display in Sterling since the test failed.
             (raise-user-error (format "Failed test ~a. Expected ~a, got ~a.~a"
                            'name 'expected (if (Sat? first-instance) 'sat 'unsat)
                            (if (Sat? first-instance)
                                (format " Found instance ~a" first-instance)
                                (if (Unsat-core first-instance)
                                    (format " Core: ~a" (Unsat-core first-instance))
                                    "")))))
           (close-run name)]

          [(equal? 'expected 'theorem)          
           (check name args ...)
           (define first-instance (tree:get-value (Run-result name)))
           (when (Sat? first-instance)
             (when (> (get-verbosity) 0)
               (printf "Instance found, with statistics and metadata:~n")
               (pretty-print first-instance))
             (display name) ;; Display in sterling since the test failed.
             (raise-user-error (format "Theorem ~a failed. Found instance:~n~a"
                            'name first-instance)))
           (close-run name)]

          [else (raise (format "Illegal argument to test. Received ~a, expected sat, unsat, or theorem."
                               'expected))])))]))

(define-syntax (example stx)  
  (syntax-parse stx
    [(_ name:id pred bounds ...)
     (add-to-execs
       (syntax/loc stx (begin
         (when (eq? 'temporal (get-option curr-state 'problem_type))
           (raise-user-error (format "example ~a: Can't have examples when problem_type option is temporal" 'name)))
         (run name #:preds [pred] #:bounds [bounds ...])
         (define first-instance (tree:get-value (Run-result name)))
         (when (Unsat? first-instance)
           (run double-check #:preds [] #:bounds [bounds ...])
           (define double-check-instance (tree:get-value (Run-result double-check)))
           (if (Sat? double-check-instance)
               (raise-user-error (format "Invalid example '~a'; the instance specified does not satisfy the given predicate." 'name))
               (raise-user-error (format (string-append "Invalid example '~a'; the instance specified is impossible. "
                                             "This means that the specified bounds conflict with each other "
                                             "or with the sig/relation definitions.")
                              'name)))))))]))

; Checks that some predicates are always true.
; (check name
;        #:preds [(pred ...)]
;        [#:scope [((sig [lower 0] upper) ...)]]
;        [#:bounds [bound ...]]))
(define-syntax (check stx)
  (syntax-parse stx
    [(check name:id
            (~alt
              (~optional (~seq #:preds (pred ...)))
              (~optional (~seq #:scope ((sig:id (~optional lower:nat #:defaults ([lower #'0])) upper:nat) ...)))
              (~optional (~seq #:bounds (bound ...)))) ...)
     (syntax/loc stx
       (run name (~? (~@ #:preds [(! (&& pred ...))]))
                 (~? (~@ #:scope ([sig lower upper] ...)))
                 (~? (~@ #:bounds (bound ...)))))]))


; Exprimental: Run in the context of a given external Forge spec
; (with path-to-forge-spec commands ...)
(define-syntax (with stx)
  (syntax-parse stx
    [(with (ids:id ... #:from module-name) exprs ...+)
     #'(let ([temp-state curr-state])
         (define ids (dynamic-require module-name 'ids)) ...
         (define result
           (let () exprs ...))
         (update-state! temp-state)
         result)]))

(define-for-syntax (add-to-execs stx)  
  (if (equal? (syntax-local-context) 'module)
      #`(module+ execs #,stx)
      stx))

; Experimental: Execute a forge file (but don't require any of the spec)
; (execute "<path/to/file.rkt>")
(define-syntax (execute stx)
  (syntax-case stx ()
    [(_ m) (replace-context stx (add-to-execs #'(require (submod m execs))))]))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Result Functions ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; make-model-generator :: Stream<model> -> (-> model)
; Creates a thunk which generates a new model on each call.
(define (make-model-generator model-lazy-tree [mode 'next])
  (thunk
    (define ret (tree:get-value model-lazy-tree))
    (set! model-lazy-tree (tree:get-child model-lazy-tree mode))
    ret))

(provide (prefix-out forge: nsa))
(define nsa (make-parameter #f))
; display :: Run -> void
; Lifted function which, when provided a Run,
; generates a Sterling instance for it.
(define (true-display arg1 [arg2 #f])
  (if (not (Run? arg1))
      (if arg2 (@display arg1 arg2) (@display arg1))
      (let ()
        (define run arg1)
        (define model-lazy-tree (Run-result run))        
        (define (evaluate-str str-command)
          (define pipe1 (open-input-string str-command))
          (define pipe2 (open-input-string (format "eval ~a" str-command)))

          (with-handlers ([(lambda (x) #t) 
                           (lambda (exn) (exn-message exn))])
            ; Read command as syntax from pipe
            (define expr
              (cond [(equal? (get-option curr-state 'eval-language) 'surface)
                     (forge-lang:parse "/no-name" (forge-lang:make-tokenizer pipe2))]
                    [(equal? (get-option curr-state 'eval-language) 'core)
                     (read-syntax 'Evaluator pipe1)]
                    [else (raise-user-error "Could not evaluate in current language - must be surface or core.")]))

            ;(printf "Run Atoms: ~a~n" (Run-atoms run))

            ; Evaluate command
            (define full-command (datum->syntax #f `(let
              ,(for/list ([atom (Run-atoms run)]
                          #:when (symbol? atom))
                 `[,atom (atom ',atom)])
                 ,expr)))

            (printf "full-command: ~a~n" full-command)
            
            (define ns (namespace-anchor->namespace (nsa)))
            (define command (eval full-command ns))
            
            (evaluate run '() command)))

        (define (get-contrast-model-generator model compare distance)
          (unless (member distance '(close far))
            (raise (format "Contrast model distance expected one of ('close, 'far); got ~a" distance)))
          (unless (member compare '(compare contrast))
            (raise (format "Contrast model compare expected one of ('compare, 'contrast); got ~a" compare)))

          (define new-state 
            (let ([old-state (get-state run)])
              (state-set-option (state-set-option old-state 'backend 'pardinus)
                                'solver 'TargetSATSolver)))
          (define new-preds
            (if (equal? compare 'compare)
                (Run-spec-preds (Run-run-spec run))
                (list (! (foldr (lambda (a b) (&& a b))
                                  true
                                  (Run-spec-preds (Run-run-spec run)))))))
          
          (define new-target
            (if (Unsat? model) ; if satisfiable, move target
                (Run-spec-target (Run-run-spec run))
                (Target
                 (for/hash ([(key value) (first (Sat-instances model))]
                            #:when (member key (append (get-sigs new-state)
                                                       (get-relations new-state))))
                   (values key value))
                 distance)))

          (define contrast-run-spec
            (struct-copy Run-spec (Run-run-spec run)
                         [preds new-preds]
                         [target new-target]
                         [state new-state]))
          (define-values (run-result atom-rels server-ports kodkod-currents kodkod-bounds)
                         (send-to-kodkod contrast-run-spec))
          (define contrast-run 
            (struct-copy Run run
                         [name (string->symbol (format "~a-contrast" (Run-name run)))]
                         [run-spec contrast-run-spec]
                         [result run-result]
                         [server-ports server-ports]
                         [kodkod-currents kodkod-currents]))
          (get-result contrast-run))

        (display-model run
                       model-lazy-tree 
                       (get-relation-map run)
                       evaluate-str
                       (Run-name run) 
                       (Run-command run) 
                       "/no-name.rkt" 
                       (get-bitwidth
                         (Run-run-spec run)) 
                       empty
                       get-contrast-model-generator))))

(define-syntax (display stx)
  (syntax-case stx ()
    [(display args ...)
      (add-to-execs #'(true-display args ...))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Scope/Bound Updaters ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; set-bitwidth :: Scope, int -> Scope
; Updates the bitwidth for the given Scope.
;(define (set-bitwidth scope n)
;  (struct-copy Scope scope
;               [bitwidth n]))
;

(define (solution-diff s1 s2)
  (map instance-diff (Sat-instances s1) (Sat-instances s2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Seq Library  ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; reference:
; https://github.com/AlloyTools/org.alloytools.alloy/blob/master/org.alloytools.alloy.core/src/main/resources/models/util/seqrel.als

; need to provide through expander

(provide isSeqOf seqFirst seqLast indsOf idxOf lastIdxOf elems inds isEmpty hasDups seqRest)

(define-syntax (define-builtin stx)
  (syntax-parse stx
   [(define-builtin:id (opName:id locArg:id args:id ...) body:expr)
    (with-syntax ([opName/func (format-id #'opName "~a/func" #'opName)]
                  [ellip '...])
      (syntax/loc stx (begin
        (define-syntax (opName stxx)
          (syntax-parse stxx
            ; For use in forge/core; full s-expression expands to 0-ary procedure
            ; Note use of "ellip" to denote "..." for the inner macro.
            [(opName inner-args:id ellip)
             (quasisyntax/loc stxx
               (opName/func (nodeinfo #,(build-source-location stxx) 'checklangNoCheck) inner-args ellip))]
            ; For use with #lang forge; identifier by itself expands to 3+-ary procedure
            [opName
             (quasisyntax/loc stxx
               (lambda (args ...)
                 (opName/func (nodeinfo #,(build-source-location stxx) 'checklangNoCheck) args ...)))]))
        
        (define (opName/func locArg args ...)
          body)
        )))
    ]))

(define-builtin (isSeqOf info r1 d)
  (&&/info info
      (in/info info r1 (-> Int univ))
      (in/info info (join/info info Int r1) d)
      (all ([i1 (join/info info r1 univ)])
           (&&/info info (int>= (sum/info info i1) (int 0))
               (lone (join/info info i1 r1))))
      (all ([e (join/info info Int r1)])
           (some (join/info info r1 e)))
      (all ([i1 (join/info info r1 univ)])
           (implies (!= i1 (sing/info info (int 0)))
                    (some (join/info info
                     (sing/info info
                      (subtract/info info
                       (sum/info info i1) (int 1))) r1))))))

(define-builtin (seqFirst info r)
  (join/info info
    (sing/info info (int 0))
    r))

(define-builtin (seqLast info r)
  (join/info info
    (sing/info info
      (subtract/info info
        (card/info info r) (int 1)))
    r))

; precondition: r isSeqOf something
(define-builtin (seqRest info r)
  (-/info info 
    (join/info info succ r)
    (->/info info (int -1) univ)))

(define-builtin (indsOf info r e)
  (join/info info r e))

(define-builtin (idxOf info r e)
  (min (join/info info r e)))

(define-builtin (lastIdxOf info r e)
  (max (join/info info r e)))

(define-builtin (elems info r)
  (join/info info Int r))

(define-builtin (inds info r)
  (join/info info r univ))

(define-builtin (isEmpty info r)
  (no/func r #:info info))

(define-builtin (hasDups info r)
  (some ([e (elems/func info r)])
    (some ([num1 (indsOf/func info r e)] [num2 (indsOf/func info r e)])
      (!= num1 num2))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Reachability Library  ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(provide reachable)

(define (srcloc->string loc)
  (format "line ~a, col ~a, span: ~a" (source-location-line loc) (source-location-column loc) (source-location-span loc)))

; a reachable from b through r1 + r2 + ...
(define-syntax (reachable stx)
  (syntax-parse stx
    ; For use in forge/core; full s-expression expands to 0-ary procedure
    [(reachable a b r ...)
     (quasisyntax/loc stx
       (reachablefun #,(build-source-location stx) a b (list r ...)))]
    ; For use with #lang forge; identifier by itself expands to 3+-ary procedure
    [reachable
     (quasisyntax/loc stx
       (lambda (a b . r) (reachablefun #,(build-source-location stx) a b r)))]))



(define (reachablefun loc a b r)
  (unless (equal? 1 (node/expr-arity a)) (raise-user-error (format "First argument \"~a\" to reachable is not a singleton at loc ~a" (deparse a) (srcloc->string loc))))
  (unless (equal? 1 (node/expr-arity b)) (raise-user-error (format "Second argument \"~a\" to reachable is not a singleton at loc ~a" (deparse b) (srcloc->string loc))))
  (in/info (nodeinfo loc 'checklangNoCheck) 
           a 
           (join/info (nodeinfo loc (get-check-lang)) 
                      b 
                      (^/info (nodeinfo loc 'checklangNoCheck) (union-relations loc r)))))

(define (union-relations loc r)
  (cond
    [(empty? r) (raise-user-error "Unexpected: union-relations given no arguments. Please report this error.")]
    [(empty? (rest r)) (first r)]
    [else (+/info (nodeinfo loc 'checklangNoCheck) (first r) (union-relations loc (rest r)))]))
