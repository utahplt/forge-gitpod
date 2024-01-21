#lang brag

top : statement*
@statement : func-def | expr | return | if
func-def : /"def" var /"(" ids /")" /":" block
/ids : [var (/"," var)*]
block : /INDENT statement* /DEDENT
@expr : comparison
comparison : [comparison "<"] value
@value : var | INT | func-app | STRING
func-app : var /"(" exprs /")"
@exprs : [expr (/"," expr)*]
return : /"return" expr
if : /"if" expr /":" block [/"else" /":" block]
@var : ID