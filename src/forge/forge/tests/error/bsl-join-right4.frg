#lang forge/bsl
option run_sterling off


sig Course {}
sig Grade {}
one sig A, B, C {}

sig Student {
    numWRIT: one Int,
    transcript: pfunc Course -> Grade
}

pred fieldsEqual {
    some s1, s2: Student| s1.transcript.Grade = s2.transcript.Grade
}

test expect {
    {fieldsEqual} is sat
}