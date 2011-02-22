
/** 
 * Twixt board representation.
 */

import std.algorithm;
import std.conv;
import std.ctype;
import std.exception;
import std.range;
import std.stdio;
import std.string;

import std.bitmanip : BitArray;
import std.math : abs;
import std.random : Random;
import std.regex : match;
import std.typecons : Tuple, tuple;

import core.runtime;

import logger;

private {
  Logger lgr;
}

static this() {
  lgr = new Logger(__FILE__, LogLevel.LL_INFO);
}

alias uint BridgeId;

/// Coordinates starting in bottom left corner
struct Coord {
  int x;
  int y;

  this(int x, int y) {
    this.x = x;
    this.y = y;
  }

  // not optimized - mostly for testing
  static Coord fromPos(int pos, int boardSize) { 
    return Coord(pos % boardSize, pos/boardSize);
  }

  int getPos(int size)
  { return x + y * size;} 
}

enum Color {
  white,
  black,
  empty
}

Color flipColor(Color color) 
in {
  assert(color != Color.empty);
}
body {
  return color == Color.white ? Color.black : Color.white;
}

/** Helper function to create a "set" from an array.*/
bool[T] toAssoc(T)(T[] elems) {
  bool[T] res;
  for (int i = 0; i < elems.length; i++)
    res[elems[i]] = 1;
  return res;
}

/** Helper function for normalizing input board representations. */
string stripLines(string s) {
  // TODO this obvious one liner doesn't work
  // auto strBoard = joiner(map!(strip)(splitlines(strBoardRaw)), "xyz");
  
  char[] cBoard;
  foreach (line; splitlines(s))
      cBoard ~= "\n" ~ strip(line);
  return to!string(strip(cBoard));
}

class BoardException : Exception {
  public this(string s) {
    super(s);
  }
};

class Board {

public:

  this(int size) {
    mSize = size;
    mPegs[0].length = mSize * mSize;
    mPegs[1].length = mSize * mSize;
    mBridges.length = mSize * mSize * 4;
    mNgbOffsets = [ -2 - mSize, -1 - 2 * mSize, 1 - 2 * mSize, 2 - mSize, 
                     2 + mSize, 1 + 2 * mSize, -1 + 2 * mSize, -2 + mSize];

    // only 4 orientations (denoted by clock times) taken into account
    // there are obvious symmetries between 7, 5 oclock and 8, 4 oclock
    alias size s;
    // 8 oclock
    mSpoilOffsets[0] = [ 2 - 4 * (s + 2), 2 - 4 * (s + 1), 1 - 4 * s, 3 - 4 * 3, 
                         3 - 4 * 2, 2 - 4 * 2, 1 - 4, 2 - 4, 3 - 4];
    // 7 oclock
    mSpoilOffsets[1] = [ 1 - 4 * (s + 1), 2 - 4 * 2, 2 - 4, 1 - 4, -1 + 4,
                         2 + 4 * (s - 2), 2 + 4 * (s - 1), 1 + 4 * (s - 1), -1 + 4 * s];
    // 5 oclock
    mSpoilOffsets[2] = [ -1 - 4 * (s - 1), -2 + 4 * 2, -2 + 4, -1 + 4, 1 - 4,
                         -2 + 4 * (s + 2), -2 + 4 * (s + 1), -1 + 4 * (s + 1), 1 + 4 * s];
    // 4 oclock
    mSpoilOffsets[3] = [ -2 - 4 * (s - 2), -2 - 4 * (s - 1), -1 - 4 * s, -3 + 4 * 3, 
                         -3 + 4 * 2, -2 + 4 * 2, -1 + 4, -2 + 4, -3 + 4];
  }

  // copy constructor
  this(Board board) {
    this.mSize = board.mSize;
    this.mPegs[0] = board.mPegs[0].dup;
    this.mPegs[1] = board.mPegs[1].dup;
    this.mBridges = board.mBridges.dup;

    // TODO static ?
    this.mNgbOffsets = board.mNgbOffsets.dup;
    this.mSpoilOffsets = board.mSpoilOffsets.dup;
  }

  /** Loads the board from snickers string format. */
  this(string strBoard) {
    string[] lines = splitlines(strBoard);
    if(!lines.length)
      throw new BoardException("empty input"); 

    // top edge is white's edge - no black pegs can be there
    this(count!("a == '.' || a == 'W' || a == 'w'")(lines[0]));

    // current peg position 
    int pos = 0;
    // groupId -> list of pegs mapping
    int[][int] groups;

    // load all the pegs/empty fields
    foreach (line; lines) {
      line = strip(line);

      if((line.length + 3) * 4 < 16)
        throw new BoardException("too short line"); 

      while (!line.empty) {
        if (pos >= mSize * mSize)
          throw new BoardException("invalid input"); 

        auto toTake = min(4, line.length);
        scope (exit) {pos++, line = line[toTake .. $];};

        auto s = removechars(to!string(take(line, toTake)), " _|");
        // empty field
        if (s == ".")
          continue;

        if(match(s, "^[bwBW][a-z0-9]*$").empty)
          throw new BoardException(format("invalid peg(%s) format", pos));

        Color color = tolower(s[0]) == 'b' ? Color.black : Color.white;

        // place peg
        mPegs[color][pos] = 1;

        // resolve group belongance

        int groupId = 0;
        // peg isn't in any group
        // it has and will have no bridges
        if (s.length == 1)
          continue;

        // match groupId - for white numbers for black alphas
        try { 
          if (color == Color.white) 
            groupId = to!int(s[1 .. $]);
          else
            // -1 to differentiate from white
            groupId = -1 * reduce!("a + to!int(b)")(0, s[1 .. $]);
        } catch (ConvException) {
          throw new BoardException(format("invalid peg(%s) format - can't deduce group", pos));
        }

        // update groups
        auto group = groupId in groups; 
        if(!group) {
          groups[groupId] = [pos]; 
          continue;
        }

        *group ~= pos;
      }
    }

    // now information on all groups is present - place bridges
    
    BridgeId[] allBridges;
    bool[BridgeId] inCross;

    // find all potential bridges to be built
    foreach (group; groups)
      for (int i = 0; i < group.length; i++) 
        for (int j = i + 1; j < group.length; j++)
          // all pegs withing a group are of same color
          if (isBridgeShape(group[i], group[j]))
            allBridges ~= calcBridgeId(group[i], group[j]);

    // find those in cross
    for (int i = 0; i < allBridges.length; i++) 
      for (int j = i; j < allBridges.length; j++)
        if (bridgesInCross(allBridges[i], allBridges[j])) {
          inCross[allBridges[i]] = 1;
          inCross[allBridges[j]] = 1;
        }

    // place what can be placed
    foreach (bridge; allBridges) 
      if (bridge !in inCross) {
        enforce(tryPlaceBridge(bridge),
          format("can't place bridge(%s) considered placeable", bridge));
      }

    lgr.trace("loading board: bridges all(%s) bridges in cross(%s)",
      allBridges, inCross);

    // indicator of change
    int lastLen = 0;
    // iteratively go through remaining bridges in cross
    // remove from the list those which connect pegs in one group
    while (inCross.length && lastLen != inCross.length)
    {
      lastLen = inCross.length;

      // check what is already connected
      auto currentGroups = buildPegGroups();

      // drop those in cross which connect connected groups
      BridgeId[] toRemove;
      foreach (bridge, ref isPresent; inCross) {
        assert(isPresent);
        // get pos1, pos2 from bridge id as a tuple
        auto ends = calcBridgeEnds(bridge);
        auto gid1 = ends[0] in currentGroups;
        auto gid2 = ends[1] in currentGroups;

        // these pegs are connected via different route already 
        if(gid1 !is null && *gid1 == *gid2)
          toRemove ~= bridge;
      }

      foreach (bridge; toRemove) 
        inCross.remove(bridge);
    }
    
    // place the rest
    foreach (bridge, _; inCross)
      enforce(tryPlaceBridge(bridge),
        format("can't place bridge(%s) after in cross filter", bridge));
  }

  static string normStrBoard(string s) {
    return stripLines(s);
  }

  /** Dumps the board to snickers string format. */
  string toString() const {
    // result
    char[] strBoard;
    // peg -> groupId mapping if peg has > 1 bridge
    auto groups = [buildPegGroupsByColor(Color.white),
                   buildPegGroupsByColor(Color.black)];

    for (auto i = 0; i < mSize * mSize; i++) {
      if (i % mSize == 0 && i != 0) {
        strBoard ~= '\n';
      }

      // padding in the beginning for better look
      // if (i % mSize == 0)
         // strBoard ~= " ";

      // post formatter handles different paddings
      // distance between columns is 3
      int padding = 3;
      scope(exit) { 
        assert(padding <= 3);
        char[3] s = "   ";

        // top and bottom edge
        if(i / mSize == 0 || i / mSize == mSize - 2)
          s = "___";
        if(i % mSize == mSize - 1)
          s[$ - 1] = ' ';
        // left and right edge
        if(i % mSize == 0)
          s[$ - 1] = '|';
        if(i % mSize == mSize - 2)
          s[$ - 1] = '|';
        // TODO ugly
        // strip the whitespace in the end
        if(i % mSize == mSize - 1) 
          strBoard ~= strip(s[ 3 - padding .. 3]);
        else
          strBoard ~= s[ 3 - padding .. 3];
      };

      if (!mPegs[Color.white][i] && !mPegs[Color.black][i]) {
        strBoard ~= ".";
        continue;
      }

      // there is a peg to be printed

      // str repr for color and group
      static auto chrPeg = ['w', 'b'];
      auto numsGen = (int i) { return to!string(i); }; 
      auto charsGen = (int i) {
        // groups start from 1
        assert(i > 0);
        char[] s;
        while (i > 0) {
          s ~= 'a' + (i - 1) % 26;
          i /= 26;
        }
        return to!string(s);
      }; 
      auto strGroupGen = [numsGen, charsGen];

      foreach (color; [Color.white, Color.black]) {
        if (!mPegs[color][i])
          continue;

        // peg has bridges
        if(i in groups[color]){
          auto strGroup = strGroupGen[color](groups[color][i]); 
          strBoard ~= toupper(chrPeg[color]);
          strBoard ~= strGroup;
          padding -= strGroup.length;
        }
        // standalone peg
        else {
          strBoard ~= chrPeg[color];
        }
      }
    }
    return to!string(strBoard);
  }

  bool isValidPeg(int pos, Color color) const {
    return isValidPos(pos, color) && !mPegs[Color.white][pos] &&
           !mPegs[Color.black][pos] && color != Color.empty;
  }

  bool placePeg(Coord coord, Color color) {
    return placePeg(coord.getPos(mSize), color);
  }

  bool placePeg(int pos, Color color) {
    if(!isValidPeg(pos, color))
    {
      lgr.dbug("placing peg(%s) color(%s) invalid", pos, color);
      return false;
    }

    lgr.dbug("placing peg(%s) color(%s)", pos, color);

    // place the peg
    assert(pos > 0 && pos < mPegs[color].length);
    mPegs[color][pos] = 1;
    
    // build bridges
    foreach (off; mNgbOffsets) {
      int ngb = pos + off;

      if (!isValidPos(ngb, color) || !mPegs[color][ngb])
        continue;
      
      BridgeId bid = calcBridgeId(pos, ngb);
      assert(!hasBridge(bid));

      if (!canPlaceBridge(bid))
        continue;

      // special case to prevent "cylinder like" connections
      if (abs(pos % mSize - ngb % mSize) > 2)
        continue;

      // place the bridge
      mBridges[bid] = 1;
    }

    return true;
  }

  /** There must be a winner present for this to have meaning. */
  Color getWinner() const {
    if (checkWinner(Color.white))
      return Color.white;

    if (checkWinner(Color.black))
      return Color.black;

    return Color.empty;
  }

  int getSize() const {
    return mSize;
  }

  int getFieldsNum() const {
    return mSize * mSize;
  }

  // analyzer part - TODO put this aside to another object

  Color getPosColor(int pos) const {
    if (mPegs[Color.white][pos])
      return Color.white;

    if (mPegs[Color.black][pos])
      return Color.black;

    return Color.empty;
  }

  int getPeerByRandom(int pos, Color color, ref Random gen) const {
    int peer = gen.front() % 8;
    gen.popFront();
    return mNgbOffsets[peer] + pos;
  }

  int getPeerByDirection(int pos, Color color, ref Random gen) const {
    int peer = gen.front() % 8;
    gen.popFront();
    if (color == Color.white) {
      peer = pos / mSize < mSize / 2 ? 4 + peer % 4 : peer % 4;
    }
    else {
      assert(color == Color.black);
      uint off = pos % mSize < mSize / 2 ? 4 : 0; 
      peer = peer < 2 || peer > 5 ? (peer + off) % 8: (peer + 4 - off) % 8;
    }
    return mNgbOffsets[peer] + pos;
  }
  
  int getPeerByStupidPath(int pos, Color color, bool rightOrDown, ref Random gen) const {

    if (getPosColor(pos) == color.empty)
      return pos; 

    static int[4] where[4] = 
      [ 
        [0, 1, 2, 3], // white up
        [0, 1, 6, 7], // black left 
        [4, 5, 6, 7], // white down
        [2, 3, 4, 5], // black right
      ];

    auto dirs = where[color + 2 * rightOrDown];
    auto index = dirs[gen.front() % 4];
    gen.popFront();
    auto peer = mNgbOffsets[index] + pos;

    return peer;
  }

private:

  bool checkWinner(Color color) const {
    BitArray visited;
    visited.length = mSize * mSize;

    int off = color == Color.white ? 1 : mSize;
    int limit = color == Color.white ? mSize : mSize * mSize;

    for (int i = 0; i < limit; i += off) {
      if(!mPegs[color][i] || visited[i])
        continue;

      assert(isValidPos(i, color));
      
      // faster ?
      int[] group = [i];
      visited[i] = true;

      while (!group.empty) {
        int peg = group.front();

        foreach(ngb; getConnectedPegs(peg, color))
          if (!visited[ngb]) {
            visited[ngb] = true;
            group ~= ngb;
          }
        group.popFront();

        // win check
        // since white/black cannot generate move in blacks/white winning line
        // we can leave out the color check
        if (peg % mSize == mSize - 1 || peg / mSize == mSize - 1) 
          return true;
      }
    }
    return false;
  }

  int[int] buildPegGroups() const {
    auto groups = buildPegGroupsByColor(Color.white);
    foreach(key, group; buildPegGroupsByColor(Color.black, groups.length)) {
      assert(key !in groups);
      groups[key] = group;
    }
    return groups;
  }

  // at the moment this function doesn't need to be fast
  int[int] buildPegGroupsByColor(Color color, uint nextGid = 1) const {
    // peg -> groupId
    int[int] groupIds; 
    BitArray visited;
    visited.length = mSize * mSize;

    BoardIter: 
    for (int i = 0; i < mPegs[color].length; i++) {
      if(!mPegs[color][i] || !isValidPos(i, color) || visited[i])
        continue;
      
      int[] group = [i];
      visited[i] = true;

      while (!group.empty) {
        int peg = group.front();

        lgr.trace("adding peg(%d) to group(%d) color(%s)", peg, nextGid, color);

        foreach(ngb; getConnectedPegs(peg, color))
          if (!visited[ngb]) {
            visited[ngb] = true;
            group ~= ngb;
          }
        group.popFront();

        // don't store single pegs
        if(peg == i && group.empty)
          continue BoardIter;
        groupIds[peg] = nextGid;
      }
      nextGid++;
    }
    
    lgr.trace("building peg groups for color(%s) groupIds(%s)", color, groupIds);
    return groupIds;
  }

  bool tryPlaceBridge(int pos1, int pos2, Color color) {
    if (!isBridgeShape(pos1, pos2))
      return false;
    BridgeId bid = calcBridgeId(pos1, pos2);
    if (canPlaceBridge(bid)) {
      mBridges[bid] = 1;
      return true;
    }
    return false;
  }

  bool tryPlaceBridge(BridgeId bid) {
    if (canPlaceBridge(bid)) {
      mBridges[bid] = 1;
      return true;
    }
    return false;
  }

  bool removeBridge(BridgeId bridge) {
    if (!hasBridge(bridge))
      return false;
    mBridges[bridge] = 1;
    return true;
  }

  // bridge doesn't have to be constructable
  bool isBridgeShape(int pos1, int pos2) {
    return (pos1 - pos2 in toAssoc(mNgbOffsets)) !is null;
  }

  bool hasBridge(BridgeId bridge) const {
    return mBridges[bridge];
  }

  uint getBridgeType(BridgeId bridge) const {
    return bridge % 4;
  }

  BridgeId calcBridgeId(int pos1, int pos2) const
  in {
    bool found = false;
    foreach(ngb; mNgbOffsets)
      if (ngb == (pos1 - pos2))
        found = true;
    assert(found);
    assert((isValidPos(pos1, Color.white) && isValidPos(pos2, Color.white)) ||
           (isValidPos(pos1, Color.black) && isValidPos(pos2, Color.black)));
    assert(areSameColor(pos1, pos2));
  }
  body {
    // TODO more elegant ?
    int minPos = pos1 < pos2 ? pos1 : pos2;
    int maxPos = pos1 < pos2 ? pos2 : pos1;
    // map 4 possible cases of bridge orientation to [0, 1, 2, 3]
    // .  .  *  .  .
    // 0  .  .  .  3
    // .  1  .  2  . 
    int off = (maxPos - minPos) % mSize > 2 ? 2 : 1;
    return minPos * 4 + ((maxPos - minPos) + off) % mSize;
  }

  Tuple!(int, int) calcBridgeEnds(BridgeId bid) const
  body {
    int pos1 = bid / 4;
    int off = 0;
    switch (bid % 4) {
      case 0 : off = mSize - 2; break;
      case 1 : off = 2 * mSize - 1; break;
      case 2 : off = 2 * mSize + 1; break;
      case 3 : off = 1 * mSize + 2; break;
    }
    return tuple(pos1, pos1 + off); 
  }

  bool canPlaceBridge(BridgeId bridge) const
  in {
    assert(!hasBridge(bridge));
  }
  body {
    foreach (spoilOffset; mSpoilOffsets[getBridgeType(bridge)]) {
      BridgeId spoiler = bridge + spoilOffset;
      if (hasBridge(spoiler) && spoiler >= 0 && spoiler < mBridges.length)
        return false;
    }
      
    return true;
  }

  bool bridgesInCross(BridgeId bridge1, BridgeId bridge2) const {
    foreach (spoilOffset; mSpoilOffsets[getBridgeType(bridge1)])
      if (bridge1 + spoilOffset == bridge2)
        return true;
    return false;
  }

  int[] getConnectedPegs(int pos, Color color) const
  in {
    assert(isValidPos(pos, color));
    assert(mPegs[color][pos]);
  }
  out(result) {
    foreach (connectedPos; result)
      assert(isValidPos(connectedPos, color));
  }
  body {
    int[] result;

    // TODO check that 
    foreach (off; mNgbOffsets) {
      if (isValidPos(pos + off, color) &&
          mPegs[color][pos + off] &&
          hasBridge(calcBridgeId(pos, pos + off)))
        result ~= pos + off;
    }

    return result;
  }

  bool areSameColor(int pos1, int pos2) const 
  out (result) {
    if (result && mPegs[Color.white][pos1] == true) 
      assert(mPegs[Color.black][pos1] == mPegs[Color.black][pos2]);
  }
  body
  {
    return mPegs[Color.white][pos1] == mPegs[Color.white][pos2];
  }

  // doesn't cover special cases of top left and bottom right corner
  // that is ok since these happen little and are eliminated in isValidPos
  bool isOnBoard(int pos) const {
    return pos >= 1 && pos < mSize * mSize;
  }

  bool isValidPos(int pos, Color color) const {
    if (pos <= 0 || pos >= mSize * mSize)
      return false;

    int x = pos % mSize; 
    int y = pos / mSize;

    // watchout: if pos == mSize then  x == 0 !
    // trivial (no edges) + within ranges
    if (x > 0 && x < mSize - 1 && y > 0 && y < mSize - 1)
      return true;

    bool yedge = x == 0 || x == mSize - 1;
    bool xedge = y == 0 || y == mSize - 1;
    
    // edges
    if (color == Color.white && xedge && !yedge)
      return true;
    if (color == Color.black && yedge && !xedge)
      return true;

    return false;
  }

  unittest {
    Board b = new Board(4);
    // outside board
    assert(b.isValidPos(-1, Color.white) == false);
    assert(b.isValidPos(18, Color.white) == false);
    assert(b.isValidPos(-1, Color.black) == false);
    assert(b.isValidPos(18, Color.black) == false);
    assert(b.isValidPos(16, Color.white) == false);
    assert(b.isValidPos(16, Color.black) == false);
    // corners
    assert(b.isValidPos(0, Color.white) == false);
    assert(b.isValidPos(0, Color.black) == false);
    assert(b.isValidPos(3, Color.white) == false);
    assert(b.isValidPos(3, Color.black) == false);
    assert(b.isValidPos(12, Color.white) == false);
    assert(b.isValidPos(12, Color.black) == false);
    assert(b.isValidPos(15, Color.white) == false);
    assert(b.isValidPos(15, Color.black) == false);
    // white edge
    assert(b.isValidPos(1, Color.white) == true);
    assert(b.isValidPos(1, Color.black) == false);
    assert(b.isValidPos(13, Color.white) == true);
    assert(b.isValidPos(13, Color.black) == false);
    // black edge
    assert(b.isValidPos(4, Color.white) == false);
    assert(b.isValidPos(4, Color.black) == true);
    assert(b.isValidPos(11, Color.white) == false);
    assert(b.isValidPos(11, Color.black) == true);
  }

private:

  int mSize;

  // presence map for white/blag pegs
  BitArray mPegs[2];
  // presence map for bridgeIds 
  BitArray mBridges;

  // offsets for positions of neigbors (bridgeable pegs)
  // this will be filled on creation and then never changed again
  // TODO static ?
  int[8] mNgbOffsets;
  // hand prepared spoil offsets for bridges
  // bridge id + elements of mSpoilOffsets[bridge type] == possible spoils
  int[9] mSpoilOffsets[4];
}

