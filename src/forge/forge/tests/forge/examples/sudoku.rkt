#lang forge

option run_sterling off


option verbose 0

-- VERSION FOR AUTOMATED TESTING

-- SUDOKU
-- Find me boards with 10 squares populated (initial puzzle)
--  such that there is a valid completed extension (i.e., the initial is solvable)

-- Ideally we'd like to find UNIQUE-SOLUTION boards (up to isomorphism) but unfortunately that's
--  harder than we can handle at the moment (needs 2nd order universals and possibly some cleverness around isomorphism)

sig N {neighbors: set N}
one sig N1 extends N {}
one sig N2 extends N {}
one sig N3 extends N {}
one sig N4 extends N {}
one sig N5 extends N {}
one sig N6 extends N {}
one sig N7 extends N {}
one sig N8 extends N {}
one sig N9 extends N {}


sig Board {

  places: set N -> N -> N
}

pred structural {
  -- lone number per cell
  all b: Board | all i: N | all j: N | lone b.places[i][j]
                 
  -- neighbors
  N1.neighbors = N1+N2+N3
  N2.neighbors = N1+N2+N3
  N3.neighbors = N1+N2+N3
  N4.neighbors = N4+N5+N6
  N5.neighbors = N4+N5+N6
  N6.neighbors = N4+N5+N6
  N7.neighbors = N7+N8+N9
  N8.neighbors = N7+N8+N9
  N9.neighbors = N7+N8+N9
}

pred filled[b: Board, n: Int] {
  #b.places = n
}
pred tenFilled {
  some b: Board | filled[b, 10]  
}
pred solved[b: Board] {  
    all i: N | b.places[i, N] = N // every row, taking all columns
    all i: N | b.places[N, i] = N // every column, taking all rows  //N in {x : N | some j : N | j->i->x in b.places } 
    // and every sub-block (inefficient way of phrasing it -- or is it?)
    all i: N | all j: N | b.places[i.neighbors][j.neighbors] = N
}
pred someSolved {
  some b: Board | solved[b]
}
test expect {
 {structural} for 2 Board, 9 N, 5 Int is sat
 {tenFilled structural} for 2 Board, 9 N, 5 Int is sat
 {someSolved structural} for 2 Board, 9 N, 5 Int is sat
}

pred generatePuzzle {
  structural
  some init: Board |
  some final: Board | {
      -- lesson on performance: try commenting this out...
    init != final -- massively helpful, even if it's a consequence of the other constraints
    -- ? maybe even faster if we constrain init to be pre-valid? not =N, but no dupes?    
    filled[init, 10]
    init.places in final.places
    solved[final]     
  }
} 
test expect {
  generatePuzzle for 2 Board, 9 N, 5 Int is sat
}
