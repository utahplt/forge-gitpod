#lang br/quicklang
(module reader br
  (require "reader.rkt")
  (provide read-syntax get-info)
  (define (get-info port mod line col pos)
    (define (handle-query key default)
      (case key
        [(color-lexer)
         (dynamic-require 'jsonic-demo-3/colorer 'color-jsonic)]
        [(drracket:indentation)
         (dynamic-require 'jsonic-demo-3/indenter 'indent-jsonic)]
        [(drracket:toolbar-buttons)
         (dynamic-require 'jsonic-demo-3/buttons 'button-list)]
        [else default]))
    handle-query))

