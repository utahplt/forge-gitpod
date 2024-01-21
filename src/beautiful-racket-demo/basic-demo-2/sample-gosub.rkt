#lang basic-demo-2
10 gosub 41
20 print "world"
30 gosub 100
31 print "hi"
35 end
40 return
41 print "hello" : return
100 print "third"
110 goto 40