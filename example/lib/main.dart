import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:app_blocker/app_blocker.dart';

void main() {
  runApp(const AppBlockerExampleApp());
}

class AppBlockerExampleApp extends StatelessWidget {
  const AppBlockerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Blocker Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = const <Widget>[
    BlockTab(),
    SchedulesTab(),
    ProfilesTab(),
    EventsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.block),
            selectedIcon: Icon(Icons.block, color: Colors.deepPurple),
            label: 'Block',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule),
            selectedIcon: Icon(Icons.schedule, color: Colors.deepPurple),
            label: 'Schedules',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            selectedIcon: Icon(Icons.person, color: Colors.deepPurple),
            label: 'Profiles',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            selectedIcon: Icon(Icons.list_alt, color: Colors.deepPurple),
            label: 'Events',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 1: Block
// =============================================================================

class BlockTab extends StatefulWidget {
  const BlockTab({super.key});

  @override
  State<BlockTab> createState() => _BlockTabState();
}

class _BlockTabState extends State<BlockTab> {
  final _blocker = AppBlocker.instance;

  BlockerPermissionStatus? _permissionStatus;
  List<AppInfo> _apps = [];
  List<String> _blockedApps = [];
  final Set<String> _selectedApps = {};
  bool _loadingApps = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadBlockedApps();
  }

  Future<void> _checkPermission() async {
    try {
      final status = await _blocker.checkPermission();
      setState(() => _permissionStatus = status);
    } catch (e) {
      _showError('Failed to check permission: $e');
    }
  }

  Future<void> _requestPermission() async {
    try {
      final status = await _blocker.requestPermission();
      setState(() => _permissionStatus = status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission status: ${status.name}')),
        );
      }
    } catch (e) {
      _showError('Failed to request permission: $e');
    }
  }

  Future<void> _selectApps() async {
    if (_apps.isEmpty) {
      setState(() => _loadingApps = true);
      try {
        final apps = await _blocker.getApps();
        setState(() {
          _apps = apps;
          _loadingApps = false;
        });
      } catch (e) {
        setState(() => _loadingApps = false);
        _showError('Failed to get apps: $e');
        return;
      }
    }

    if (!mounted || _apps.isEmpty) return;

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AppPickerBottomSheet(apps: _apps),
    );

    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _selectedApps.clear();
        _selectedApps.addAll(selected);
      });
    }
  }

  Future<void> _blockSelectedApps() async {
    if (_selectedApps.isEmpty) return;

    try {
      await _blocker.blockApps(_selectedApps.toList());
      await _loadBlockedApps();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedApps.length} app(s) blocked'),
          ),
        );
        setState(() => _selectedApps.clear());
      }
    } catch (e) {
      _showError('Failed to block apps: $e');
    }
  }

  Future<void> _loadBlockedApps() async {
    try {
      final blocked = await _blocker.getBlockedApps();
      setState(() => _blockedApps = blocked);
    } catch (e) {
      _showError('Failed to load blocked apps: $e');
    }
  }

  Future<void> _unblockApp(String packageName) async {
    try {
      await _blocker.unblockApps([packageName]);
      await _loadBlockedApps();
    } catch (e) {
      _showError('Failed to unblock app: $e');
    }
  }

  Future<void> _blockAll() async {
    try {
      await _blocker.blockAll();
      await _loadBlockedApps();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All apps blocked')),
        );
      }
    } catch (e) {
      _showError('Failed to block all: $e');
    }
  }

  Future<void> _unblockAll() async {
    try {
      await _blocker.unblockAll();
      await _loadBlockedApps();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All apps unblocked')),
        );
      }
    } catch (e) {
      _showError('Failed to unblock all: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('App Blocker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Permission section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Permissions', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _permissionStatus == BlockerPermissionStatus.granted
                            ? Icons.check_circle
                            : Icons.warning,
                        color:
                            _permissionStatus == BlockerPermissionStatus.granted
                                ? Colors.green
                                : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${_permissionStatus?.name ?? 'unknown'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: _checkPermission,
                        child: const Text('Check'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _requestPermission,
                        child: const Text('Request'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Select & Block Apps section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Block Apps', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: _loadingApps ? null : _selectApps,
                      child: _loadingApps
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _selectedApps.isEmpty
                                  ? 'Select Apps'
                                  : '${_selectedApps.length} app(s) selected — Tap to change',
                            ),
                    ),
                  ),
                  if (_selectedApps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _blockSelectedApps,
                        child: Text(
                          'Block ${_selectedApps.length} App(s)',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bulk actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bulk Actions', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _blockAll,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                        ),
                        child: const Text('Block All'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _unblockAll,
                        child: const Text('Unblock All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Blocked apps list
          Text(
            'Blocked Apps (${_blockedApps.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_blockedApps.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No apps are currently blocked')),
              ),
            )
          else
            ...List.generate(_blockedApps.length, (index) {
              final packageName = _blockedApps[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.app_blocking),
                  title: Text(packageName),
                  trailing: IconButton(
                    icon: const Icon(Icons.lock_open),
                    tooltip: 'Unblock',
                    onPressed: () => _unblockApp(packageName),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AppPickerBottomSheet extends StatefulWidget {
  const _AppPickerBottomSheet({required this.apps});

  final List<AppInfo> apps;

  @override
  State<_AppPickerBottomSheet> createState() => _AppPickerBottomSheetState();
}

class _AppPickerBottomSheetState extends State<_AppPickerBottomSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Choose Apps',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_selected.length} app(s) selected',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: widget.apps.isEmpty
                ? Center(
                    child: Text(
                      'No apps found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.apps.length,
                    itemBuilder: (context, index) {
                      final app = widget.apps[index];
                      final isSelected =
                          _selected.contains(app.packageName);
                      return _AppTile(
                        app: app,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(app.packageName);
                            } else {
                              _selected.add(app.packageName);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selected.toList()),
              child: Text(
                _selected.isEmpty
                    ? 'Select apps to block'
                    : 'Confirm (${_selected.length})',
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.isSelected,
    required this.onTap,
  });

  final AppInfo app;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            _AppIcon(icon: app.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                app.appName,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check,
                      size: 14, color: colorScheme.onPrimary)
                  : null,
            ),
          ],
        ),
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
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

// =============================================================================
// Tab 2: Schedules
// =============================================================================

class SchedulesTab extends StatefulWidget {
  const SchedulesTab({super.key});

  @override
  State<SchedulesTab> createState() => _SchedulesTabState();
}

class _SchedulesTabState extends State<SchedulesTab> {
  final _blocker = AppBlocker.instance;

  List<BlockSchedule> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final schedules = await _blocker.getSchedules();
      setState(() => _schedules = schedules);
    } catch (e) {
      _showError('Failed to load schedules: $e');
    }
  }

  Future<void> _toggleSchedule(BlockSchedule schedule) async {
    try {
      if (schedule.enabled) {
        await _blocker.disableSchedule(schedule.id);
      } else {
        await _blocker.enableSchedule(schedule.id);
      }
      await _loadSchedules();
    } catch (e) {
      _showError('Failed to toggle schedule: $e');
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    try {
      await _blocker.removeSchedule(scheduleId);
      await _loadSchedules();
    } catch (e) {
      _showError('Failed to delete schedule: $e');
    }
  }

  Future<void> _addSchedule() async {
    final result = await showDialog<BlockSchedule>(
      context: context,
      builder: (context) => const _AddScheduleDialog(),
    );

    if (result != null) {
      try {
        await _blocker.addSchedule(result);
        await _loadSchedules();
      } catch (e) {
        _showError('Failed to add schedule: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedules')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSchedule,
        child: const Icon(Icons.add),
      ),
      body: _schedules.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No schedules yet'),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create a schedule',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return Dismissible(
                  key: ValueKey(schedule.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Schedule'),
                        content: Text(
                          'Delete "${schedule.name}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => _deleteSchedule(schedule.id),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.schedule,
                        color: schedule.enabled ? Colors.green : Colors.grey,
                      ),
                      title: Text(schedule.name),
                      subtitle: Text(
                        '${_formatTime(schedule.startTime)} - ${_formatTime(schedule.endTime)}'
                        ' | ${_formatWeekdays(schedule.weekdays)}',
                      ),
                      trailing: Switch(
                        value: schedule.enabled,
                        onChanged: (_) => _toggleSchedule(schedule),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatWeekdays(List<int> weekdays) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays.map((d) => names[d - 1]).join(', ');
  }
}

class _AddScheduleDialog extends StatefulWidget {
  const _AddScheduleDialog();

  @override
  State<_AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<_AddScheduleDialog> {
  final _nameController = TextEditingController();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Mon-Fri default

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return AlertDialog(
      title: const Text('New Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Schedule Name',
                hintText: 'e.g., Work Hours',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_startTime.format(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_endTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Days'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final day = i + 1;
                final isSelected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    });
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      dayLabels[i],
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
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
            final name = _nameController.text.trim();
            if (name.isEmpty || _selectedDays.isEmpty) return;

            final schedule = BlockSchedule(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              appIdentifiers: const [],
              weekdays: _selectedDays.toList()..sort(),
              startTime: _startTime,
              endTime: _endTime,
            );
            Navigator.pop(context, schedule);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// =============================================================================
// Tab 3: Profiles
// =============================================================================

class ProfilesTab extends StatefulWidget {
  const ProfilesTab({super.key});

  @override
  State<ProfilesTab> createState() => _ProfilesTabState();
}

class _ProfilesTabState extends State<ProfilesTab> {
  final _blocker = AppBlocker.instance;

  List<BlockProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final profiles = await _blocker.getProfiles();
      setState(() => _profiles = profiles);
    } catch (e) {
      _showError('Failed to load profiles: $e');
    }
  }

  Future<void> _toggleProfile(BlockProfile profile) async {
    try {
      if (profile.isActive) {
        await _blocker.deactivateProfile(profile.id);
      } else {
        await _blocker.activateProfile(profile.id);
      }
      await _loadProfiles();
    } catch (e) {
      _showError('Failed to toggle profile: $e');
    }
  }

  Future<void> _deleteProfile(String profileId) async {
    try {
      await _blocker.deleteProfile(profileId);
      await _loadProfiles();
    } catch (e) {
      _showError('Failed to delete profile: $e');
    }
  }

  Future<void> _createProfile() async {
    final result = await showDialog<BlockProfile>(
      context: context,
      builder: (context) => const _CreateProfileDialog(),
    );

    if (result != null) {
      try {
        await _blocker.createProfile(result);
        await _loadProfiles();
      } catch (e) {
        _showError('Failed to create profile: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProfile,
        child: const Icon(Icons.add),
      ),
      body: _profiles.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No profiles yet'),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create a profile',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _profiles.length,
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                return Dismissible(
                  key: ValueKey(profile.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Profile'),
                        content: Text(
                          'Delete "${profile.name}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => _deleteProfile(profile.id),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: profile.isActive
                            ? Colors.green
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        child: Icon(
                          Icons.person,
                          color: profile.isActive
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      title: Text(profile.name),
                      subtitle: Text(
                        '${profile.appIdentifiers.length} app(s)'
                        '${profile.schedules.isNotEmpty ? ' | ${profile.schedules.length} schedule(s)' : ''}',
                      ),
                      trailing: Switch(
                        value: profile.isActive,
                        onChanged: (_) => _toggleProfile(profile),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog();

  @override
  State<_CreateProfileDialog> createState() => _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Profile'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Profile Name',
          hintText: 'e.g., Work Mode',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            final profile = BlockProfile(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              appIdentifiers: const [],
            );
            Navigator.pop(context, profile);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// =============================================================================
// Tab 4: Events
// =============================================================================

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final _blocker = AppBlocker.instance;
  final List<BlockEvent> _events = [];
  StreamSubscription<BlockEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _blocker.onBlockEvent.listen(
      (event) {
        setState(() {
          _events.insert(0, event);
          // Keep only the latest 100 events
          if (_events.length > 100) {
            _events.removeRange(100, _events.length);
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event stream error: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  IconData _iconForEventType(BlockEventType type) {
    return switch (type) {
      BlockEventType.blocked => Icons.block,
      BlockEventType.unblocked => Icons.lock_open,
      BlockEventType.attemptedAccess => Icons.warning_amber,
      BlockEventType.scheduleActivated => Icons.schedule,
      BlockEventType.scheduleDeactivated => Icons.schedule_outlined,
    };
  }

  Color _colorForEventType(BlockEventType type) {
    return switch (type) {
      BlockEventType.blocked => Colors.red,
      BlockEventType.unblocked => Colors.green,
      BlockEventType.attemptedAccess => Colors.orange,
      BlockEventType.scheduleActivated => Colors.blue,
      BlockEventType.scheduleDeactivated => Colors.grey,
    };
  }

  String _formatTimestamp(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          if (_events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear events',
              onPressed: () => setState(() => _events.clear()),
            ),
        ],
      ),
      body: _events.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stream, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No events yet'),
                  SizedBox(height: 8),
                  Text(
                    'Listening for block events...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      _iconForEventType(event.type),
                      color: _colorForEventType(event.type),
                    ),
                    title: Text(event.type.name),
                    subtitle: Text(
                      [
                        if (event.packageName != null) event.packageName!,
                        if (event.scheduleId != null)
                          'schedule: ${event.scheduleId}',
                      ].join(' | '),
                    ),
                    trailing: Text(
                      _formatTimestamp(event.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
