#lang br/quicklang
(require "parser.rkt" "tokenizer.rkt")

(module+ reader (provide read-syntax get-info))

(define (read-syntax path port)
  (define-values (line col pos) (port-next-location port))
  (define port+newline (input-port-append #f port (open-input-string "\n")))
  (port-count-lines! port+newline)
  (set-port-next-location! port+newline line col pos)
  (define parse-tree (parse path (tokenize port+newline)))
  (strip-bindings
   #`(module basic-mod basic-demo-nth/expander
       #,parse-tree)))

(define (get-info port mod line col pos)
    (define (handle-query key default)
      (case key
        #;[(color-lexer)
         (dynamic-require 'basic-demo/colorer 'color-basic (λ () #f))]
        #;[(drracket:indentation)
         (dynamic-require 'basic-demo/indenter 'indent-jsonic (λ () #f))]
        #;[(drracket:toolbar-buttons)
         (dynamic-require 'basic-demo/buttons 'button-list (λ () #f))]
        [else default]))
    handle-query)