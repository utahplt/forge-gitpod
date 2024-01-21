#lang forge

sig A { r: set A }
--fact r: func

<sig label="A" ID="4" parentID="2">
    <atom label="A0"/><atom label="A1"/><atom label="A2"/><atom label="A3"/>
    <atom label="A4"/><atom label="A5"/><atom label="A6"/><atom label="A7"/>
    <atom label="A8"/><atom label="A9"/>
</sig>
<field label="r" ID="5" parentID="4">
    <tuple><atom label="A0"/><atom label="A9"/></tuple>
    <tuple><atom label="A1"/><atom label="A9"/></tuple>
    <tuple><atom label="A2"/><atom label="A8"/></tuple>
    <tuple><atom label="A3"/><atom label="A7"/></tuple>
    <tuple><atom label="A4"/><atom label="A6"/></tuple>
    <tuple><atom label="A5"/><atom label="A5"/></tuple>
    <tuple><atom label="A6"/><atom label="A9"/></tuple>
    <tuple><atom label="A7"/><atom label="A9"/></tuple>
    <tuple><atom label="A8"/><atom label="A8"/></tuple>
    <tuple><atom label="A9"/><atom label="A7"/></tuple>
</field>

leaf: A = A-A.r
fixp: A = (r & iden).A
    
run {} for exactly 10 A

