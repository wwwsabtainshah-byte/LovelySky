import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TransparentFrameVideo extends StatefulWidget {
  const TransparentFrameVideo({super.key});

  @override
  State<TransparentFrameVideo> createState() =>
      _TransparentFrameVideoState();
}

class _TransparentFrameVideoState extends State<TransparentFrameVideo> {
  WebViewController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final bytes = await rootBundle.load(
        'assets/live_room_seat_frame_transparent.webm',
      );

      final videoData = base64Encode(
        bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        ),
      );

      final controller = WebViewController();

      await controller.setJavaScriptMode(
        JavaScriptMode.unrestricted,
      );

      await controller.setBackgroundColor(
        const Color(0x00000000),
      );

      await controller.loadHtmlString('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport"
                content="width=device-width, initial-scale=1">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              width: 100%;
              height: 100%;
              overflow: hidden;
              background: transparent !important;
            }
            video {
              width: 100%;
              height: 100%;
              object-fit: contain;
              background: transparent;
            }
          </style>
        </head>
        <body>
          <video autoplay muted loop playsinline>
            <source
              src="data:video/webm;base64,$videoData"
              type="video/webm">
          </video>
        </body>
        </html>
      ''');

      if (!mounted) return;

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) {
      return IgnorePointer(
        child: WebViewWidget(controller: _controller!),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Video error: $_error',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFFFFD779),
      ),
    );
  }
}
