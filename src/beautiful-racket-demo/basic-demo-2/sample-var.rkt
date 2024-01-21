#lang basic-demo-2
10 a = 1 : a = 5
20 gosub 150
30 a = 25
40 gosub 150
50 end
150 print a + a + a
160 return