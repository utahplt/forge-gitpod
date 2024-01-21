#lang basic-demo-nth
10 X = 3
20 on X gosub 210, 220, 230
21 print "yay"
22 end
210 print "one"
211 return
220 print "two"
221 return
230 print "three"
231 return