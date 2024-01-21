#lang brag

chip-program : /"CHIP" chipname /"{" in-spec out-spec part-spec /"}"
@chipname : ID
in-spec : pin-spec
out-spec : pin-spec
@pin-spec : (/"IN" | /"OUT") pin [/"," pin]* /";"
/pin : ID  [/"[" NUMBER /"]"]
@part-spec : /"PARTS:" part+
part : partname /"(" wire-assign [/"," wire-assign]* /")" /";"
@partname : ID
/wire-assign : pin-range /"=" pin-val
/pin-range : ID [/"[" bus-range /"]"]
@bus-range : number [/"." /"." number]
@pin-val : pin-range | BINARY-NUMBER | TRUE | FALSE
@number : BINARY-NUMBER | NUMBER