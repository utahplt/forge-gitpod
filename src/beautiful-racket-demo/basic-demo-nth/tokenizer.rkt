#lang br
(require brag/support)
(provide tokenize basic-lexer)

(define-lex-abbrevs
  (integer (:+ numeric))
  ;; don't lex the leading "-": muddles "-X" and "Y-X"
  (decimal (:or integer (:seq (:? integer) (:seq "." integer)))))


(define basic-lexer
  (lexer-src-pos
   [whitespace (token 'WHITE lexeme #:skip? #t
                      #:position (pos lexeme-start)
                      #:line (line lexeme-start)
                      #:column (col lexeme-start)
                      #:span (- (pos lexeme-end)
                                (pos lexeme-start)))]
   [(:or (from/to "/*" "*/")
         (:: decimal (:+ whitespace) (from/to (uc+lc "rem") "\n")))
    (token 'COMMENT lexeme #:skip? #t
           #:position (pos lexeme-start)
           #:line (line lexeme-start)
           #:column (col lexeme-start)
           #:span (- (pos lexeme-end)
                     (pos lexeme-start)))]
   [(:or (uc+lc "print" "for" "to" "step" "if"
                "goto" "input" "let" "next"
                "return" "clear" "list" "run"
                "end" "then" "else" "gosub"
                "and" "or" "stop" "let" "def" "dim" "on")
         ";" "=" "(" ")" "+" "-" "*" "/" "^"
         "<=" ">=" "<>" "<" ">" "=" ":" ",") (token (string-downcase lexeme)
                                                    (string-downcase lexeme)
                                                    #:position (pos lexeme-start)
                                                    #:line (line lexeme-start)
                                                    #:column (col lexeme-start)
                                                    #:span (- (pos lexeme-end)
                                                              (pos lexeme-start)))]
   [decimal (token 'NUMBER (string->number lexeme)
                   #:position (pos lexeme-start)
                   #:line (line lexeme-start)
                   #:column (col lexeme-start)
                   #:span (- (pos lexeme-end)
                             (pos lexeme-start)))]
   [(:: alphabetic (:* (:or alphabetic numeric)) (:? "$")) (token 'ID (string->symbol lexeme)
                                                                  #:position (pos lexeme-start)
                                                                  #:line (line lexeme-start)
                                                                  #:column (col lexeme-start)
                                                                  #:span (- (pos lexeme-end)
                                                                            (pos lexeme-start)))]
   [(from/to "\"" "\"") (token 'STRING (trim-ends  "\"" lexeme  "\"")
                               #:position (+ (pos lexeme-start) 1)
                               #:line (line lexeme-start)
                               #:column (+ (col lexeme-start) 1)
                               #:span (- (pos lexeme-end)
                                         (pos lexeme-start) 2))]))

(define (tokenize ip)
  (port-count-lines! ip)
  (define (next-token) (basic-lexer ip))  
  next-token)

(module+ main
  (apply-tokenizer tokenize "\n10 rem foo\n15 print x\n20 rem\n"))