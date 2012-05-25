# How to Get It

Wyld is still *very early on in development* and missing several major
features.  Once it reaches a more useable state, binaries will be
available for download.  Until then, you will have to *compile it
yourself.*

## Requirements

Before you compile this, you will need:

* A D compiler (`gdc` is recommended)
* Development packages for ncurses (on Ubuntu: `libncurses5-dev`)

## Compiling

To compile:

    cd Wyld
    gdc wyld/*.d -I ncs/ -o main -l curses

## Running

To run the game:

    cd Wyld
    ./main
