
import logger;
import board;
import std.stdio;

private { 
  Logger lgr; 
  static this() { 
    lgr = new Logger(__FILE__, LogLevel.LL_DEBUG);
    setupLogging("snickers.log");
  }
}

void main() {
  lgr.info("snickers started");
}
