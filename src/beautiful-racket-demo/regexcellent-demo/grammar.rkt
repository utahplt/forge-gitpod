#lang brag

top : (/NEWLINE+ [line])* /NEWLINE*
line : [lookbehind] pat [lookahead]
pat : repeat+ | choice
lookbehind : /"(" /"?" /"<" /"=" pat /")"
lookahead : /"(" /"?" /"=" pat /")"
choice : pat (/"|" pat)+
repeat : repeatable [("*" | "+") ["?"] | "?"]
@repeatable : group | any | start | end | literal | chars
group : /"(" pat /")"
any : /"."
start : /"^"
end : /"$"
literal : LITERAL
chars : /"[" literal* /"]"