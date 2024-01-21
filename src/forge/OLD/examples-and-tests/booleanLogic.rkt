#lang forge

option solver MiniSatProver
option logtranslation 2
option coregranularity 2

------------------------------------------------------
-- Formula Type
------------------------------------------------------

abstract sig Formula {
  truth: set Instance -- Instances this is true in
}
sig Var extends Formula {}

sig Instance {
  trueVars: set Var
}


sig Not extends Formula {child: one Formula}
sig And extends Formula {aleft, aright: one Formula}
sig Or extends Formula {oleft, oright: one Formula}

pred children {
  all n: Not | n.truth = Instance - n.child.truth
  all a: And | a.truth = a.aleft.truth & a.aright.truth
  all o: Or | o.truth = o.oleft.truth + o.oright.truth
}
-- IMPORTANT: don't add new formulas without updating allSubformulas and children

------------------------------------------------------
-- Axioms and helpers
------------------------------------------------------

fun allSubformulas[f: Formula]: set Formula {
  f.^(child + oleft + oright + aleft + aright)
}

pred wellFormed {
  -- no cycles
  all f: Formula | f not in allSubformulas[f]

  -- via abstract
  -- all f: Formula | f in Not + And + Or + Var

  all f: Var | f.truth = {i: Instance | f in i.trueVars}
}

------------------------------------------------------

--GiveMeAFormula : run {children and wellFormed and some Formula} for 5 Formula, 5 Instance

pred GiveMeABigFormula {
  children 
  wellFormed 
  some f: Formula | {
    #(allSubformulas[f] & Var) > 2
    some i: Instance | i not in f.truth
    some i: Instance | i in f.truth
  }
}

nameThisRun : run GiveMeABigFormula for 8 Formula, 2 Instance, 5 Int -- need 2 instances
