import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide Group;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/group.dart';
import '../services/pocketbase_service.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.group});

  final Group group;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<GroupMember> _members = [];
  bool _isLoading = true;
  String? _errorMessage;
  late String _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final members = await PocketBaseService.instance
          .getGroupLeaderboard(widget.group.id, _selectedDate);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not load leaderboard.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddMemberDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => _AddMemberDialog(
        groupId: widget.group.id,
        onAdded: _loadLeaderboard,
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateFormat('yyyy-MM-dd').parse(_selectedDate),
      firstDate: today.subtract(const Duration(days: 90)),
      lastDate: today,
    );
    if (picked != null) {
      setState(() => _selectedDate = DateFormat('yyyy-MM-dd').format(picked));
      _loadLeaderboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isToday = _selectedDate == today;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add member',
            onPressed: _showAddMemberDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  isToday
                      ? 'Today'
                      : DateFormat.yMMMMd()
                          .format(DateFormat('yyyy-MM-dd').parse(_selectedDate)),
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('Change date'),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // Leaderboard
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _loadLeaderboard, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return const Center(child: Text('No members yet.'));
    }

    final currentUserId = PocketBaseService.instance.currentUserId;
    final maxSteps =
        _members.isEmpty ? 1 : (_members.first.steps > 0 ? _members.first.steps : 1);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = _members[index];
        final isMe = member.userId == currentUserId;
        return _LeaderboardTile(
          rank: index + 1,
          member: member,
          maxSteps: maxSteps,
          isMe: isMe,
        );
      },
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.member,
    required this.maxSteps,
    required this.isMe,
  });

  final int rank;
  final GroupMember member;
  final int maxSteps;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = (member.steps / maxSteps).clamp(0.0, 1.0);

    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : cs.onSurfaceVariant;

    return Card(
      color: isMe ? cs.primaryContainer.withValues(alpha: 0.4) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 32,
              child: Center(
                child: rank <= 3
                    ? Icon(Icons.emoji_events, color: rankColor, size: 22)
                    : Text(
                        '$rank',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: isMe ? cs.primary : cs.surfaceContainerHighest,
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isMe ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + progress bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.name + (isMe ? ' (you)' : ''),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                isMe ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        NumberFormat.decimalPattern().format(member.steps),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                          isMe ? cs.primary : cs.secondary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${member.steps} steps',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      if (member.rewardPoints > 0)
                        Text(
                          '₹${member.rewardPoints}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({required this.groupId, required this.onAdded});

  final String groupId;
  final VoidCallback onAdded;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

// Represents a device contact, whether or not they're in Mango Health.
class _ContactEntry {
  final String displayName;
  final String email;
  final String? userId;

  const _ContactEntry({
    required this.displayName,
    required this.email,
    this.userId,
  });

  bool get isMangoUser => userId != null;
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  List<_ContactEntry> _mangoContacts = [];
  List<_ContactEntry> _nonMangoContacts = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _adding = {};
  final Set<String> _added = {};
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted) {
        if (mounted) setState(() { _isLoading = false; _error = 'Contacts permission denied.'; });
        return;
      }

      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.email},
      );

      // Collect unique emails → contact
      final emailToContact = <String, Contact>{};
      for (final c in contacts) {
        for (final e in c.emails) {
          final normalized = e.address.trim().toLowerCase();
          if (normalized.isNotEmpty) emailToContact[normalized] = c;
        }
      }

      if (emailToContact.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Batch lookup in PocketBase (chunks of 50)
      final allEmails = emailToContact.keys.toList();
      final mangoUsers = <({String id, String name, String email})>[];
      for (var i = 0; i < allEmails.length; i += 50) {
        final end = (i + 50).clamp(0, allEmails.length);
        final found = await PocketBaseService.instance
            .lookupUsersByEmails(allEmails.sublist(i, end));
        mangoUsers.addAll(found);
      }

      final mangoEmailToUser = {for (final u in mangoUsers) u.email.toLowerCase(): u};
      final currentUserId = PocketBaseService.instance.currentUserId;

      final mango = <_ContactEntry>[];
      final nonMango = <_ContactEntry>[];
      final seen = <String>{};

      for (final entry in emailToContact.entries) {
        final email = entry.key;
        if (!seen.add(email)) continue;
        final displayName = (entry.value.displayName?.isNotEmpty == true)
            ? entry.value.displayName!
            : email;

        if (mangoEmailToUser.containsKey(email)) {
          final u = mangoEmailToUser[email]!;
          if (u.id == currentUserId) continue; // skip self
          mango.add(_ContactEntry(displayName: displayName, email: email, userId: u.id));
        } else {
          nonMango.add(_ContactEntry(displayName: displayName, email: email));
        }
      }

      mango.sort((a, b) => a.displayName.compareTo(b.displayName));
      nonMango.sort((a, b) => a.displayName.compareTo(b.displayName));

      if (mounted) {
        setState(() {
          _mangoContacts = mango;
          _nonMangoContacts = nonMango;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = 'Failed to load contacts: $e'; });
    }
  }

  Future<void> _add(String userId) async {
    setState(() => _adding.add(userId));
    try {
      await PocketBaseService.instance.addMemberToGroup(widget.groupId, userId);
      widget.onAdded();
      if (mounted) setState(() => _added.add(userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding.remove(userId));
    }
  }

  Future<void> _sendInvite(String contactName) async {
    const androidUrl =
        'https://play.google.com/store/apps/details?id=com.avilpage.mango_health';
    const iosUrl =
        'https://apps.apple.com/app/mango-health/id0000000000'; // replace with real ID

    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final storeUrl = isIos ? iosUrl : androidUrl;

    final message =
        'Hey $contactName! 👋 I\'m using Mango Health to track my daily steps and earn rewards 🥭🚶\n\n'
        'Join me and let\'s compete on the leaderboard!\n\n'
        'Download here: $storeUrl';

    await SharePlus.instance.share(ShareParams(text: message));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget body;
    if (_isLoading) {
      body = const Center(
        child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadContacts, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_mangoContacts.isEmpty && _nonMangoContacts.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No contacts with email addresses found.',
          textAlign: TextAlign.center,
        ),
      );
    } else {
      final q = _searchQuery.toLowerCase();
      final filteredMango = q.isEmpty
          ? _mangoContacts
          : _mangoContacts
              .where((c) =>
                  c.displayName.toLowerCase().contains(q) ||
                  c.email.toLowerCase().contains(q))
              .toList();
      final filteredNonMango = q.isEmpty
          ? _nonMangoContacts
          : _nonMangoContacts
              .where((c) =>
                  c.displayName.toLowerCase().contains(q) ||
                  c.email.toLowerCase().contains(q))
              .toList();

      final items = <Widget>[];

      if (filteredMango.isNotEmpty) {
        items.add(_SectionHeader(title: 'On Mango Health'));
        for (final c in filteredMango) {
          final isAdded = _added.contains(c.userId);
          final isAdding = _adding.contains(c.userId);
          items.add(_ContactTile(
            contact: c,
            cs: cs,
            theme: theme,
            trailing: isAdded
                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                : isAdding
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(52, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _add(c.userId!),
                        child: const Text('Add'),
                      ),
          ));
        }
      }

      if (filteredNonMango.isNotEmpty) {
        items.add(_SectionHeader(title: 'Not on Mango Health yet'));
        for (final c in filteredNonMango) {
          items.add(_ContactTile(
            contact: c,
            cs: cs,
            theme: theme,
            trailing: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(52, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _sendInvite(c.displayName),
              child: const Text('Invite'),
            ),
          ));
        }
      }

      if (items.isEmpty) {
        items.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Text('No contacts match your search.', textAlign: TextAlign.center),
        ));
      }

      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search contacts…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: items),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Add from contacts'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        // Cap total dialog content height so it never exceeds screen space
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.cs,
    required this.theme,
    required this.trailing,
  });

  final _ContactEntry contact;
  final ColorScheme cs;
  final ThemeData theme;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final isMango = contact.isMangoUser;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                isMango ? cs.primaryContainer : cs.surfaceContainerHighest,
            child: Text(
              contact.displayName.isNotEmpty
                  ? contact.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 12,
                color: isMango ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: contact.displayName,
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextSpan(
                    text: '  ${contact.email}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
