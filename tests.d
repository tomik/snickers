
/** "See-object-from-outside" level tests. */

import std.stdio;

import board;

// board loading and dumping

// empty board
unittest {

 string inBoard =
  ".__|.___.___.___.___.__|.__
   .  |.   .   .   .   .  |.
   .  |.   .   .   .   .  |.
   .  |.   .   .   .   .  |.
   .  |.   .   .   .   .  |.
   .__|.___.___.___.___.__|.__
   .  |.   .   .   .   .  |.";
  
 Board board = new Board(inBoard);
 assert(board.toString() == Board.normStrBoard(inBoard));
}

unittest {

 string inBoard =
  ".__|.___W1__.___.___.__|.__
   Ba |.   .   .   b   W1 |.
   .  |.   Ba  W1  .   .  |.
   .  |W1  .   .   .   .  |.
   .  |.   .   .   .   .  |.
   .__|.___W1__.___.___.__|.__
   .  |.   .   .   W1  .  |.";
  
 Board board = new Board(inBoard);
 assert(board.toString() == Board.normStrBoard(inBoard));
}

// multiple groups for one player
unittest {

 string inBoard =
  ".__|.___W1__.___.___.__|.__
   Ba |.   .   .   b   W1 |.
   .  |.   Ba  W1  .   .  |.
   .  |W1  .   .   .   .  |.
   .  |.   .   .   .   W2 |.
   .__|.___.___.___.___.__|.__
   .  |.   .   .   W2  .  |.";
  
 Board board = new Board(inBoard);
 assert(board.toString() == Board.normStrBoard(inBoard));
}

// special situation with group overlap
unittest {

 string inBoard =
  ".__|.___.___W1__.___.__|.__
   .  |.   .   .   .   W1 |. 
   .  |.   W1  Ba  .   .  |.
   .  |.   .   .   W1  .  |.
   .  |.   Ba  .   Ba  .  |.
   .__|.___.___.___.___.__|.__
   .  |.   .   .   .   .  |.";
  
 Board board = new Board(inBoard);
 assert(board.toString() == Board.normStrBoard(inBoard));
}

unittest {

 string inBoard =
  ".__|.___W1__.__|.__
   Ba |.   .   .  |.
   .  |.   Ba  W1 |.
   .__|.___w___.__|Ba_
   .  |.   .   w  |.";
  
 Board board = new Board(inBoard);
 assert(board.toString() == Board.normStrBoard(inBoard));
}

// placing a peg

unittest {

 string inBoard =
  ".__|.___W1__.__|.__
   Ba |.   .   .  |.
   .  |.   Ba  W1 |.
   .__|.___.___.__|Ba_
   .  |.   w   w  |.";
  
 string outBoard =
  ".__|.___W1__.__|.__
   Ba |.   .   .  |.
   .  |.   Ba  W1 |.
   .__|W2__.___.__|Ba_
   .  |.   w   W2 |.";

 Board board = new Board(inBoard);
 assert(board.toString() == Board.normStrBoard(inBoard));

 // there is a peg already
 auto placed = board.placePeg(22, Color.white);
 assert(!placed);

 // valid
 placed = board.placePeg(16, Color.white);
 assert(placed);
 assert(board.toString() == Board.normStrBoard(outBoard));
}

// placing peg connects groups
unittest {

 string inBoard =
  ".__|.___W1__.___.___.__|.__
   .  |.   .   .   W1  W2 |. 
   Ba |.   b   .   w   .  |.
   .  |Bb  Ba  .   W2  .  |b
   .  |.   .   .   .   .  |.
   Bb_|.___w___.___W3__.__|.__
   .  |.   W3  .   .   .  |.";

 // white places peg
 string outBoard1 =
  ".__|.___W1__.___.___.__|.__
   .  |.   .   .   W1  W2 |. 
   Ba |.   b   .   w   .  |.
   .  |Bb  Ba  W1  W2  .  |b
   .  |.   .   .   .   .  |.
   Bb_|.___W1__.___W1__.__|.__
   .  |.   W1  .   .   .  |.";

 // black places peg
 string outBoard2 =
  ".__|.___W1__.___.___.__|.__
   .  |.   .   .   W1  W2 |. 
   Ba |.   b   .   w   .  |.
   .  |Bb  Ba  .   W2  .  |Ba
   .  |.   .   .   Ba  .  |.
   Bb_|.___w___.___W3__.__|.__
   .  |.   W3  .   .   .  |.";

 Board board = new Board(inBoard);
 assert(board.toString() == Board.normStrBoard(inBoard));

 // white
 auto placed = board.placePeg(24, Color.white);
 assert(placed);
 assert(board.toString() == Board.normStrBoard(outBoard1));

 board = new Board(inBoard);
 // black
 placed = board.placePeg(32, Color.black);
 assert(placed);
 assert(board.toString() == Board.normStrBoard(outBoard2));
}

// determining a winner

