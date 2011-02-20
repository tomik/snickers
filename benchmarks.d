
import std.datetime : systime, benchmark, StopWatch; 
import std.random : Mt19937;
import std.conv;
import std.stdio;

import board;
import playout : SimplePlayout;

void runBenchmarks() {
  simplePlayoutBenchmark(1000, 15, 150);
}

void simplePlayoutBenchmark(uint playoutsNum, uint boardSize, uint playoutLen) {
  StopWatch sw;
  Mt19937 gen;
  gen.seed(cast(uint)systime().toMilliseconds!long);

  int[3] results = [0, 0, 0];

  sw.start();

  for(int i = 0; i < playoutsNum; i++)
  {
    SimplePlayout playout = new SimplePlayout(new Board(boardSize), playoutLen, gen); 
    auto res = playout.evaluate();
    results[to!int(res) + 1]++;
  }

  sw.stop();
  // in seconds
  double elapsed = sw.peek().msec / 1000.0;

  writefln("====================\n"
           "simplePlayout:\n"
           "====================\n"
           "board size(%d)\n"
           "playout length(%d)\n"
           "playouts num(%s)\n"
           "results(WdB)(%s)\n"
           "time total(%s) pps(%s) mps(%s)",
      boardSize, playoutLen, playoutsNum, results,
      elapsed, playoutsNum / elapsed, playoutsNum * playoutLen / elapsed);
}

