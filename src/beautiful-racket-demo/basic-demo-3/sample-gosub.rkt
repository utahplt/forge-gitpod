#lang basic-demo-3
10 gosub 41
20 print "second"
30 gosub 100
31 print "fourth"
35 end
40 return
41 print "first" : return
100 print "third"
110 goto 40