#lang basic-demo-nth

3 print TAB(33);"Chemist"
6 print TAB(15);"Creative Computing | Morristown, New Jersey"
8 print:print:print
10 print "The fictitious chemical kryptocyanic acid can only be"
20 print "diluted by the ratio of 7 parts water to 3 parts acid."
30 print "if any other ratio is attempted, the acid becomes unstable"
40 print "and soon explodes. Given the amount of acid, you must"
50 print "decide who much water to add for dilution. If you miss,"
60 print "you face the consequences."
100 A=INT(RND(50))
110 W=7*A/3
115 if A=1 then P="liter" else P="liters"
120 print A; " "; P ; " of kryptocyanic acid. How much water?";
130 input R
140 D=ABS(W-R)
150 if D>W/20 then 200
160 print "Good job! You may breathe now, but don't inhale the fumes!"
170 print
180 goto 100
200 print "Sizzle! You have just been desalinated into a blob"
210 print "of quivering protoplasm!"
220 T=T+1
230 if T=3 then 260
240 print "However, you may try again with another life."
250 goto 100
260 print "Your 3 lives are used, but you will be long remembered for"
270 print "your contributions to the field of comic-book chemistry."
280 end