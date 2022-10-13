# cnsFormatPainter
a Cadence Skill script to copy and paste component property visibility and location in DEHDL

This happened because, during an attempt to convert a schematic between two versions of DEHDL (16.9 to 17.2), the visibility of ALL component properties in the schematic was turned off. I don't want to touch each component in the schematic to turn the visibility back on and arrange each property in a sensible way, so I'm attempting to add some automation. Plus I get to learn the wonderful language, Cadence's "Skill."

use cnsHandle=cnmpsImport() to connect the skill engine to the DEHDL session that started the engine

in DEHDL console, type 'system'

a cmd window opens. type 'start cnskill -i -nongraph'

the skill console opens. close the cmd window from the previous step to give control back to DEHDL.

use load("cnsFormatPainter.il") to load this file

use 'ImportHandle=cnmpsImport()', gets a handle to the running DEHDL instance.

pass the handle to the procedures that use a DEHDL handle

TODO: attach the Skill function to a DEHDL command
