#lang brag
taco-program : /"\n"* taco-leaf* /"\n"*
taco-leaf : /left-paren (taco | not-a-taco){7} /right-paren
taco : /"%"
not-a-taco : /left-paren /right-paren
left-paren : "#"
right-paren : "$"