
import std.datetime : systime, benchmark, StopWatch; 
import std.random : Random, unpredictableSeed;
import std.conv;
import std.stdio;

import board;
import playout : SimplePlayout, BBPlayout;

void runBenchmarks() {
  int seed = unpredictableSeed();
  Random gen = Random(seed);
  playoutBenchmark!(BBPlayout)(gen, 10000, 24, 90, "large board");
  playoutBenchmark!(BBPlayout)(gen, 10000, 7, 45, "small board");
  playoutBenchmark!(SimplePlayout)(gen, 10000, 24, 200, "large board");
  playoutBenchmark!(SimplePlayout)(gen, 10000, 7, 100, "small board");
}

void playoutBenchmark(Playout)(Random gen, uint playoutsNum, uint boardSize, uint playoutLen, string comment) {
  StopWatch sw;

  int[3] results = [0, 0, 0];
  
  Board board = new Board(boardSize);
  // board.placePeg(250, Color.white);
  // board.placePeg(299, Color.white);

  sw.start();

  for(int i = 0; i < playoutsNum; i++)
  {
    Playout playout = new Playout(board, playoutLen, gen); 
    auto res = playout.evaluate();
    results[to!int(res) + 1]++;
  }

  sw.stop();
  // in seconds
  double elapsed = sw.peek().msec / 1000.0;

  writefln("====================\n"
           "%s (%s) \n"
           "====================\n"
           "board size(%d)\n"
           "playout length(%d)\n"
           "playouts num(%s)\n"
           "results(WdB)(%s)\n"
           "time total(%s) pps(%s) mps(%s)",
      Playout.getName(), comment, boardSize, playoutLen, playoutsNum, results,
      elapsed, playoutsNum / elapsed, playoutsNum * playoutLen / elapsed);
}

