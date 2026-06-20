import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group.dart';
import '../services/pocketbase_service.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group> _groups = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final groups = await PocketBaseService.instance.getMyGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Could not load groups.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create group'),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Group name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text),
              child: const Text('Create')),
        ],
      ),
    );
    // Defer dispose so the dialog close animation completes first
    Future.microtask(nameCtrl.dispose);
    if (result == null || result.trim().isEmpty) return;
    await _createGroup(result.trim());
  }

  Future<void> _showJoinDialog() async {
    final codeCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join group'),
        content: TextField(
          controller: codeCtrl,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Invite code',
            hintText: 'e.g. ABC123',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, codeCtrl.text),
              child: const Text('Join')),
        ],
      ),
    );
    Future.microtask(codeCtrl.dispose);
    if (result == null || result.trim().isEmpty) return;
    _joinGroup(result.trim());
  }

  Future<void> _createGroup(String name) async {
    try {
      final group = await PocketBaseService.instance.createGroup(name);
      await _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group created! Invite code: ${group.inviteCode}'),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () => Clipboard.setData(
                  ClipboardData(text: group.inviteCode)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    }
  }

  Future<void> _joinGroup(String code) async {
    try {
      final group = await PocketBaseService.instance.joinGroup(code);
      await _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined "${group.name}"!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroups,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'join',
            onPressed: _showJoinDialog,
            tooltip: 'Join group',
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('New group'),
          ),
        ],
      ),
      body: _buildBody(),
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
            FilledButton(onPressed: _loadGroups, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No groups yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group or join one with an invite code.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final group = _groups[index];
        return _GroupCard(
          group: group,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(group: group),
            ),
          ),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});

  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Text(
                  group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Code: ',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant),
                        ),
                        Text(
                          group.inviteCode,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => Clipboard.setData(
                              ClipboardData(text: group.inviteCode)),
                          child: Icon(Icons.copy, size: 14, color: cs.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
