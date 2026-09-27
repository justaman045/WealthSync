// Stub for open_filex on web.
//
// NOTE: the return type deliberately stays `bool?` and is *not* the native
// plugin's `Result`. The two signatures cannot be unified without importing
// open_filex on web (the reason this stub exists), so every call site must keep
// discarding the result — the native `Result` would not resolve on this
// platform. Callers therefore cannot report an "could not open file" failure
// portably; that is a known limitation, not an oversight. Do not "fix" it by
// consuming the result without changing this file.
class OpenFilex {
  static Future<bool?> open(String filePath) async => false;
}
