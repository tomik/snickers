
import std.stdio;
import std.exception : Exception;
import std.typecons : Tuple, tuple;
import std.conv : to;
import std.string : format, strip, startsWith, indexOf;

import board : Board, Peg, Color;
// this will soon become part of phobos
import std.process : spawnProcess, Pid, Pipe, wait;

Tuple!(string, string) split2(string s) {
  int index = indexOf(s, ' ');
  string s1 = strip(index == -1 ? s : s[0 .. index]).idup;
  string s2 = strip(index == -1 ? "" : s[index + 1 .. $]).idup;
  return tuple(s1, s2); 
}

class MatchException : Exception {
  this(string s) { super(s); }
}

struct Reply {
  bool mOk; 
  string mArgs;

  this(string s) {
    auto splitted = split2(s.strip());
    string cmd = splitted[0];
    mArgs = splitted[1];

    if (cmd !in ["ok":1, "nok":1])
      throw new MatchException("invalid engine response");
    mOk = cmd == "ok";
  }
}

struct Bot {

  public:

  this(string id, string binPath) {
    mId = id;
    mWriter = Pipe.create();
    mReader = Pipe.create();
    mChildPid = spawnProcess(binPath, mWriter.readEnd, mReader.writeEnd);
  }

  ~this()
  {
    // send("quit");
    // wait(mChildPid);
  }

  string toString() { 
    return mId;
  }

  /// Waits for asynchronous message.
  /// and returns its arguments
  string waitForMsg(string msg) {
    string buf = readBuf().idup;

    if (msg != buf)
      throw new MatchException(format("unexpected msg received %s", buf));

    return split2(buf)[1];
  }

  /// Sends cmd to bot and waits for reply
  Reply send(string cmd) {
    writefln("sent %s command to %s", cmd, this.toString());
    mWriter.writeEnd.writeln(cmd);

    return Reply(readBuf().idup);
  }

  private:

  char[] readBuf() {
    char[] buf;

    while (true) {
      buf = to!(char[])(mReader.readEnd.readln()).strip();
      writefln("received %s from %s", buf, this.toString());
      if (!buf.startsWith("log"))
        break;
    }

    return buf;  
  }

  private:
    string mId;
    Pipe mReader;
    Pipe mWriter;
    Pid mChildPid;
}

void main() {

  string botPath[2] = ["./bin/snickers", "./bin/snickers"];
  Reply[2] reply;
  Bot bot[2];
  bot[0] = Bot("white", botPath[0]);
  bot[1] = Bot("black", botPath[1]);
  
  // load board
  Board board = new Board(12); 
   
  // setup game in bots
  
  bot[0].send("newgame 12");
  bot[1].send("newgame 12");
  
  // setup settings
  
  // search
  
  while (1) {
  }

}
