import 'package:pocketbase/pocketbase.dart';

import '../models/daily_step.dart';

class PocketBaseService {
  PocketBase? _client;
  String? _url;

  bool get isConfigured => _client != null;
  bool get isAuthenticated => _client?.authStore.isValid ?? false;
  String? get configuredUrl => _url;

  void configure(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      _url = null;
      _client = null;
      return;
    }

    _url = normalized;
    _client = PocketBase(normalized);
  }

  Future<RecordAuth?> login(String email, String password) async {
    final client = _client;
    if (client == null) {
      return null;
    }

    return client.collection('users').authWithPassword(email.trim(), password);
  }

  Future<void> syncSteps(List<DailyStep> unsynced) async {
    final client = _client;
    final userId = client?.authStore.record?.id;
    if (client == null || userId == null || unsynced.isEmpty) {
      return;
    }

    final collection = client.collection('steps');

    for (final step in unsynced) {
      final payload = {
        'user': userId,
        'date': step.date,
        'steps': step.steps,
        'reward_points': step.rewardPoints,
      };

      try {
        final existing = await collection.getFirstListItem(
          client.filter('user = {:user} && date = {:date}', {
            'user': userId,
            'date': step.date,
          }),
        );
        await collection.update(existing.id, body: payload);
      } on ClientException catch (error) {
        if (error.statusCode == 404) {
          await collection.create(body: payload);
        } else {
          rethrow;
        }
      }
    }
  }
}
