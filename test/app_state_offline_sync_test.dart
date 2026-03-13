import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:princess_trackers/models/app_models.dart';
import 'package:princess_trackers/models/power_block.dart';
import 'package:princess_trackers/models/tracker.dart';
import 'package:princess_trackers/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeConnectivityPlatform extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  FakeConnectivityPlatform(this._currentResults);

  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> _currentResults;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _currentResults;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void emit(List<ConnectivityResult> results) {
    _currentResults = results;
    _controller.add(results);
  }

  Future<void> disposePlatform() async {
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeConnectivityPlatform connectivityPlatform;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    connectivityPlatform =
        FakeConnectivityPlatform(const [ConnectivityResult.none]);
    ConnectivityPlatform.instance = connectivityPlatform;
  });

  tearDown(() async {
    await connectivityPlatform.disposePlatform();
  });

  test('offline status change flushes on reconnect', () async {
    final state = AppState();
    state.currentTracker = Tracker(
      id: 1,
      name: 'LBD Tracker',
      slug: 'lbd',
      statusTypes: const ['term'],
    );
    state.blocks = [
      PowerBlock(
        id: 1,
        name: 'INV-1',
        powerBlockNumber: 1,
        lbdCount: 1,
        lbds: [
          LbdItem(
            id: 1,
            name: 'LBD 1',
            identifier: 'LBD-001',
            statuses: [LbdStatus(statusType: 'term', isCompleted: false)],
          ),
        ],
      ),
    ];

    state.isOffline = true;

    await state.toggleStatus(1, 'term', true);

    final prefs = await SharedPreferences.getInstance();
    final queuedOffline =
        jsonDecode(prefs.getString('pending_queue') ?? '[]') as List<dynamic>;
    expect(queuedOffline, hasLength(1));
    expect(queuedOffline.first['type'], 'status');
    expect(
      state.blocks.first.lbds.first.statuses.first.isCompleted,
      isTrue,
    );

    connectivityPlatform.emit(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(seconds: 2));

    final queuedAfterReconnect =
        jsonDecode(prefs.getString('pending_queue') ?? '[]') as List<dynamic>;
    expect(queuedAfterReconnect, isEmpty);
    expect(state.blocks.first.lbds.first.statuses.first.isCompleted, isTrue);
  });

  test('offline shared claim stores all selected people', () async {
    final state = AppState();
    state.user = User(id: 7, name: 'Alice', username: 'alice');
    state.currentTracker = Tracker(
      id: 1,
      name: 'LBD Tracker',
      slug: 'lbd',
      statusTypes: const ['term'],
    );
    state.blocks = [
      PowerBlock(
        id: 1,
        name: 'INV-1',
        powerBlockNumber: 1,
        lbdCount: 1,
        lbds: const [],
      ),
    ];

    state.isOffline = true;

    await state.claimBlock(1, people: const ['Bob', 'Helper Guy']);

    expect(state.blocks.first.claimedPeople, ['Alice', 'Bob', 'Helper Guy']);
    expect(state.blocks.first.claimedLabel, 'Alice, Bob, Helper Guy');

    final prefs = await SharedPreferences.getInstance();
    final queued =
        jsonDecode(prefs.getString('pending_queue') ?? '[]') as List<dynamic>;
    expect(queued, hasLength(1));
    expect(queued.first['type'], 'claim');
    expect(
      List<String>.from(queued.first['people'] as List<dynamic>),
      ['Alice', 'Bob', 'Helper Guy'],
    );
  });
}