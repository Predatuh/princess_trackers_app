import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class RealtimeSyncService {
  RealtimeSyncService({required this.baseUrl});

  final String baseUrl;
  io.Socket? _socket;
  VoidCallback? _onBlocksChanged;
  VoidCallback? _onHubChanged;
  Timer? _blocksDebounce;
  Timer? _hubDebounce;

  bool get isConnected => _socket?.connected ?? false;

  bool get _realtimeEnabled {
    const explicitRealtime = bool.fromEnvironment('ENABLE_REALTIME', defaultValue: false);
    if (explicitRealtime) {
      return true;
    }

    final uri = Uri.tryParse(baseUrl);
    final host = uri?.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host == 'princesstrackers.com' ||
        host == 'www.princesstrackers.com';
  }

  void connect({
    required VoidCallback onBlocksChanged,
    required VoidCallback onHubChanged,
  }) {
    _onBlocksChanged = onBlocksChanged;
    _onHubChanged = onHubChanged;

    if (!_realtimeEnabled) {
      if (kDebugMode) {
        debugPrint('RealtimeSyncService disabled for baseUrl=$baseUrl');
      }
      return;
    }

    if (_socket != null) {
      if (!(_socket?.connected ?? false)) {
        _socket?.connect();
      }
      return;
    }

    final rootUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    _socket = io.io(
      rootUrl,
      io.OptionBuilder()
          .setTransports(['polling'])
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket?.onConnect((_) {
      if (kDebugMode) {
        debugPrint('RealtimeSyncService connected');
      }
    });

    _socket?.onConnectError((error) {
      if (kDebugMode) {
        debugPrint('RealtimeSyncService connect error: $error');
      }
    });

    _socket?.onError((error) {
      if (kDebugMode) {
        debugPrint('RealtimeSyncService socket error: $error');
      }
    });

    _socket?.on('status_update', (_) {
      _scheduleBlocksRefresh();
      _scheduleHubRefresh();
    });
    _socket?.on('bulk_update', (_) {
      _scheduleBlocksRefresh();
      _scheduleHubRefresh();
    });
    _socket?.on('claim_update', (_) {
      _scheduleBlocksRefresh();
      _scheduleHubRefresh();
    });
  }

  void _scheduleBlocksRefresh() {
    _blocksDebounce?.cancel();
    _blocksDebounce = Timer(const Duration(milliseconds: 250), () {
      _onBlocksChanged?.call();
    });
  }

  void _scheduleHubRefresh() {
    _hubDebounce?.cancel();
    _hubDebounce = Timer(const Duration(milliseconds: 350), () {
      _onHubChanged?.call();
    });
  }

  void disconnect() {
    _blocksDebounce?.cancel();
    _hubDebounce?.cancel();
    _socket?.dispose();
    _socket = null;
  }
}