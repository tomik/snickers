
import std.string : format;

import board : Color;

string pegToJsonStr(int x, int y, Color color) 
in { 
  assert(color == Color.white || color == Color.black);
}
body {
  return format("{\"player\": %s, \"x\": %d, \"y\": %d, \"type\": 1}", 
            color == Color.white ? "1" : "2", x + 1, y + 1);      
}

