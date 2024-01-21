#lang brag

program : load-expr output-file-expr compare-to-expr output-list-expr test-expr*
load-expr : /"load" ID /","
output-file-expr : /"output-file" ID /","
compare-to-expr : /"compare-to" ID /","
output-list-expr : /"output-list" column+ /";"
/column :  ID FORMAT-STRING
@test-expr : step-expr+ /";"
@step-expr : (set-expr | eval-expr | output-expr) [/","]
set-expr : /"set" ID VAL
eval-expr : /"eval"
output-expr : /"output"