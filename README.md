# cnsFormatPainter

A Cadence Skill script to copy and paste component property visibility and location in DEHDL

---
## Introduction

The intention behind this script is to create an easy way to display component properties on your schematic, by copying the visibility and location from a similar component, similar what the Microsoft Office tools' format painter does.

---
## Running the command (Skill console method)

1. Copy the file "cnsFormatPainter.il" into the project directory.

2. In the DEHDL console, type `system`

3. A cmd window opens. type `start cnskill -i -nongraph`

4. The Skill console opens. Close the cmd window from the previous step to give control back to DEHDL.

5. Use `load("cnsFormatPainter.il")` to load the Skill script.

6. Invoke the format painter command by using the `formatPainter()` function call.

7. Follow the prompts in the DEHDL console to copy property visibility between components.

## Running the command (DEHDL command method)

1. Copy the files "cnsFormatPainter.il" and "startup.scr" into the project directory.

2. The "startup.scr" script creates a DEHDL command which invokes a Skill interpreter, connects it to the running DEHDL session, and calls the formatPainter() function in the Skill script. You can manually run the startup script by typing `script startup.scr` into the DEHDL console, or you can have DEHDL automatically run the script at startup:

     * Add "startup.scr" to the "Tools > Options > Input Script:" entry.

3. The `formatPainter` command is now available for use in editing your schematic.

     * Option 1: type `formatPainter` into the DEHDL console.
     * Option 2: assign the command to a key stroke.

         * Open Tools > Customize > Commands. Click "New" and give the command a name.
         * Enter "formatPainter" in the "Command String" window.
         * Open the "Keys" tab and select the new command from the list.
         * Click the "Press New Key" field, enter the keystroke you want to use, and click "Add Key."

## Usage

1. Invoke the formatPainter command using the keystroke you added, or enter `formatPainter` in the DEHDL console.

2. Click a component to compy from

3. Click a component to paste visibility to. Continue clicking components until you're done. Click away from any component to finish.