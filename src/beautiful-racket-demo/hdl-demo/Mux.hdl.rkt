#lang hdl-demo

// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/01/Mux.hdl

/** 
 * Multiplexor:
 * out = a if sel == 0
 *       b otherwise
 */

CHIP Mux {
    IN a, b[15], sel[8];
    OUT out;

    PARTS:
    Not(in=sel, out=not-sel);
    And(a=a, b=not-sel, out=a-and-not-sel);
	And(a=b, b=sel, out=b-and-sel);
	Or(a=a-and-not-sel, b=b-and-sel, out=out);
}
