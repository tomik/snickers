
import core.thread : sleep, Thread;
import std.concurrency;
import std.conv : to, ConvException;
import std.random : Random, unpredictableSeed;
import std.string : format, split;

import board : Board, BoardException, Peg;
import playout;
import tei : CtrlMsg, ICtrl, Reply, Feed, IFeedHandler;
import engine : Engine;

class Control : ICtrl {

  Reply HandlePing(CtrlMsg msg) {
    return Reply(true);
  }

  Reply HandleGetStf(CtrlMsg msg) {
    return Reply(true, mBoard.toStfString());
  }

  Reply HandleGetSgf(CtrlMsg msg) {
    return Reply(true, mBoard.toSgfString());
  }

  Reply HandleQuit(CtrlMsg msg) {
    Reply r;
    r.ok = true;
    r.shutdown = true;
    return r;
  }

  // handlers
  
  Reply HandleNewGame(CtrlMsg msg) {
    string sizeStr = msg.args.length ? msg.args : "24";
    int size;
    try {
      size = to!int(sizeStr);
    } catch (ConvException)
      return Reply(false, format("can't parse board size from str %s", sizeStr));
    mBoard = new Board(size);
    return Reply(true);
  }

  // this is an atomic function - either all pegs are played or none
  // this is achieved by board copying
  Reply HandlePlay(CtrlMsg msg) {
    string moves = msg.args;
    Board backup = new Board(mBoard);
    try {
      foreach (pegStr; split(moves)) {
        mBoard.placePeg(Peg(pegStr)); 
      }
    } catch (BoardException e) {
      // revert to previous board
      mBoard = backup;
      return Reply(false, e.msg);
    }
    return Reply(true);
  }
  
  Reply HandleGo(CtrlMsg msg) {
    // TODO didn't find a way to create an immutable/shared copy of the board object
    // for now just passing a string representation from which object can be reconstructed
    string repr = mBoard.toStfString();
    mSearchTid = spawnLinked!(string, shared IFeedHandler)(&startSearchInThread, repr, mFeedHandler);
    return Reply(true);
  }

  Reply HandleStop(CtrlMsg msg) {
    // join the thread
    mSearchTid.send(thisTid, "stop");
    auto end = receiveOnly!LinkTerminated();
    return Reply(true);
  }

  Reply HandleGetBest(CtrlMsg msg) {
    mSearchTid.send(thisTid, "bestmove");
    auto peg = receiveOnly!Peg();
    return Reply(true, format("%s", to!string(peg)));
  }

  Reply HandleGetBoard(CtrlMsg msg) {
    return Reply(true, format("\n%s", mBoard.toString()));
  }

  Reply HandleDoPlayout(CtrlMsg msg) {
    string maxLengthStr = msg.args.length ? msg.args : "0";
    int maxLength;
    try {
      maxLength = to!int(maxLengthStr); 
    } catch (ConvException e) {
      return Reply(false, format("invalid maxLength definition %s", maxLengthStr)); 
    }

    if (maxLength <= 0)
      maxLength = mBoard.size * 7;
    BBPlayout pl = new BBPlayout(mBoard, maxLength, Random(unpredictableSeed()));
    pl.run();
    mBoard = pl.getBoard();
    return Reply(true);
  }
  
  static void startSearchInThread(string boardStr, shared IFeedHandler mFeedHandler) {
    Engine engine = new Engine();
    engine.search(boardStr);
    mFeedHandler.HandleSearchDoneFeed(Feed("bestmove", engine.getBestMove().toString()));
    // only for logging
    mFeedHandler.HandleSearchDoneFeed(Feed("stats", engine.getSearchStats().toString(), true));
  }

  void SetFeedHandler(shared IFeedHandler fh) {
    mFeedHandler = fh;
  }

  private:
    Board mBoard;
    Tid mSearchTid;
    shared IFeedHandler mFeedHandler;
}

