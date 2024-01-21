#lang forge/bsl
option verbose 0

abstract sig Player {}
one sig X, O extends Player {}
sig Board {
  board: pfunc Int -> Int -> Player
}

-------------------------------------------------

inst inst_piecewise
{
  Board = `Board0 + `Board1 + `Board2 
  Player = `X + `O
  -- TODO: infer these
  X = `X
  O = `O
  
  `Board0.board in (1, 1)   -> `X +
                  (1 -> 2) -> `O +
                  1 -> 0   -> `X 

  -- This is an error: can't mix operators in a piecewise bind
  `Board0.board ni (2, 2)   -> `X +
                  (1 -> 2) -> `O +
                  1 -> 0   -> `X
                                    
  
}

test expect {
  should_error: {} for inst_piecewise is sat
}
