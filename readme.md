## Solutions

### [Random Hunt and Adjacent Targeting](https://github.com/steelThread/battle-group/blob/master/algos/adjacent_targeting.rb)

Uses a random hunt with adjacent targeting.  Hunting uses a parity (checkboard)
based approach.  When a hit is observed, all of the adjacent cells not already
visited are searched until there are no more focused targets at which point the
hunt continues

60 - 65 shot average per win (not emprical)

### [Density Hunt and Targeting](https://github.com/steelThread/battle-group/blob/master/algos/probability_targeting.rb)

Employs a probablistic solution based on density using a little linear
algebra.  During each round of the game a density matrix is built for
the individual pieces still in play by determining all possible positions
on the board that a piece can fit.  Each element in the matrix is a sum of
the # of times the piece could be positioned there in both orientations.  All
individual matrices are then summed up to provide an overall density picture.

While hunting, the densest positions in the matrix are visited first.
If more than one position is found, a random sample is taken from the
set.  Once a hit is observed the targeting initially uses the density info
to order the adjacent cells to attack. After two or more hits, the algorithm
will favor vertical and horizontal targets based on the hit pattern.  If this can't
be determined (no single horizontal or vertical path) the density values
are again used to order target positions.

40 - 50 shot average per win (not emprical)

----

## Installation

Clone the repo

```bash
$ git clone https://github.com/steelThread/battle-group.git
$ cd battle-group
```

----
## Running

Requires Ruby 1.9, I'm using 1.9.3p286.  The player will connect to a local rails server.  To
change just update the [code](https://github.com/steelThread/battle-group/blob/master/battle_group.rb#L295).

```bash
$ ruby battle_group.rb
```