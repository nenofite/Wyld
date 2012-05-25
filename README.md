# Installing

## Requirements

Before you compile this, you will need:

* A D compiler (gdc is what I use)
* Development packages for ncurses

## Compiling

To compile:

    cd Wyld
    gdc wyld/*.d -o main -l curses

## Running

To run the game:

    cd Wyld
    ./main
