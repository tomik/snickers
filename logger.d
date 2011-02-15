
import std.stdio;
import std.conv;
import std.file;
import std.string;
import std.stream;
import core.thread;
import std.date;

enum LogLevel {LL_TRACE = 0, LL_DEBUG = 1, LL_INFO = 2, LL_ERROR = 3};

static LogWriter logWriter;

void setupLogging(string output, bool autoFlush = false)
{
  if(!logWriter)
    logWriter = new LogWriter;

  logWriter.init(output, autoFlush);
}

class Logger
{
  public:

  this(string logModule, LogLevel logLevel)
  {
    this.mLogModule = logModule;
    this.mLogLevel = logLevel;

    if(!logWriter)
      logWriter = new LogWriter;
  }

  void trace(T...)(lazy string logString, T args)
  {
    if (mLogLevel <= LogLevel.LL_TRACE)
      logWriter.writeToLog("TRACE", mLogModule, format(logString(), args));
  }

  void dbug(T...)(lazy string logString, T args)
  {
    if (mLogLevel <= LogLevel.LL_DEBUG)
      logWriter.writeToLog("DEBUG", mLogModule, format(logString(), args));
  }

  void info(T...)(lazy string logString, T args)
  {
    if (mLogLevel <= LogLevel.LL_INFO)
      logWriter.writeToLog("INFO", mLogModule, format(logString(), args));
  }

  void error(T...)(lazy string logString, T args)
  {
    if (mLogLevel <= LogLevel.LL_ERROR)
      logWriter.writeToLog("ERROR", mLogModule, format(logString(), args), true);
  }

  private:

  LogLevel mLogLevel;
  string mLogModule;
}

class LogWriter
{
  private this()
  {}

  private void init(string output, bool autoFlush = false)
  {
    // TODO better ?
    if (!(mOutStream is null))
      throw new Exception("log stream already initialized");

      this.mAutoFlush = autoFlush;
      this.mTzOffset = 0; //tzoffset * ticksPerHour;
      this.mOutStream = new BufferedFile(output, FileMode.OutNew);
  }

  ~this()
  {
    if(mOutStream)
    {
      mOutStream.flush();
      mOutStream.close();
    }
  }

  private void writeToLog(string levelName, string logModule, string msg, bool doFlush = false)
  {
    if(!mOutStream)
      return;

    Date currTime;
    scope(failure) mOutStream.flush();

    currTime.parse(toUTCString(getUTCtime() + mTzOffset));
    string locMsg = format("%4d:%02d:%02d %02d:%02d:%02d= %s: %s - %s", currTime.year,
          currTime.month, currTime.day, currTime.hour, currTime.minute,
          currTime.second, levelName, logModule, msg.dup);
    synchronized
    {
      mOutStream.writeLine(locMsg);
      if (mAutoFlush || doFlush)
      {
        mOutStream.flush();
      }
    }
  }

  private:

  bool mAutoFlush;
  int mTzOffset;
  // why is __gshared needed here (if not present destructor crashes) 
  __gshared Stream mOutStream;
}
