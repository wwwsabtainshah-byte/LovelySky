from pathlib import Path
import sys

p = Path("lib/main.dart")
s = p.read_text()

old = """  void initState() {
    super.initState();
    _loadSeats();
    seatRefreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadSeats(),
    );
  }"""

new = """  void initState() {
    super.initState();
    _loadSeats();
    _loadMessages();
    seatRefreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        _loadSeats();
        _loadMessages();
      },
    );
  }"""

if s.count(old) != 1:
    sys.exit("Timer block exact match nahi hua; main.dart unchanged.")

Path("main.dart.chat-timer-preview").write_text(s.replace(old, new, 1))
print("TIMER PREVIEW READY; main.dart abhi change nahi hui.")
