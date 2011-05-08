
/**
 * Control module which handles interaction with engine controller (user, web interface, gui).
 * This is command-line-like interface inspired by aei (http://arimaa.janzert.com/aei/aei-protocol.html)
 *
 * Protocol is named TEI (Twixt Engine Interface)
 */

import std.array : empty;
import std.stdio;
import std.string : indexOf, format, strip;
import std.variant : Variant;

import logger;
import types : SystemExit;

private { 
  Logger lgr; 
  static this() { 
    lgr = new Logger(__FILE__, LogLevel.LL_DEBUG);
  }
}

struct CtrlMsg {
  string command;
  string args;
}

enum TakesArgs {
  yes,
  no,
  maybe
}

struct Reply {
  bool ok; 
  string args;
  bool shutdown;

  string toString() {
    string s = ok ? "ok" : "nok";
    return (s ~ " " ~ args).strip();
  }
}

// asynchronous data from the controller
// i.e. game termination
struct Feed {
  string name;
  string args;
  bool isLog;

  string toString() {
    return (name ~ " " ~ args).strip();
  }
}

// interface for control handlers
// this is called by the protocol parser 
interface ICtrl {
  Reply HandlePing(CtrlMsg msg);
  Reply HandleNewGame(CtrlMsg msg);
  Reply HandlePlay(CtrlMsg msg);
  Reply HandleGo(CtrlMsg msg);
  Reply HandleStop(CtrlMsg msg);
  Reply HandleGetBest(CtrlMsg msg);
  Reply HandleGetStf(CtrlMsg msg);
  Reply HandleGetSgf(CtrlMsg msg);
  Reply HandleGetBoard(CtrlMsg msg);
  Reply HandleDoPlayout(CtrlMsg msg);
  Reply HandleQuit(CtrlMsg msg);
  void SetFeedHandler(shared IFeedHandler);
}

interface IFeedHandler {
  synchronized void HandleSearchDoneFeed(Feed feed);
}

class TeiParser {

  enum State {
    init,
    game,
    search,
    // meta states
    any,
    same
  }

  // control record defining control FA
  // state + command -> new state + action
  struct Record {
    State mState;
    string mCommand;
    State mNewState;
    TakesArgs takesArgs;
    Reply delegate (CtrlMsg) mAction;
    // command arguments are stored in object control
  }

  this(ICtrl ctrl) {
    mRecords ~= Record(State.any, "ping", State.same, TakesArgs.no, &ctrl.HandlePing);
    // creates new game, arguments are expected to be cols rows (default 24 24)
    mRecords ~= Record(State.init, "newgame", State.game, TakesArgs.maybe, &ctrl.HandleNewGame);
    mRecords ~= Record(State.game, "newgame", State.game, TakesArgs.maybe, &ctrl.HandleNewGame);
    // plays given pegs in order 
    // peg is in format colrow alpha for col (big for black), num for row
    // i.e. play r7 S12 g5 J18
    mRecords ~= Record(State.game, "play", State.game, TakesArgs.yes, &ctrl.HandlePlay);
    // start the search in a separate thread
    mRecords ~= Record(State.game, "go", State.search, TakesArgs.no, &ctrl.HandleGo);
    // returns best move during/after ongoing search
    mRecords ~= Record(State.search, "getbest", State.search, TakesArgs.no, &ctrl.HandleGetBest);
    // stop current search and output best move so far
    mRecords ~= Record(State.search, "stop", State.game, TakesArgs.no, &ctrl.HandleStop);
    mRecords ~= Record(State.game, "getstf", State.game, TakesArgs.no, &ctrl.HandleGetStf);
    mRecords ~= Record(State.game, "getsgf", State.game, TakesArgs.no, &ctrl.HandleGetSgf);
    // stop the session and quit program
    mRecords ~= Record(State.any, "quit", State.same, TakesArgs.no, &ctrl.HandleQuit);
    // TODO loads game from file
    // mRecords ~= Record(State.init, "loadgame", State.game, () {;});
    // mRecords ~= Record(State.game, "setoption", State.game, () {;});
    // mRecords ~= Record(State.search, "getpv", State.search, &this.getPV);
    // analytic functions on board
    mRecords ~= Record(State.game, "getboard", State.game, TakesArgs.no, &ctrl.HandleGetBoard);
    // runs one playout in the same thread
    mRecords ~= Record(State.game, "doplayout", State.game, TakesArgs.no, &ctrl.HandleDoPlayout);

    mState = State.init;


    mWriter = new shared(Writer);
    mFeedHandler = new shared(FeedHandler)(mWriter);
    
    mCtrl = ctrl;
    mCtrl.SetFeedHandler(mFeedHandler);
  }

  void runInputLoop() {
    char[] buf;
    // TODO only in command-line mode - without control file
    // write("> ");

    while (readln(buf)) {
      lgr.info("received %s", buf);
      dispatch(strip(buf));
      // write("> ");
    }
  }

  void dispatch(const char[] line) {
    // parse the command name
    int index = indexOf(line, ' ');
    string cmd = strip(index == -1 ? line : line[0 .. index]).idup;
    string args = strip(index == -1 ? "" : line [index + 1 .. $]).idup;
    // select record
    Record *record = null;

    foreach (r; mRecords) {
      if (r.mCommand == cmd &&
         (mState == r.mState || r.mState == State.any)) {
        record = &r;
        break;
      }
    }

    if (!record) {
      mWriter.output(Reply(false, format("command %s not applicable", cmd)).toString());
      return;
    }

    if (!args.empty && record.takesArgs == TakesArgs.no) {
      mWriter.output(Reply(false, format("command %s expected to have no arguments", cmd)).toString());
      return;
    }

    if (args.empty && record.takesArgs == TakesArgs.yes) {
      mWriter.output(Reply(false, format("command %s expected to have arguments", cmd)).toString());
      return;
    }

    // pass message to handler
    Reply reply = record.mAction(CtrlMsg(cmd, args));
    if (reply.ok && record.mNewState != State.same) {
      mState = record.mNewState; 
    }
    mWriter.output(reply.toString());

    if (reply.shutdown)
      throw new SystemExit();
  }

  void log(string s) {
    mWriter.output("log " ~ s);
  }

  private:
    State mState;
    Record mRecords[];
    ICtrl mCtrl;
    shared Writer mWriter;
    shared FeedHandler mFeedHandler;
}

synchronized class Writer {

  void output(string msg) {
    outputRaw(" " ~ msg);
  }

  void outputRaw(string msg) {
    writeln(msg);
    stdout.flush();
    lgr.info("outputted %s", msg);
  }
}

synchronized class FeedHandler : IFeedHandler { 

  this(shared Writer w) {
    mWriter = w;
  }

  void HandleSearchDoneFeed(Feed feed) {
    if (feed.isLog) 
      mWriter.output("log " ~ feed.toString);
    else
      mWriter.output(feed.toString());
  }

  private:
    shared Writer mWriter;
}
