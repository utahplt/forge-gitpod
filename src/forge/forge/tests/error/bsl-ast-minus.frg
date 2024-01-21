#lang forge/bsl
option run_sterling off


sig Node {
    next: lone Node
}
one sig A, B extends Node{}

pred err {
    some (A - next)
}

test expect{
    {err} is sat
}