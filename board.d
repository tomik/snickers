
/** 
 * Twixt board representation.
 */

import std.algorithm;
import std.array;
import std.bitmanip;
import std.conv;
import std.ctype;
import std.stdio;
import std.string;
import std.range;

debug {
  import std.regex;
}

import logger;

private {
  Logger lgr;
}

static this() {
  lgr = new Logger(__FILE__, LogLevel.LL_DEBUG);
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

enum Field {
  white,
  black,
  empty,
  none
}


/** Helper function to create a "set" from an array.*/
bool[T] toAssoc(T)(T[] elems) {
  bool[T] res;
  for (int i = 0; i < elems.length; i++)
    res[elems[i]] = 1;
  return res;
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
                    -2 + mSize, -1 + 2 * mSize, 1 + 2 * mSize, 2 + mSize];

    // only 4 orientations (denoted by clock times) taken into account
    // there are obvious symmetries between 7, 5 oclock and 8, 4 oclock
    alias size s;
    // 8 oclock
    mSpoilOffsets[0] = [ 2 - 4 * (s + 2), 2 - 4 * (s + 1), 1 - 4 * s, 3 - 4 * 3, 
                         3 - 4 * 2, 2 - 4 * 2, 1 - 4, 2 - 4, 3 - 4];
    // 7 oclock
    mSpoilOffsets[1] = [ 1 - 4 * (s + 1), 2 - 4 * 2, 2 - 4, 1 - 4, -1 + 4,
                         2 + 4 * (s - 2), 2 + 4 * (s - 1), 1 + 4 * (size - 1), -1 + 4 * size];
    // 5 oclock
    mSpoilOffsets[2] = [ -1 - 4 * (s - 1), -2 + 4 * 2, -2 + 4, -1 + 4, 1 - 4,
                         -2 + 4 * (s + 2), -2 + 4 * (s + 1), -1 + 4 * (size + 1), 1 + 4 * size];
    // 4 oclock
    mSpoilOffsets[3] = [ -2 - 4 * (s - 2), -2 - 4 * (s - 1), -1 - 4 * s, -3 + 4 * 3, 
                         -3 + 4 * 2, -2 + 4 * 2, -1 + 4, -2 + 4, -3 + 4];
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
        if (s == ".")
          continue;
        assert(!match(s, "^[a-zA-Z0-9]*$").empty);
        assert(tolower(s[0]) == 'b' || tolower(s[0]) == 'w');
        Color color = tolower(s[0]) == 'b' ? Color.black : Color.white;

        // match groupId - for white numbers for black alphas
        int groupId;
        if (color == Color.white) 
          groupId = to!int(s[1 .. $]);
        else
          groupId = reduce!("a + to!int(b)")(0, s[1 .. $]);

        // place peg
        mPegs[color][pos] = 1;

        auto group = groupId in groups; 
        if(!group)
        {
          groups[groupId] = [pos]; 
          continue;
        }

        // place bridges
        foreach (friendPos; *group)
          tryPlaceBridge(pos, friendPos, color);
        *group ~= pos;
      }
    }
  }

  unittest {

   // Example board(7x7) in snickers string format
   
   string strBoardRaw =
    ".__|.___W1__.___.___.__|.__
     Ba |.   .   .   b   W1 |.
     .  |.   Ba  W1  .   .  |.
     .  |W1  .   .   .   .  |.
     .  |.   .   .   .   .  |.
     .__|.___W1__.___.___.__|.__
     .  |.   .   .   W1  .  |.";
    
   // TODO this obvious one liner doesn't work
   // auto strBoard = joiner(map!(strip)(splitlines(strBoardRaw)), "xyz");
   
   char[] cBoard;
   foreach (line; splitlines(strBoardRaw))
       cBoard ~= "\n" ~ strip(line);
   auto strBoard = to!string(strip(cBoard));


   Board board = new Board(strBoard);
   assert(board.toString() == strBoard);
  }

  /** Dumps the board to snickers string format. */
  string toString() const {
    // result
    char[] strBoard;
    // peg -> groupId mapping if peg has > 1 bridge
    auto groups = [buildPegGroups(Color.white),
                   buildPegGroups(Color.black)];

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
        // groups start from 0
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

  void placePeg(Coord coord, Color color) {
    int pos1 = coord.getPos(mSize);
    if(!isValidPeg(pos1, color))
      return;

    // place the peg
    assert(pos1 > 0 && pos1 < mPegs[color].length);
    mPegs[color][pos1] = 1;
    
    // build bridges
    foreach (off; mNgbOffsets) {
      int pos2 = pos1 + off;

      if (!isValidPos(pos2, color))
        continue;
      
      BridgeId bid = calcBridgeId(pos1, pos2);
      assert(!hasBridge(bid));

      if (!canPlaceBridge(bid))
        continue;

      // place the bridge
      mBridges[bid] = 1;
    }
  }

  bool hasWinner() const {
    return false;
  }

  /** There must be a winner present for this to have meaning. */
  Color getWinner() const {
    return Color.white;
  }

private:

  int[int] buildPegGroups(Color color) const {
    uint nextGid = 1;
    // pos -> groupId
    int[int] groupIds; 
    // groupId -> [pos]
    int[][int] groups; 

    for (int i = 0; i < mPegs[color].length; i++) {
      if(!mPegs[color][i] || !isValidPos(i, color))
        continue;
      auto ngbs = getConnectedPegs(i, color);
      lgr.trace("color(%s), peg(%s) connected pegs(%s)", color, i, ngbs);
      if(!ngbs.length)
        continue;

      groupIds[i] = nextGid;
      groups[nextGid++] = [i];

      // merge connected groups
      foreach(ngb; ngbs) {
        auto gid1 = groupIds[i];
        if(ngb !in groupIds)
        {
          groupIds[ngb] = gid1;
          groups[gid1] ~= ngb;
          continue;
        }

        auto gid2 = groupIds[ngb];
        auto oldGid = gid1 < gid2 ? gid2 : gid1;
        auto newGid = gid1 < gid2 ? gid1 : gid2;
        auto oldGroup = groups[oldGid];
        auto newGroup = groups[newGid];

        // TODO optimize ?
        foreach (oldMember; oldGroup)
          groupIds[oldMember] = newGid;
        groups[newGid] ~= groups[oldGid];
        groups.remove(oldGid);
      }
    }
    
    lgr.dbug("building peg groups for color(%s) groupIds(%s)", color, groupIds);

    return groupIds;
  }

  bool tryPlaceBridge(int pos1, int pos2, Color color) {
      if (pos1 - pos2 !in toAssoc(mNgbOffsets))
        return false;
      BridgeId bid = calcBridgeId(pos1, pos2);
      if (canPlaceBridge(bid)) {
        mBridges[bid] = 1;
        return true;
      }
     return false;
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

  bool canPlaceBridge(BridgeId bridge) const
  in {
    assert(!hasBridge(bridge));
  }
  body {
    foreach (spoilOffset; mSpoilOffsets[getBridgeType(bridge)])
      if (hasBridge(bridge + spoilOffset))
        return false;
      
    return true;
  }

  int[] getConnectedPegs(int pos, Color color) const
  in {
    assert(isValidPos(pos, color));
  }
  out(result) {
    foreach (connectedPos; result)
      assert(isValidPos(connectedPos, color));
  }
  body {
    int[] result;

    foreach (off; mNgbOffsets) {
      if (isValidPos(pos + off, color) &&
          hasBridge(calcBridgeId(pos, pos + off)))
        result ~= pos + off;
    }

    return result;
  }

  bool isValidPeg(int pos, Color color) const {
    return isValidPos(pos, color) && !mPegs[color][pos] && color != Color.empty;
  }

  bool isValidPos(int pos, Color color) const {
    if(pos < 0)
      return false;

    int x = pos % mSize; 
    int y = pos / mSize;

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



