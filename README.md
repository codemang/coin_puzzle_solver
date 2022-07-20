Coin Puzzle Solver
=

This is a ruby script that solves a tricky coin puzzle.

## The Puzzle

Once upon a time, my brother-in-law gave me a puzzle to solve.

You are given 13 coins. All the coins weigh the same, except for one coin.
Importantly, you do not know whether that coin will be heavier or lighter than
the other coins. You are given a balance beam scale and can weigh the coins in
any way you like.

**Your goal is to figure out what is the minimum number of times you must use the
scale in order to always find the coin with the incorrect weight.**

## Usage

1. Install Ruby gems.

    ```bash
    $ bundle i
    ```

2. Run the general solve script.

    ```bash
    $ bin/solve_puzzle
    ```

## Developing

Running this script can take 1-2 minutes, as the solver uses a Dynamic
Programming approach to create permutations of puzzle states and a
score representing their distance from the solution.

Therefore, it can be helpful to generate the permutations once and save them to
disk:

```bash
$ bin/save_puzzle_states
```

Then you can run the solve script and tell it to read from disk.

```bash
$ bin/solve_puzzle -r
```
