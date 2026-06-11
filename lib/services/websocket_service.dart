import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<String> statusText = ValueNotifier('Not connected');
  final ValueNotifier<String> lastAck = ValueNotifier('-');

  String lastIp = '10.0.2.2';
  String lastPort = '8765';

  Future<void> connect({
    required String ip,
    required String port,
  }) async {
    final cleanIp = ip.trim();
    final cleanPort = port.trim();

    lastIp = cleanIp;
    lastPort = cleanPort;

    final url = 'ws://$cleanIp:$cleanPort';

    try {
      statusText.value = 'Connecting to $url...';

      await _subscription?.cancel();
      await _channel?.sink.close();

      final channel = WebSocketChannel.connect(Uri.parse(url));

      await channel.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      _channel = channel;
      isConnected.value = true;
      statusText.value = 'Connected to $url';

      _subscription = _channel!.stream.listen(
        (message) {
          lastAck.value = message.toString();
        },
        onError: (error) {
          _channel = null;
          isConnected.value = false;
          statusText.value = 'Connection error: $error';
        },
        onDone: () {
          _channel = null;
          isConnected.value = false;
          statusText.value = 'Disconnected';
        },
      );
    } catch (e) {
      isConnected.value = false;
      statusText.value = 'Connect failed: $e';

      try {
        await _channel?.sink.close();
      } catch (_) {}

      _channel = null;
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();

    _subscription = null;
    _channel = null;

    isConnected.value = false;
    statusText.value = 'Disconnected';
  }

  void sendCommand({
    required String command,
    String? gesture,
    double? x,
    double? y,
    String? text,
  }) {
    if (_channel == null || !isConnected.value) {
      statusText.value = 'Cannot send: not connected';
      return;
    }

    final data = <String, dynamic>{
      'type': 'command',
      'command': command,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (gesture != null && gesture.trim().isNotEmpty) {
      data['gesture'] = gesture.trim();
    }

    if (x != null) {
      data['x'] = x;
    }

    if (y != null) {
      data['y'] = y;
    }

    if (text != null && text.trim().isNotEmpty) {
      data['text'] = text.trim();
    }

    _channel!.sink.add(jsonEncode(data));
    statusText.value = 'Sent: $command';
  }
}

final webSocketService = WebSocketService();