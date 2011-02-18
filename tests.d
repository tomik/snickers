
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

// check invalid moves 
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
  auto placed = false;

  // there is a white peg already
  assert(!board.placePeg(22, Color.white));

  // there is a black peg already
  assert(!board.placePeg(12, Color.white));

  // white can't play on side edges
   assert(!board.placePeg(5, Color.white));
   assert(!board.placePeg(9, Color.white));

  // black can't play on top/bottom edges
   assert(!board.placePeg(1, Color.black));
   assert(!board.placePeg(23, Color.black));

  // valid
  assert(board.placePeg(16, Color.white));
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
  auto placed = false;
  assert(board.placePeg(24, Color.white));
  assert(board.toString() == Board.normStrBoard(outBoard1));

  board = new Board(inBoard);
  // black
  assert(board.placePeg(32, Color.black));
  assert(board.toString() == Board.normStrBoard(outBoard2));
}

// play multiple moves in a row
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

  string[10] strBoards;
  int i = 0;

  strBoards[i] =
   ".__|.___.___.___.___.__|.__
    .  |.   .   .   .   .  |.
    .  |.   .   .   .   .  |.
    .  |.   .   .   w   .  |.
    .  |.   .   .   .   .  |.
    .__|.___.___.___.___.__|.__
    .  |.   .   .   .   .  |.";

  auto placed = false;
  assert(board.placePeg(25, Color.white));
  assert(board.toString() == Board.normStrBoard(strBoards[i]));

  strBoards[++i] =
   ".__|.___.___.___.___.__|.__
    .  |.   .   .   .   .  |.
    .  |.   b   .   .   .  |.
    .  |.   .   .   w   .  |.
    .  |.   .   .   .   .  |.
    .__|.___.___.___.___.__|.__
    .  |.   .   .   .   .  |.";

  assert(board.placePeg(16, Color.black));
  assert(board.toString() == Board.normStrBoard(strBoards[i]));

  strBoards[++i] =
   ".__|.___.___.___.___.__|.__
    .  |.   .   .   .   .  |.
    .  |.   b   .   .   .  |.
    .  |.   .   .   W1  .  |.
    .  |.   W1  .   .   .  |.
    .__|.___.___.___.___.__|.__
    .  |.   .   .   .   .  |.";

  assert(board.placePeg(30, Color.white));
  assert(board.toString() == Board.normStrBoard(strBoards[i]));

  strBoards[++i] =
   ".__|.___.___.___.___.__|.__
    .  |.   .   .   .   .  |.
    .  |.   b   .   .   .  |.
    .  |.   .   .   W1  .  |.
    .  |.   W1  b   .   .  |.
    .__|.___.___.___.___.__|.__
    .  |.   .   .   .   .  |.";

  assert(board.placePeg(31, Color.black));
  assert(board.toString() == Board.normStrBoard(strBoards[i]));

  strBoards[++i] =
   ".__|.___w___.___.___.__|.__
    .  |.   .   .   .   .  |.
    .  |.   b   .   .   .  |.
    .  |.   .   .   W1  .  |.
    .  |.   W1  b   .   .  |.
    .__|.___.___.___.___.__|.__
    .  |.   .   .   .   .  |.";

  assert(board.placePeg(2, Color.white));
  assert(board.toString() == Board.normStrBoard(strBoards[i]));

  strBoards[++i] =
   ".__|.___w___.___.___.__|.__
    .  |.   .   .   .   .  |.
    .  |.   b   .   .   .  |.
    .  |.   .   .   W1  .  |.
    .  |.   W1  Ba  .   .  |.
    .__|.___.___.___.___Ba_|.__
    .  |.   .   .   .   .  |.";

  assert(board.placePeg(40, Color.black));
  assert(board.toString() == Board.normStrBoard(strBoards[i]));

  strBoards[++i] =
   ".__|.___W1__.___.___.__|.__
    .  |.   .   .   .   .  |.
    .  |W1  b   .   .   .  |.
    .  |.   .   .   W1  .  |.
    .  |.   W1  Ba  .   .  |.
    .__|.___.___.___.___Ba_|.__
    .  |.   .   .   .   .  |.";

  assert(board.placePeg(15, Color.white));
  assert(board.toString() == Board.normStrBoard(strBoards[i]));

  strBoards[++i] =
   ".__|.___W1__.___.___.__|.__
    .  |.   .   .   Ba  .  |.
    .  |W1  Ba  .   .   .  |.
    .  |.   .   .   W1  .  |.
    .  |.   W1  Bb  .   .  |.
    .__|.___.___.___.___Bb_|.__
    .  |.   .   .   .   .  |.";

  assert(board.placePeg(11, Color.black));
  assert(board.toString() == Board.normStrBoard(strBoards[i]));

  strBoards[++i] =
   ".__|.___W1__.___.___.__|.__
    .  |.   .   .   Ba  .  |.
    .  |W1  Ba  .   .   .  |.
    .  |.   .   .   W1  .  |.
    .  |.   W1  Bb  .   .  |.
    .__|.___.___.___.___Bb_|.__
    .  |.   .   W1  .   .  |.";

  assert(board.placePeg(45, Color.white));
  assert(board.toString() == Board.normStrBoard(strBoards[i]));
}

// determining a winner

