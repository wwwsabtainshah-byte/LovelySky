from pathlib import Path

p = Path("lib/main.dart")
s = p.read_text()

# Backup
Path("lib/main.dart.seat_backup").write_text(s)

# Fix API request
old = """  final ok = await _roomPost(
      '/voice/rooms/${widget.room['id']}/seats/upgrade',
    );"""

new = """  final nextCapacity = seatCapacity == 30 ? 36 : seatCapacity + 5;
  final ok = await _roomPost(
      '/voice/rooms/${widget.room['id']}/seats/upgrade',
      body: {'seat_capacity': nextCapacity},
    );"""

if old not in s:
    start = s.find("Future<void> _upgradeRoomSeats()")
    end = s.find("Future<void> _loadSeats()", start)
    section = s[start:end]
    old = """final ok = await _roomPost(
                               '/voice/rooms/${widget.room['id']}/seats/upgrade',
    );"""
    if old not in section:
        raise SystemExit("Upgrade API exact location not found")
    section = section.replace(old, new, 1)
    s = s[:start] + section + s[end:]
else:
    s = s.replace(old, new, 1)

# Insert More menu option using actual indentation
marker = """              ListTile(
                                                 leading: const Icon(Icons.info_outline),"""

if marker not in s:
    import re
    pattern = r"(?m)^(\s*)ListTile\(\s*\n\s*leading: const Icon\(Icons\.info_outline\),"
    match = re.search(pattern, s)
    if not match:
        raise SystemExit("More menu exact location not found")
    indent = match.group(1)
    pos = match.start()
else:
    indent = "              "
    pos = s.index(marker)

item = """              if (roomRole == 'owner' && seatCapacity < 36)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Upgrade Room Seats'),
                  subtitle: Text(
                    'Next: ${seatCapacity == 30 ? 36 : seatCapacity + 5} seats',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _upgradeRoomSeats();
                  },
                ),
"""

s = s[:pos] + item + s[pos:]
p.write_text(s)

print("SUCCESS: Seat upgrade API and More menu patched.")
