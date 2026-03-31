import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:app_blocker/app_blocker.dart';

void main() => runApp(const AppBlockerExampleApp());

// ─────────────────────────────────────────────────────────────────────────────
// App shell
// ─────────────────────────────────────────────────────────────────────────────

class AppBlockerExampleApp extends StatelessWidget {
  const AppBlockerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Blocker Demo',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _BlockingTab(),
          _SchedulesTab(),
          _ProfilesTab(),
          _EventsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.block), label: 'Blocking'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Schedules'),
          NavigationDestination(icon: Icon(Icons.view_list), label: 'Profiles'),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Events',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blocking tab
// ─────────────────────────────────────────────────────────────────────────────

class _BlockingTab extends StatefulWidget {
  const _BlockingTab();

  @override
  State<_BlockingTab> createState() => _BlockingTabState();
}

class _BlockingTabState extends State<_BlockingTab> {
  final _blocker = AppBlocker.instance;

  BlockerPermissionStatus? _permission;
  BlockerCapabilities? _caps;
  List<AppInfo> _apps = [];
  Set<String> _selectedApps = {};
  List<String> _blockedApps = [];
  bool _loadingApps = false;
  OverlayConfig? _overlayConfig;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadCaps();
    _refreshBlocked();
    _loadOverlayConfig();
  }

  Future<void> _checkPermission() async {
    try {
      final s = await _blocker.checkPermission();
      if (mounted) setState(() => _permission = s);
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _loadCaps() async {
    try {
      final c = await _blocker.getCapabilities();
      if (mounted) setState(() => _caps = c);
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _refreshBlocked() async {
    try {
      final list = await _blocker.getBlockedApps();
      if (mounted) setState(() => _blockedApps = list);
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _loadOverlayConfig() async {
    try {
      final config = await _blocker.getOverlayConfig();
      if (mounted) setState(() => _overlayConfig = config);
    } catch (_) {}
  }

  Future<void> _requestPermission() async {
    try {
      final s = await _blocker.requestPermission();
      if (mounted) setState(() => _permission = s);
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _selectApps() async {
    if (Platform.isIOS) {
      setState(() => _loadingApps = true);
      try {
        await _blocker.getApps();
        _snack('Apps selected via Screen Time');
      } catch (e) {
        _err('$e');
      } finally {
        setState(() => _loadingApps = false);
      }
      return;
    }

    if (_apps.isEmpty) {
      setState(() => _loadingApps = true);
      try {
        _apps = await _blocker.getApps();
      } catch (e) {
        _err('$e');
        setState(() => _loadingApps = false);
        return;
      }
      setState(() => _loadingApps = false);
    }

    if (!mounted) return;
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppPicker(apps: _apps, initial: _selectedApps),
    );
    if (selected != null) setState(() => _selectedApps = selected);
  }

  Future<void> _blockSelected() async {
    if (_selectedApps.isEmpty) return;
    try {
      await _blocker.blockApps(_selectedApps.toList());
      _snack('${_selectedApps.length} app(s) blocked');
      setState(() => _selectedApps = {});
      _refreshBlocked();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _unblockSelected() async {
    if (_selectedApps.isEmpty) return;
    try {
      await _blocker.unblockApps(_selectedApps.toList());
      _snack('${_selectedApps.length} app(s) unblocked');
      setState(() => _selectedApps = {});
      _refreshBlocked();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _blockAll() async {
    try {
      await _blocker.blockAll();
      _snack('All apps blocked');
      _refreshBlocked();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _unblockAll() async {
    try {
      await _blocker.unblockAll();
      _snack('All apps unblocked');
      _refreshBlocked();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _checkAppStatus() async {
    final id = await _showTextInput('App Status', 'Package name / bundle ID');
    if (id == null || id.isEmpty) return;
    try {
      final status = await _blocker.getAppStatus(id);
      _snack('"$id" is ${status.name}');
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _configureOverlay() async {
    final saved = await showDialog<OverlayConfig>(
      context: context,
      builder: (_) =>
          _OverlayConfigDialog(blocker: _blocker, initial: _overlayConfig),
    );
    if (saved != null) setState(() => _overlayConfig = saved);
  }

  Future<String?> _showTextInput(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final granted = _permission == BlockerPermissionStatus.granted;

    return Scaffold(
      appBar: AppBar(title: const Text('Blocking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Permissions & capabilities
          _Section(
            title: 'Permissions & Capabilities',
            children: [
              Row(
                children: [
                  Icon(
                    granted ? Icons.check_circle : Icons.warning,
                    color: granted ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text('Status: ${_permission?.name ?? '…'}'),
                ],
              ),
              if (_caps != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _CapChip('Block apps', _caps!.canBlockApps),
                    _CapChip('Overlay', _caps!.canShowOverlay),
                    _CapChip('Shield', _caps!.canUseSystemShield),
                    _CapChip('Schedule', _caps!.canSchedule),
                    _CapChip('App list', _caps!.canGetInstalledApps),
                    _CapChip('Picker', _caps!.canShowActivityPicker),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _checkPermission,
                    child: const Text('Check'),
                  ),
                  FilledButton(
                    onPressed: _requestPermission,
                    child: const Text('Request'),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadCaps,
                    child: const Text('Caps'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Block list
          _Section(
            title: 'Block List (${_blockedApps.length})',
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshBlocked,
            ),
            children: _blockedApps.isEmpty
                ? [
                    Text(
                      'None',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ]
                : _blockedApps
                      .map((p) => Text(p, style: theme.textTheme.bodySmall))
                      .toList(),
          ),
          const SizedBox(height: 12),

          // Block / unblock
          _Section(
            title: 'Block / Unblock Apps',
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: _loadingApps ? null : _selectApps,
                  child: _loadingApps
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _selectedApps.isEmpty
                              ? 'Select Apps'
                              : '${_selectedApps.length} selected — tap to change',
                        ),
                ),
              ),
              if (_selectedApps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _blockSelected,
                        child: Text('Block ${_selectedApps.length}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _unblockSelected,
                        child: Text('Unblock ${_selectedApps.length}'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _blockAll,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                      ),
                      child: const Text('Block All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _unblockAll,
                      child: const Text('Unblock All'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _checkAppStatus,
                  child: const Text('Check App Status…'),
                ),
              ),
            ],
          ),

          // Overlay config (Android only)
          if (Platform.isAndroid) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Overlay Config (Android)',
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _configureOverlay,
                    child: const Text('Configure Overlay…'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Overlay config dialog (Android-only)
class _OverlayConfigDialog extends StatefulWidget {
  const _OverlayConfigDialog({required this.blocker, this.initial});
  final AppBlocker blocker;
  final OverlayConfig? initial;

  @override
  State<_OverlayConfigDialog> createState() => _OverlayConfigDialogState();
}

class _OverlayConfigDialogState extends State<_OverlayConfigDialog> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _message;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _title = TextEditingController(text: c?.title ?? 'App Blocked');
    _subtitle = TextEditingController(text: c?.subtitle ?? 'Take a break!');
    _message = TextEditingController(
      text: c?.message ?? 'This app is currently blocked.',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Overlay Config'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _subtitle,
            decoration: const InputDecoration(labelText: 'Subtitle'),
          ),
          TextField(
            controller: _message,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final config = OverlayConfig(
              title: _title.text,
              subtitle: _subtitle.text,
              message: _message.text,
            );
            try {
              await widget.blocker.setOverlayConfig(config);
              if (context.mounted) {
                Navigator.pop(context, config);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Overlay config saved')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedules tab
// ─────────────────────────────────────────────────────────────────────────────

class _SchedulesTab extends StatefulWidget {
  const _SchedulesTab();

  @override
  State<_SchedulesTab> createState() => _SchedulesTabState();
}

class _SchedulesTabState extends State<_SchedulesTab> {
  final _blocker = AppBlocker.instance;
  List<BlockSchedule> _schedules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _blocker.getSchedules();
      if (mounted) setState(() => _schedules = s);
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _toggle(BlockSchedule s) async {
    try {
      if (s.enabled) {
        await _blocker.disableSchedule(s.id);
      } else {
        await _blocker.enableSchedule(s.id);
      }
      _load();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _blocker.removeSchedule(id);
      _load();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _add() async {
    final schedule = await showDialog<BlockSchedule>(
      context: context,
      builder: (_) => const _ScheduleDialog(),
    );
    if (schedule == null) return;
    try {
      await _blocker.addSchedule(schedule);
      _load();
    } catch (e) {
      _err('$e');
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _dayLabels(List<int> days) {
    const names = ['', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return days.map((d) => names[d]).join(', ');
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedules'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _schedules.isEmpty
          ? const Center(child: Text('No schedules yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _schedules.length,
              itemBuilder: (_, i) {
                final s = _schedules[i];
                return Card(
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text(
                      '${_fmtTime(s.startTime)} – ${_fmtTime(s.endTime)}'
                      ' • ${_dayLabels(s.weekdays)}'
                      '\n${s.appIdentifiers.length} app(s)',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(value: s.enabled, onChanged: (_) => _toggle(s)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(s.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog();

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  final _name = TextEditingController();
  final _appsInput = TextEditingController();
  final Set<int> _weekdays = {1, 2, 3, 4, 5};
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);

  static const _dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void dispose() {
    _name.dispose();
    _appsInput.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null)
      setState(() => isStart ? _start = picked : _end = picked);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Work hours',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _appsInput,
              decoration: const InputDecoration(
                labelText: 'App IDs (comma-separated)',
                hintText: 'com.instagram.android, ...',
              ),
            ),
            const SizedBox(height: 16),
            Text('Days', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: List.generate(7, (i) {
                final day = i + 1;
                return FilterChip(
                  label: Text(_dayNames[i]),
                  selected: _weekdays.contains(day),
                  onSelected: (v) => setState(
                    () => v ? _weekdays.add(day) : _weekdays.remove(day),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('Start: ${_fmtTime(_start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('End: ${_fmtTime(_end)}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final appIds = _appsInput.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            if (_name.text.trim().isEmpty ||
                _weekdays.isEmpty ||
                appIds.isEmpty)
              return;
            Navigator.pop(
              context,
              BlockSchedule(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _name.text.trim(),
                appIdentifiers: appIds,
                weekdays: _weekdays.toList()..sort(),
                startTime: _start,
                endTime: _end,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profiles tab
// ─────────────────────────────────────────────────────────────────────────────

class _ProfilesTab extends StatefulWidget {
  const _ProfilesTab();

  @override
  State<_ProfilesTab> createState() => _ProfilesTabState();
}

class _ProfilesTabState extends State<_ProfilesTab> {
  final _blocker = AppBlocker.instance;
  List<BlockProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _blocker.getProfiles();
      if (mounted) setState(() => _profiles = p);
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _toggle(BlockProfile p) async {
    try {
      if (p.isActive) {
        await _blocker.deactivateProfile(p.id);
      } else {
        await _blocker.activateProfile(p.id);
      }
      _load();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _blocker.deleteProfile(id);
      _load();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _create() async {
    final profile = await showDialog<BlockProfile>(
      context: context,
      builder: (_) => const _ProfileDialog(),
    );
    if (profile == null) return;
    try {
      await _blocker.createProfile(profile);
      _load();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _showActive() async {
    try {
      final p = await _blocker.getActiveProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              p == null ? 'No active profile' : 'Active: ${p.name}',
            ),
          ),
        );
      }
    } catch (e) {
      _err('$e');
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Get active profile',
            onPressed: _showActive,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _profiles.isEmpty
          ? const Center(child: Text('No profiles yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _profiles.length,
              itemBuilder: (_, i) {
                final p = _profiles[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.isActive
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        color: p.isActive ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.appIdentifiers.length} apps'
                      ' • ${p.schedules.length} schedules'
                      '${p.isActive ? ' • Active' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _toggle(p),
                          child: Text(p.isActive ? 'Deactivate' : 'Activate'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(p.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog();

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _name = TextEditingController();
  final _appsInput = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _appsInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Work Mode',
            ),
            autofocus: true,
          ),
          TextField(
            controller: _appsInput,
            decoration: const InputDecoration(
              labelText: 'App IDs (comma-separated)',
              hintText: 'com.instagram.android, ...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            final appIds = _appsInput.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            Navigator.pop(
              context,
              BlockProfile(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _name.text.trim(),
                appIdentifiers: appIds,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Events tab
// ─────────────────────────────────────────────────────────────────────────────

class _EventsTab extends StatefulWidget {
  const _EventsTab();

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  StreamSubscription<BlockEvent>? _sub;
  final List<BlockEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _sub = AppBlocker.instance.onBlockEvent.listen((e) {
      if (mounted) setState(() => _events.insert(0, e));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Events (${_events.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear',
            onPressed: () => setState(() => _events.clear()),
          ),
        ],
      ),
      body: _events.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('No events yet'),
                  const SizedBox(height: 4),
                  Text(
                    'Block or unblock apps to see events here',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _events.length,
              itemBuilder: (_, i) {
                final e = _events[i];
                return Card(
                  child: ListTile(
                    leading: _EventIcon(type: e.type),
                    title: Text(e.type.name),
                    subtitle: Text(
                      [
                        if (e.packageName != null) e.packageName!,
                        if (e.scheduleId != null) 'schedule: ${e.scheduleId}',
                        _fmtTime(e.timestamp),
                      ].join(' • '),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EventIcon extends StatelessWidget {
  const _EventIcon({required this.type});
  final BlockEventType type;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (type) {
      BlockEventType.blocked => (Icons.block, Colors.red),
      BlockEventType.unblocked => (Icons.lock_open, Colors.green),
      BlockEventType.attemptedAccess => (Icons.warning_amber, Colors.orange),
      BlockEventType.scheduleActivated => (Icons.schedule, Colors.blue),
      BlockEventType.scheduleDeactivated => (Icons.schedule_send, Colors.grey),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CapChip extends StatelessWidget {
  const _CapChip(this.label, this.supported);

  final String label;
  final bool supported;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      avatar: Icon(
        supported ? Icons.check : Icons.close,
        size: 14,
        color: supported ? Colors.green : Colors.red,
      ),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AppPicker extends StatefulWidget {
  const _AppPicker({required this.apps, required this.initial});

  final List<AppInfo> apps;
  final Set<String> initial;

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  late final Set<String> _selected = Set.from(widget.initial);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Apps',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${_selected.length} selected',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: widget.apps.length,
              itemBuilder: (_, i) {
                final app = widget.apps[i];
                final isSelected = _selected.contains(app.packageName);
                return ListTile(
                  leading: _AppIcon(icon: app.icon),
                  title: Text(
                    app.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: cs.primary)
                      : const Icon(Icons.circle_outlined),
                  onTap: () => setState(
                    () => isSelected
                        ? _selected.remove(app.packageName)
                        : _selected.add(app.packageName),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: Text(
                _selected.isEmpty
                    ? 'Confirm (none selected)'
                    : 'Confirm (${_selected.length})',
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.icon});

  final Uint8List? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(icon!, width: 40, height: 40, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.apps,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }
}
