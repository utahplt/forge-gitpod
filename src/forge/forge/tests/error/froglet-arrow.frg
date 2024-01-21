#lang froglet
option run_sterling off

sig Node {
    next: one Node
}

one sig A, B extends Node {}

pred arrow {
    A->B in next
}

test expect {
    {arrow} is sat
}
