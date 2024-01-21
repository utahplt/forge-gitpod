#lang brag
#:prefix-out my:

;; Simple baby example of JSON structure
json: number | string
    | array
    | @object
number: NUMBER

string: STRING

array: "[" [json ("," json)*] "]"

object: /"{" [kvpair ("," kvpair)*] /"}"

@kvpair : /ID colon /json

/colon : ":"
