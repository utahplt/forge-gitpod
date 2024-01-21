601
((3) 0 () 1 ((q lib "syntax/parse/class/paren-shape.rkt")) () (h ! (equal) ((c form c (c (? . 0) q ~parens)) q (740 . 2)) ((c form c (c (? . 0) q paren-shape/parens)) q (642 . 2)) ((q def ((lib "syntax/parse/class/local-value.rkt") local-value)) q (0 . 11)) ((c form c (c (? . 0) q ~braces)) q (844 . 2)) ((c form c (c (? . 0) q paren-shape)) q (585 . 4)) ((q form ((lib "syntax/parse/class/struct-id.rkt") struct-id)) q (895 . 2)) ((c form c (c (? . 0) q ~brackets)) q (791 . 2)) ((c form c (c (? . 0) q paren-shape/brackets)) q (674 . 2)) ((c form c (c (? . 0) q paren-shape/braces)) q (708 . 2))))
syntax class
(local-value [predicate?                              
              intdef-ctx                              
              #:name name                             
              #:failure-message failure-message]) -> syntax class
  predicate? : (any/c . -> . any/c) = (const #t)
  intdef-ctx : (or/c internal-definition-context?          = '()
                     (listof internal-definition-context?)
                     #f)
  name : (or/c string? #f) = #f
  failure-message : (or/c string? #f) = #f
syntax class
(paren-shape shape)
 
  shape : any/c
syntax class
paren-shape/parens
syntax class
paren-shape/brackets
syntax class
paren-shape/braces
pattern expander
(~parens H-pattern . S-pattern)
pattern expander
[~brackets H-pattern . S-pattern]
pattern expander
{~braces H-pattern . S-pattern}
syntax class
struct-id
