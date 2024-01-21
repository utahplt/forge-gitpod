#lang pythonesque-demo

"escaped quote: middle \" and end \""
"escaped backslash: middle \\ and end \\"

def nothing():
  42

def fortytwo():
  return 42

def eightyfour():
  return 84
  def noop():
    return "double dedent next"

nothing() # no output

if fortytwo() < eightyfour():
  "left is less than right"
else:
  "left is not less than right"

def last():
  return 42
  def noop():
    return "double dedent next"