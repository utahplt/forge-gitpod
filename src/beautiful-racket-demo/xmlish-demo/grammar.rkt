#lang brag

top : @content
content : (tagged-element | /comment | string | sp)*

tagged-element : /"<" /sp? identifier attrs /sp? (short | full)
@short : /"/>"
@full : /">" content /"</" /sp? identifier /sp? /">"

attrs : [attr] (/sp attr)*
attr : identifier /sp? /"=" /sp? /"\"" string /"\""

comment	: "<!--" (string | sp)* "-->"

string : char+
identifier : ALPHANUMERIC [@string]

@sp : SP
@char : ALPHANUMERIC | OTHER | AMP | LT | GT | "=" | "\""
