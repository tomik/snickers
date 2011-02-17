
/** "See-object-from-outside" level tests. */

import std.stdio;

import board;

// board loading

unittest {

 string strBoard =
  ".__|.___.___.___.___.__|.__
   .  |.   .   .   .   .  |.
   .  |.   .   .   .   .  |.
   .  |.   .   .   .   .  |.
   .  |.   .   .   .   .  |.
   .__|.___.___.___.___.__|.__
   .  |.   .   .   .   .  |.";
  
 Board board = new Board(strBoard);
 assert(board.toString() == Board.normStrBoard(strBoard));
}

unittest {

 string strBoard =
  ".__|.___W1__.___.___.__|.__
   Ba |.   .   .   b   W1 |.
   .  |.   Ba  W1  .   .  |.
   .  |W1  .   .   .   .  |.
   .  |.   .   .   .   .  |.
   .__|.___W1__.___.___.__|.__
   .  |.   .   .   W1  .  |.";
  
 Board board = new Board(strBoard);
 assert(board.toString() == Board.normStrBoard(strBoard));
}

// special situation with group overlap

unittest {

 string strBoard =
  ".__|.___.___W1__.___.__|.__
   .  |.   .   .   .   W1 |. 
   .  |.   W1  Ba  .   .  |.
   .  |.   .   .   W1  .  |.
   .  |.   Ba  .   Ba  .  |.
   .__|.___.___.___.___.__|.__
   .  |.   .   .   .   .  |.";
  
 Board board = new Board(strBoard);
 // writeln(Board.normStrBoard(strBoard));
 // writeln(board.toString());
 assert(board.toString() == Board.normStrBoard(strBoard));
}

unittest {

 string strBoard =
  ".__|.___W1__.__|.__
   Ba |.   .   .  |.
   .  |.   Ba  W1 |.
   .__|.___w___.__|Ba_
   .  |.   .   w  |.";
  
 Board board = new Board(strBoard);
 // writeln(Board.normStrBoard(strBoard));
 // writeln(board.toString());
 assert(board.toString() == Board.normStrBoard(strBoard));
}

// placing a peg

// determining a winner


/*
  unittest { 
    Board board = new Board(7);
    auto f = (int x, int y) { return board.calcBridgeId(x, y); };
    board.mPegs[Color.white][2] = 1;
    board.mPegs[Color.white][12] = 1;
    board.mPegs[Color.white][17] = 1;
    board.mPegs[Color.white][22] = 1;
    board.mPegs[Color.white][37] = 1;
    board.mPegs[Color.white][46] = 1;

    board.mBridges[f(2, 17)] = 1;
    board.mBridges[f(17, 12)] = 1;
    board.mBridges[f(17, 22)] = 1;
    board.mBridges[f(22, 37)] = 1;
    board.mBridges[f(37, 46)] = 1;

    board.mPegs[Color.black][7] = 1;
    board.mPegs[Color.black][11] = 1;
    board.mPegs[Color.black][16] = 1;
    board.mBridges[f(7, 16)] = 1;
  }

*/
