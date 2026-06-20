import 'dart:convert';
import 'dart:math';

import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/daily_step.dart';
import '../models/group.dart';
import 'database_service.dart';

class PocketBaseService {
  PocketBaseService._();

  static final PocketBaseService instance = PocketBaseService._();

  late final PocketBase _client;

  bool get isAuthenticated => _client.authStore.isValid;
  String? get currentUserId => _client.authStore.record?.id;
  String? get currentUserName => _client.authStore.record?.getStringValue('name');
  String? get currentUserEmail => _client.authStore.record?.getStringValue('email');

  Future<void> init(String url) async {
    _client = PocketBase(url.trim());
    await _restoreAuth();
  }

  Future<void> _restoreAuth() async {
    final saved = await DatabaseService.instance.loadAuth();
    if (saved == null) return;
    try {
      final record = RecordModel.fromJson(
        jsonDecode(saved.recordJson) as Map<String, dynamic>,
      );
      _client.authStore.save(saved.token, record);
      // Refresh token in background — ignore errors (offline is fine)
      _client.collection('users').authRefresh().then((_) async {
        await _persistAuth();
      }).catchError((_) {});
    } catch (_) {
      await DatabaseService.instance.clearAuth();
    }
  }

  Future<void> _persistAuth() async {
    final token = _client.authStore.token;
    final record = _client.authStore.record;
    if (token.isEmpty || record == null) return;
    await DatabaseService.instance.saveAuth(
      token: token,
      recordJson: jsonEncode(record.toJson()),
    );
  }

  Future<RecordAuth> authWithGoogle() async {
    final auth = await _client.collection('users').authWithOAuth2(
      'google',
      (url) async {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not open browser for Google sign-in.');
        }
      },
      createData: {},
    );
    await _persistAuth();
    return auth;
  }

  Future<RecordAuth> login(String email, String password) async {
    final auth = await _client.collection('users').authWithPassword(
      email.trim(),
      password,
    );
    await _persistAuth();
    return auth;
  }

  Future<RecordAuth> register(String email, String password, String name) async {
    await _client.collection('users').create(body: {
      'email': email.trim(),
      'password': password,
      'passwordConfirm': password,
      'name': name.trim(),
    });
    final auth = await _client.collection('users').authWithPassword(
      email.trim(),
      password,
    );
    await _persistAuth();
    return auth;
  }

  Future<void> logout() async {
    _client.authStore.clear();
    await DatabaseService.instance.clearAuth();
  }

  // ── Steps sync ──────────────────────────────────────────────────────────────

  Future<void> syncSteps(List<DailyStep> unsynced) async {
    final userId = currentUserId;
    if (userId == null || unsynced.isEmpty) return;

    final collection = _client.collection('steps');

    for (final step in unsynced) {
      final payload = {
        'user': userId,
        'date': step.date,
        'steps': step.steps,
        'reward_points': step.rewardPoints,
      };

      try {
        final existing = await collection.getFirstListItem(
          _client.filter('user = {:user} && date = {:date}', {
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

  // ── Groups ───────────────────────────────────────────────────────────────────

  Future<List<({String id, String name, String email})>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final results = await _client.collection('users').getList(
      filter: _client.filter(
        'name ~ {:q} || email ~ {:q}',
        {'q': query.trim()},
      ),
      perPage: 20,
      fields: 'id,name,email',
    );
    return results.items.map((r) => (
      id: r.id,
      name: r.getStringValue('name'),
      email: r.getStringValue('email'),
    )).toList();
  }

  /// Looks up multiple users by their email addresses in a single PocketBase request.
  /// Returns only those emails that have a Mango Health account.
  Future<List<({String id, String name, String email})>> lookupUsersByEmails(
      List<String> emails) async {
    if (emails.isEmpty) return [];
    // PocketBase filter: email='a'||email='b'||...
    final filter = emails.map((e) => "email='${e.toLowerCase()}'").join('||');
    final results = await _client.collection('users').getList(
      filter: filter,
      perPage: emails.length,
      fields: 'id,name,email',
    );
    return results.items.map((r) => (
      id: r.id,
      name: r.getStringValue('name'),
      email: r.getStringValue('email'),
    )).toList();
  }

  Future<void> addMemberToGroup(String groupId, String userId) async {
    // Check if already a member
    try {
      await _client.collection('group_members').getFirstListItem(
        _client.filter('group = {:g} && user = {:u}', {'g': groupId, 'u': userId}),
      );
      return; // already a member
    } on ClientException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
    await _client.collection('group_members').create(body: {
      'group': groupId,
      'user': userId,
    });
  }

  Future<Group> createGroup(String name) async {
    final inviteCode = _generateInviteCode();
    final record = await _client.collection('groups').create(body: {
      'name': name.trim(),
      'invite_code': inviteCode,
      'created_by': currentUserId,
    });
    // Auto-join as member
    await _client.collection('group_members').create(body: {
      'group': record.id,
      'user': currentUserId,
    });
    return Group.fromRecord(record);
  }

  Future<Group> joinGroup(String inviteCode) async {
    final records = await _client.collection('groups').getList(
      filter: _client.filter('invite_code = {:code}', {'code': inviteCode.trim().toUpperCase()}),
    );
    if (records.items.isEmpty) {
      throw Exception('No group found with that invite code.');
    }
    final group = Group.fromRecord(records.items.first);

    // Check if already a member
    try {
      await _client.collection('group_members').getFirstListItem(
        _client.filter('group = {:g} && user = {:u}', {
          'g': group.id,
          'u': currentUserId,
        }),
      );
      // Already a member — just return
      return group;
    } on ClientException catch (e) {
      if (e.statusCode != 404) rethrow;
    }

    await _client.collection('group_members').create(body: {
      'group': group.id,
      'user': currentUserId,
    });
    return group;
  }

  Future<List<Group>> getMyGroups() async {
    final memberships = await _client.collection('group_members').getFullList(
      filter: _client.filter('user = {:u}', {'u': currentUserId}),
      expand: 'group',
    );
    return memberships
        .map((m) {
          final group = m.get<RecordModel?>('expand.group');
          if (group == null) return null;
          return Group.fromRecord(group);
        })
        .whereType<Group>()
        .toList();
  }

  Future<List<GroupMember>> getGroupLeaderboard(String groupId, String date) async {
    // 1. Get all members with expanded user info
    final memberships = await _client.collection('group_members').getFullList(
      filter: _client.filter('group = {:g}', {'g': groupId}),
      expand: 'user',
    );

    final userIds = memberships
        .map((m) => m.get<RecordModel?>('expand.user')?.id)
        .whereType<String>()
        .toList();

    if (userIds.isEmpty) return [];

    // 2. Fetch steps for all members on the given date in one query
    final filter = userIds
        .map((id) => "user='$id'")
        .join('||');
    final stepsRecords = await _client.collection('steps').getFullList(
      filter: '($filter)&&date="$date"',
    );

    final stepsMap = {
      for (final s in stepsRecords)
        s.getStringValue('user'): (
          steps: s.getIntValue('steps'),
          points: s.getIntValue('reward_points'),
        ),
    };

    // 3. Assemble leaderboard
    final members = memberships
        .map((m) {
          final user = m.get<RecordModel?>('expand.user');
          if (user == null) return null;
          final stepData = stepsMap[user.id];
          return GroupMember(
            userId: user.id,
            name: user.getStringValue('name').isEmpty
                ? user.getStringValue('email')
                : user.getStringValue('name'),
            email: user.getStringValue('email'),
            steps: stepData?.steps ?? 0,
            rewardPoints: stepData?.points ?? 0,
          );
        })
        .whereType<GroupMember>()
        .toList();

    members.sort((a, b) => b.steps.compareTo(a.steps));
    return members;
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

