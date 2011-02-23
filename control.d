
/**
 * Control module which handles interaction with engine controller (user, web interface, gui).
 * This is command-line-like interface inspired by aei (http://arimaa.janzert.com/aei/aei-protocol.html)
 *
 * Protocol is named TEI (Twixt Engine Interface)
 */

import std.conv : to;
import std.array : empty;
import std.stdio;
import std.string : indexOf, format, split, strip;

import board : Board, BoardException, Peg;
import types : SystemExit;

class Control {

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
    void delegate () mNoArgsAction;
    void delegate (const char[] args) mArgsAction;
    // command arguments are stored in object control
  }
  
  this() {
    mRecords ~= Record(State.any, "ping", State.same, () {send("ok");});
    // creates new game, arguments are expected to be cols rows (default 24 24)
    mRecords ~= Record(State.init, "newgame", State.game, () {newGame();}, &this.newGame);
    mRecords ~= Record(State.game, "newgame", State.game, () {newGame();}, &this.newGame);
    // loads game from file
    // TODO
    mRecords ~= Record(State.init, "loadgame", State.game, () {;});
    mRecords ~= Record(State.game, "setoption", State.game, () {;});
    // plays given pegs in order peg is in format colrow
    // alpha for col (big for black), num for row
    // i.e. play r7 S12 g5 J18
    mRecords ~= Record(State.game, "play", State.game, null, &this.play);
    // start the search in a separate thread
    mRecords ~= Record(State.game, "go", State.search, &this.startSearch);
    // stop current search and output best move so far
    mRecords ~= Record(State.search, "stop", State.game, &this.stopSearch);
    mRecords ~= Record(State.any, "quit", State.same, () {send("bye"); throw new SystemExit();});
    mRecords ~= Record(State.game, "getboard", State.game, () {send(mBoard.toString());});
    // TODO
    mRecords ~= Record(State.game, "getsgf", State.game, () {;});

    mState = State.init;
  }

  void runInputLoop() {
    char[] buf;
    // TODO only in command-line mode - without control file
    write("> ");
    while (readln(buf)) {
      dispatch(strip(buf));
      write("> ");
    }
  }

  void dispatch(const char[] line) {
    // parse the command name
    int index = indexOf(line, ' ');
    const char[] cmd = strip(index == -1 ? line : line[0 .. index]);
    const char[] args = strip(index == -1 ? "" : line [index + 1 .. $]);

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
      log(format("command %s not applicable", cmd));
      return;
    }

    if (!args.empty && !record.mArgsAction) {
      log(format("command %s expected to have no arguments", cmd));
      return;
    }

    if (args.empty && !record.mNoArgsAction) {
      log(format("command %s expected to have arguments", cmd));
      return;
    }

    // perform action
    if (args.empty) 
      record.mNoArgsAction();
    else
      record.mArgsAction(args);
    
    // update state 
    if (record.mNewState != State.same) 
      mState = record.mNewState; 
  }

  void send(string msg) {
    writeln(msg);
  }

  void log(string s) {
    writeln("log " ~ s);
  }

  // handlers
  
  void newGame(const char[] sizeStr = "24") {
    // TODO return false when can't convert
    int size = to!int(sizeStr);
    mBoard = new Board(size);
  }

  void play(const char[] moves) {
    try {
      foreach (pegStr; split(moves)) {
        Peg* peg = new Peg(pegStr); 
        mBoard.placePeg(*peg);
      }
    } catch (BoardException e) {
      log(e.msg);
    }
  }
  
  void startSearch() {
  }

  void stopSearch() {
  }

  private:
    State mState;
    Record mRecords[];

    Board mBoard;
}
