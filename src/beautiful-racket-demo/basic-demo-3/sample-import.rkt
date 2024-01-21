#lang basic-demo-3
10 import [math/number-theory]
20 print [nth-prime](15)
30 print [prime?](24)
40 import [racket/base]
50 print [max](f(1), f(2), f(5), f(4))
60 def f(x) = x + x