#lang hdl-demo

CHIP Fanout {
         IN in;
            OUT outa, outb;
            
            PARTS:
            And(a=in, b=in, out=outa);
            And(a=in, b=in, out=outb);
            
            }

