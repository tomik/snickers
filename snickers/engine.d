
/** 
 * Searching management.
 *
 * Class engine provides neccessary administration for the search itself.
 * This includes: random number generator, spawning 
 */

import core.thread : sleep;
import core.time : dur;
import std.concurrency;
import std.datetime : StopWatch;
import std.stdio;
import std.string : format;
import std.random : Random, unpredictableSeed;
import std.variant : Variant;
import std.typecons : Tuple, tuple;

import board : Board, Color, flipColor, Peg;
import playout : BBPlayout;

const int TIME_PER_MOVE = 5;

struct SearchStats {
  Peg mBestMove;
  // in milliseconds
  double mTimeElapsedMls;
  int mPlayouts;
  double mWinConfidence;

  string toString() {
    return format("playouts: %s | time: %s | confidence: %s",
             mPlayouts, mTimeElapsedMls, mWinConfidence);
  }
}

class Engine {

  void search(string boardStfStr) {
    mBoard = Board.fromStfString(boardStfStr); 
    mStats.length = mBoard.fieldsNum;
    mStats[1 .. $] = tuple(0.0, 0);
    Random gen = Random(unpredictableSeed);
    Color color = mBoard.toMove;
    StopWatch sw;

    auto i = 1;
    int playouts = 0;

    sw.start();

    while (1) {
      if (i % mSearchInterrupt == 0)
      {
        receiveTimeout (0,
          &this.handleAction,
          (Variant any) { assert(false); });

        if (!mShouldStop && sw.peek().seconds > TIME_PER_MOVE) {
          mShouldStop = true;
        }

        if (mShouldStop)
        {
          mSearchStats.mBestMove = getBestMove();
          mSearchStats.mPlayouts = playouts;
          mSearchStats.mTimeElapsedMls = sw.peek().msecs / 1000.0;
          mSearchStats.mWinConfidence = 0.5;
          return;
        }
      }

      // one iteration 
      i++;

      // run a playout from random place on the board 
      auto pos = gen.front() % mBoard.fieldsNum;
      gen.popFront();
      auto peg = Peg(pos % mBoard.size, pos / mBoard.size, color);  
      if (!mBoard.isValidPeg(peg))
        continue;

      playouts++;

      Board playoutBoard = new Board(mBoard); 
      playoutBoard.placePeg(peg);
      BBPlayout playout = new BBPlayout(playoutBoard, 100, gen);
      double result = playout.run();
      mStats[pos][1] += 1; 
      mStats[pos][0] += result; 
    }
  }

  SearchStats getSearchStats() {
    return mSearchStats;
  }

  Peg getBestMove() {
    int bestIndex = 0;
    double bestEval = 0;
    double mult = mBoard.toMove == Color.white ? 1 : -1;

    debug {
      writefln("evaluation for color(%s)", mBoard.toMove);
    }

    for (auto i = 0; i < mStats.length; i++) {
      if (mStats[i][1] && (mStats[i][0] / mStats[i][1]) < bestEval) {
        bestIndex = i;
        bestEval = mStats[i][0] / mStats[i][1];
        debug {
          writefln("best eval is now %f based on %d playouts", bestEval, mStats[i][1]);
        }
      }
    }

    return Peg(bestIndex % mBoard.size, bestIndex / mBoard.size, mBoard.toMove);
  }

  Peg[] getPV() {
    return [];
  }

  void handleAction(Tid sender, string action) {
    switch (action) {
      case "stop": 
        mShouldStop = true;
        break;

      case "bestmove": 
        sender.send(getBestMove());  
        break;

      default:
        assert(false);
    }
  }
  
  protected:
    int mSearchInterrupt = 10;

  private:
    bool mShouldStop = false;
    // victory statistics for particular fields 
    // sum of score vs. total games
    Tuple!(double, int)[] mStats;
    Board mBoard;
    SearchStats mSearchStats;
}


