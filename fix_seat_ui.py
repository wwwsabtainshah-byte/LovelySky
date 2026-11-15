from pathlib import Path
import shutil, datetime, re

main = Path("lib/main.dart")
backend = Path("backend/auth_routes.py")
stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

for p in (main, backend):
    shutil.copy2(p, str(p) + ".before_seat_" + stamp)

s = main.read_text()

# Replace upgrade dialog with seven seat choices.
start = s.index("  Future<void> _upgradeRoomSeats() async {")
end = s.index("  Future<void> _loadSeats() async {", start)

method = r'''  Future<void> _upgradeRoomSeats() async {
    if (roomRole != 'owner') return;

    const options = [5, 10, 15, 20, 25, 30, 36];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF102E49),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ROOM SEAT OPTIONS',
                style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 19)),
              const SizedBox(height: 8),
              Text('Unlocked: $seatCapacity seats',
                style: const TextStyle(color: Color(0xFF83D8FF))),
              const SizedBox(height: 15),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.65,
                children: options.map((capacity) {
                  final unlocked = capacity <= seatCapacity;
                  final active = capacity == seatCapacity;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: unlocked ? null : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Confirm Seat Upgrade'),
                          content: Text(
                            'Unlock $capacity seats for 1,000,000 Lovely Coins?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Buy Now')),
                          ],
                        ),
                      );
                      if (confirm != true || !mounted) return;
                      final ok = await _roomPost(
                        '/voice/rooms/${widget.room['id']}/seats/upgrade',
                        body: {'seat_capacity': capacity},
                      );
                      if (!mounted) return;
                      if (ok) {
                        await _loadSeats();
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        showMessage('$capacity seats unlocked!');
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: unlocked
                            ? const Color(0xFF14513F)
                            : const Color(0xFF183D5D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: unlocked
                              ? const Color(0xFF39D98A)
                              : const Color(0xFF65B8EA)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$capacity SEATS',
                            style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          if (unlocked)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle,
                                  color: Color(0xFF39D98A), size: 17),
                                const SizedBox(width: 4),
                                Text(active ? 'ACTIVE' : 'UNLOCKED',
                                  style: const TextStyle(
                                    color: Color(0xFF39D98A),
                                    fontSize: 11)),
                              ],
                            )
                          else
                            const Text('1,000,000 Coins',
                              style: TextStyle(
                                color: Color(0xFFFFD166),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CLOSE')),
            ],
          ),
        ),
      ),
    );
  }

'''
s = s[:start] + method + s[end:]

# Remove large member DP strip only (height 48); keep small DP strip (height 38).
a = s.index("                      if (occupiedSeats.isNotEmpty)\n                        SizedBox(\n                          height: 48,")
b = s.index("                      const SizedBox(height: 5),", a)
s = s[:a] + s[b:]

# Remove room-body Upgrade Seats row.
a = s.index("                      if (roomRole == 'owner')", a)
b = s.index("                    if (seatsLoading && seats.isEmpty)", a)
s = s[:a] + s[b:]

# Put Seats inside More menu instead of old Upgrade Room Seats.
pattern = re.compile(
    r"\s*if \(roomRole == 'owner' && seatCapacity < 36\)\s*"
    r"ListTile\(.*?onTap: \(\) \{\s*"
    r"Navigator\.pop\(ctx\);\s*_upgradeRoomSeats\(\);\s*\},\s*\),",
    re.S
)
s, count = pattern.subn("""
                                      if (roomRole == 'owner')
                                        ListTile(
                                          leading: const Icon(
                                            Icons.event_seat_rounded),
                                          title: const Text('Seats'),
                                          subtitle: Text(
                                            '$seatCapacity seats unlocked'),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            _upgradeRoomSeats();
                                          },
                                        ),
""", s, count=1)

if count != 1:
    raise SystemExit("ERROR: More menu item not found; main.dart not saved.")

main.write_text(s)
print("MAIN UI UPDATED")

# Existing backend already supports 5,10,15,20,25,30,36 and charges 1m.
b = backend.read_text()
if "if new_capacity not in {5, 10, 15, 20, 25, 30, 36}:" not in b:
    raise SystemExit("ERROR: Backend capacity validation differs; backend unchanged.")

needle = '''        if old_capacity == new_capacity:
            db.commit()
            return {
                "success": True,
                "seat_capacity": new_capacity,
                "cost": 0,
            }
'''
if needle not in b:
    raise SystemExit("ERROR: Backend same-capacity check not found.")

if "Seat capacity cannot be downgraded" not in b:
    b = b.replace(needle, needle + '''
        if new_capacity < old_capacity:
            raise HTTPException(400, "Seat capacity cannot be downgraded")
''', 1)
    backend.write_text(b)

print("BACKEND VERIFIED")
print("SUCCESS")
