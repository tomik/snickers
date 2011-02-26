
import std.getopt;

// import logger;
import benchmarks : runBenchmarks;
import control : Control;
import playout : runExamplePlayout;
import types : SystemExit, config;

import std.stdio;

// TODO logger doesn't work with threads !!!
//private { 
  //Logger lgr; 
  //static this() { 
    //lgr = new Logger(__FILE__, LogLevel.LL_DEBUG);
    //setupLogging("snickers.log");
  //}
//}

int main(string[] args) {
  //lgr.info("snickers started");

  getopt(args,
      "benchmark|b", &config.mBenchmark,
      "playout|p", &config.mPlayout);

  if (config.mBenchmark) {
    runBenchmarks();
    return 0;  
  }

  // runs example playout and stores it
  // in view_game.html file ready to be viewed in js viewer
  if (config.mPlayout) {
    runExamplePlayout();
    return 0;  
  }

  // TODO validate the rest of the command line

  // starts snickers interactive command line
  try {
    Control control = new Control(); 
    control.runInputLoop();
  } catch (SystemExit) {
    return 0;
  }
  return 0;
}

