
/** 
 * Searching backend.
 */

import core.thread : sleep;
// import core.time : dur;
import std.concurrency;
import std.stdio;
import std.variant : Variant;

import board : Board, Color, Peg;

class Engine {

  void search() {
    auto i = 0;

    while (1) {
      receiveTimeout (0,
        &this.handleAction,
        (Variant any) { assert(false); });

      // one iteration 
      i++;

      if (mShouldStop)
        break;
      
      sleep(1);
    }
  }

  Peg getBestMove() {
    return Peg(0, 0, Color.white);
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

  private:
    bool mShouldStop = false;
}
