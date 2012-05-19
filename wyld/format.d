module wyld.format;

import std.array: appender;
import std.format: formattedWrite;

string format(Char, Args...)(in Char[] fmt, Args args) {
  auto w = appender!(string)();
  formattedWrite(w, fmt, args);
  return w.data;
}