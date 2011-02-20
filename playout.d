
/**
 * Playout mechanisms.
 */

import std.array : empty, front, popFront;
import std.stdio;
import std.datetime : systime;
import std.random : Random, randomShuffle;
import std.math : floor;
import std.conv : to;

import std.c.time : clock;

import logger;
import board: Board, Color, flipColor;

private {
  Logger lgr;
}

static this() {
  lgr = new Logger(__FILE__, LogLevel.LL_INFO);
}

/// UCT doesn't care where does the evaluation come from
//  it can very well be playout or static analyzis
interface IEvaluator {
  // <-1, 1> where -1 is win for white and 1 win for black
  double evaluate();
}

/// The simplest approach - K times generate random move
/// afterwards check for the winner
class SimplePlayout : IEvaluator {

public:
  this (Board board, int maxLength, ref Random gen) {
    mBoard = new Board(board);
    mMaxLength = maxLength;
    mFieldsNum = mBoard.getSize() * mBoard.getSize();
    mGenerator = &gen;
    mMoves.length = mFieldsNum;
    foreach(i; 0 .. mFieldsNum - 1)
      mMoves[i] = i;
    randomShuffle(mMoves, *mGenerator);
  }

  override double evaluate() {
    // TODO get color to start
    Color color = Color.white; 
    for(int i = 0; i < mMaxLength; i++) {
      if(step(color, i)) 
      {
        color = flipColor(color);
        // writeln(mBoard.toString());
      }
      else {
        (*mGenerator).popFront();
      }
    }

    auto winner = mBoard.getWinner();

    lgr.dbug("playout finished: winner(%s)", winner);

    switch (winner) {
      case Color.white: return -1;
      case Color.black: return 1;
      case Color.empty: return 0;
    }
  }

private:
  // select move and play
  // returns true if step was performed
  bool step(Color color, uint stepNum) {
    // super simplified
    // int peg = to!int(floor((*mGenerator).front()) % mFieldsNum);
    if (mMoves.empty)
      return false;
    int peg = mMoves.front();
    mMoves.popFront();

    lgr.trace("simple playouter: step(%d) color(%s) peg(%s)",
        stepNum, color, peg);

    return mBoard.placePeg(peg, color);
  };

private:

  // after more moves than this wincheck is performed
  uint mMaxLength;

  // board needs to be able to 
  // - give list / range of available moves 
  // - play the peg
  // - check winner
  Board mBoard;

  // Mersenne Twister engine with predefined values
  Random* mGenerator;

  // number of fields on the board used for move generation
  int mFieldsNum;

  // all the moves that can be played
  int[] mMoves;
}

