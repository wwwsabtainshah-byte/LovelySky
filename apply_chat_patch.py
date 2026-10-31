from pathlib import Path
import sys

p = Path("lib/main.dart")
s = p.read_text()

old = """  void sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({'text': text, 'time': TimeOfDay.now().format(context)});
      messageController.clear();
    });
  }"""

new = """  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');
      if (token == null || token.isEmpty) return;
      final response = await http.get(
        Uri.parse('$lovelyApi/voice/rooms/${widget.room['id']}/messages'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 12));
      if (!mounted || response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (data['messages'] as List<dynamic>? ?? [])
          .map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        return <String, dynamic>{
          'id': row['id'],
          'text': '${row['sender_code'] ?? ''}: ${row['message'] ?? ''}',
          'time': '${row['created_at'] ?? ''}',
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(rows);
      });
    } catch (_) {}
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');
    if (token == null || token.isEmpty) {
      showMessage('Please log in first.');
      return;
    }
    messageController.clear();
    try {
      final response = await http.post(
        Uri.parse('$lovelyApi/voice/rooms/${widget.room['id']}/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': text}),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        await _loadMessages();
      } else {
        messageController.text = text;
        showMessage('Message send nahi hua (${response.statusCode}). Room join check karein.');
      }
    } catch (_) {
      if (!mounted) return;
      messageController.text = text;
      showMessage('Chat connection error. Dobara send karein.');
    }
  }"""

if s.count(old) != 1:
    sys.exit("Expected function exactly once nahi mila. main.dart unchanged.")

patched = s.replace(old, new, 1)
if "_loadMessages()" not in patched:
    sys.exit("Patch verification failed. main.dart unchanged.")

Path("main.dart.chat-patched-preview").write_text(patched)
print("PATCH PREVIEW READY; main.dart abhi change nahi hui.")
