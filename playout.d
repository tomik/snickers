
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
import board: Board, Color, FieldColor, flipColor, Peg;

private {
  Logger lgr;
}

static this() {
  lgr = new Logger(__FILE__, LogLevel.LL_INFO);
}

interface IPlayout {
  double run(Board board);
}

/// The simplest approach - K times generate random move
/// afterwards check for the winner
class SimplePlayout : IPlayout{

public:
  this(int maxLength, ref Random gen) {
    mMaxLength = maxLength;
    mFieldsNum = mBoard.size * mBoard.size;
    mGenerator = &gen;
    mEmptyPos.length = mFieldsNum;

    foreach (i; 0 .. mFieldsNum - 1)
      mEmptyPos[i] = i;
    randomShuffle(mEmptyPos, *mGenerator);
  }

  static string getName() { return "simplePlayout"; } 

  Peg[] getMoves() { return []; } 

  Board getBoard() { return mBoard; } 

  override double run(Board board) {
    mBoard = new Board(board);
    for (int i = 0; i < mMaxLength; i++) {
      step(i);
    }

    auto winner = mBoard.getWinner();

    lgr.dbug("playout finished: winner(%s)", winner);

    switch (winner) {
      case FieldColor.white: return -1;
      case FieldColor.black: return 1;
      case FieldColor.empty: return 0;
    }
  }

private:
  // select move and play
  // returns true if step was performed
  bool step(uint stepNum) {
    // super simplified
    if (mEmptyPos.empty)
      return false;
    int pos = mEmptyPos.front();
    mEmptyPos.popFront();

    debug { 
      lgr.trace("simple playouter: step(%d) color(%s) peg(%s)",
        stepNum, mBoard.toMove, pos); 
    }

    return mBoard.placePeg(pos);
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
  int[] mEmptyPos;
}

/**
 * Playout evaluator that is orientied on Building Bridges.
 *
 * It plays couple of first moves randomly and then biases moves to places pegs
 * forming a bridge from a previously placed peg.
 */

// TODO extract common patterns with SimplePlayout to a father class
class BBPlayout : IPlayout {

public:
  this(int maxLength, ref Random gen) {
    mMaxLength = maxLength;
    mGenerator = &gen;
    mInitialLength = 10;

    // used heuristics
    mHeurs.length = 2;
    mHeurs[0] = new NaivePathHeur(0);
    mHeurs[1] = new RandomHeur(1);
  }

  static string getName() { return "bbPlayout"; } 

  /// Retrieve moves after finished playout
  immutable (Peg[]) getMoves() const { return mBoard.getMoves(); } 

  Board getBoard() { return mBoard; } 

  override double run(Board board) {
    mBoard = new Board(board);
    // this is out parameter for stepFromLast and step
    int peg;

    // clean up and generalize this code (i.e. random-weighted elements)
    // how to handle shared datastructures in steps ? lastmove/active/etc.

    // in the beginning just throw couple of stones
    for (int i = 0; i < mInitialLength; i++) {
      // random step heur
      Heur heur = mHeurs[1];
      Color color = mBoard.toMove;
      bool placed = heur.apply(i, mLastMove, mLastHeur, mBoard, *mGenerator, peg);

      debug { 
        writefln("%s step by %s: step(%d) color(%s) peg(%s)",
          getName(), heur.getName(), i, color, peg); 
      }

      mLastMove[color] = peg;
      mLastHeur[color] = 1;
      debug { writeln(mBoard.toString()); }
    }

    for (int i = 0; i < mMaxLength - mInitialLength; i++) {
      foreach(hid, heur; mHeurs)
      {
        // TODO check if heuristic is to be applied based on weight
        Color color = mBoard.toMove;
        bool placed = heur.apply(i, mLastMove, mLastHeur, mBoard, *mGenerator, peg);

        debug { 
          writefln("%s step by %s: step(%d) color(%s) peg(%s)",
            getName(), heur.getName(), i, color, peg); 
        }

        if (placed)
        {
          mLastMove[color] = peg;
          mLastHeur[color] = hid;
          debug { writeln(mBoard.toString()); }
          break;
        }
      }
    }

    auto winner = mBoard.getWinner();
    lgr.dbug("playout finished: winner(%s)", winner);

    switch (winner) {
      case FieldColor.white: return -1;
      case FieldColor.black: return 1;
      case FieldColor.empty: return 0;
    }
  }

private:

  uint mMaxLength;
  uint mInitialLength;

  Board mBoard;

  Random* mGenerator;

  Heur mHeurs[]; 

  // state information by color
  int mLastMove[2];
  int mLastHeur[2];
}

/**
 * Heuristics are used to select moves in the playouts.
 * Typically there is more of them and playout selects a subset
 * of these to be applied for a particular move.
 * Heuristics don't have direct access to playouts state. All their
 * inputs are coming as arguments of apply method. 
 */

class Heur {
  public:
    abstract string getName();

    /**
     * Tries to find a move based on particular heuristic logic.
     * Returns: Whether a playable move was found. 
     * 
     * This is not a pure function because random generator state is altered.
     */
    abstract bool apply(
      uint stepNum,
      int[2] lastMove,
      int[2] lastHeur,
      ref Board,
      ref Random gen,
      out int peg);

    this(int hid) {
      mHid = hid;
    }

  protected: 
    int mHid;
}

/**
 * Heuristic for naive path building.
 * From a starting point tries to extend the path into
 * predefined direction.
 */

class NaivePathHeur : Heur {

public:
  this(int hid) { 
    super(hid);
  }
  
  override string getName() { return "NaivePathHeur"; }

  override bool apply(
    uint stepNum,
    int[2] lastMove,
    int[2] lastHeur,
    ref Board board,
    ref Random gen,
    out int peg) {

    int start;
    auto size = board.size;
    Color color = board.toMove;
    
    if(lastHeur[color] == mHid) {
      // continue in the naive path 
      start = lastMove[color];
    }
    else {
      // start a new naive path
      mRightOrDown[color] = gen.front() % 2 ? false : true;
      gen.popFront();

      // selects point on one of the edges
      auto off = gen.front() % (size - 1);
      gen.popFront();
      if (color == Color.white) {
        start = mRightOrDown[color] ? off : board.fieldsNum - 1 - off;
      } else {
        start = mRightOrDown[color] ? size * off : size * off + size - 1;
      }
    }

    peg = board.getPeerByStupidPath(start, color, mRightOrDown[color], gen);

    return board.placePeg(peg, color);
  }

private:
  bool mRightOrDown[2];

}

/**
 * Simplest heuristic selecting a random move to play;
 */
class RandomHeur : Heur {

public:
  this(int hid) { 
    super(hid);
  }

  override string getName() { return "RandomHeur"; }

  override bool apply(
    uint stepNum,
    int[2] lastMove,
    int[2] lastHeur,
    ref Board board,
    ref Random gen,
    out int peg) {

    peg = to!int(floor(gen.front()) % board.fieldsNum);
    gen.popFront();

    return board.placePeg(peg);
  }
}

/**
 * Heuristic selecting a random bridge from last played move by that player.
 */
class BridgeHeur : Heur {

public:
  this(int hid) { 
    super(hid);
  }

  override string getName() { return "BridgeHeur"; }

  override bool apply(
    uint stepNum,
    int[2] lastMove,
    int[2] lastHeur,
    ref Board board,
    ref Random gen,
    out int peg) {

    Color color = board.toMove;
    if (lastMove[color] == 0)
      return false;

    peg = board.getPeerByRandom(lastMove[color], color, gen);

    return board.placePeg(peg, color);
  }
}

import std.algorithm : joiner;
import std.file : File;
import std.random : unpredictableSeed;
import std.range : cycle, zip;
import std.string : replace;

import utils : pegToJsonStr;


/** Plays one game on large board with bbplayout 
 * and then dumps the moves into view_game.html template
 */
void runExamplePlayout() {

  int seed = unpredictableSeed();
  Random gen = Random(seed);
  writefln("generator seed is %s", seed);

  Board board = new Board(24);
  BBPlayout playout = new BBPlayout(75, gen); 
  auto res = playout.run(board);
  auto moves = playout.getMoves();
  string pegsJsonStr[];

  foreach (t; zip(moves, cycle([Color.white, Color.black])))
    pegsJsonStr ~= pegToJsonStr(t[0].mCol, t[0].mRow, t[1]);

  auto jsonPlayoutStr = "[" ~ to!string(joiner(pegsJsonStr, ", ")) ~ "]";
  // template for viewing page
  string t = "<script type='text/javascript'> <!-- \n"
             "window.location = 'file:///home/tomik/src/javascript/twixt/twixt.html?record={record}' \n"
             "//--> \n </script>";
  auto f = File("view_game.html", "w");
  f.write(t.replace("{record}", jsonPlayoutStr));
} 

