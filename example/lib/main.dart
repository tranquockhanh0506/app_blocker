import 'dart:io';
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
  final _blocker = AppBlocker.instance;

  BlockerPermissionStatus? _permissionStatus;
  List<AppInfo> _apps = [];
  final Set<String> _selectedApps = {};
  bool _loadingApps = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
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
    if (Platform.isIOS) {
      // iOS: FamilyActivityPicker handles selection & blocking in one step
      setState(() => _loadingApps = true);
      try {
        await _blocker.getApps();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Apps blocked via Screen Time')),
          );
        }
      } catch (e) {
        _showError('Failed to select apps: $e');
      } finally {
        setState(() => _loadingApps = false);
      }
      return;
    }

    // Android: get apps list, then show bottom sheet to pick
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${_selectedApps.length} app(s) blocked')),
        );
        setState(() => _selectedApps.clear());
      }
    } catch (e) {
      _showError('Failed to block apps: $e');
    }
  }

  Future<void> _blockAll() async {
    try {
      await _blocker.blockAll();
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
      appBar: AppBar(title: const Text('App Blocker Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Permission
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
                        color: _permissionStatus ==
                                BlockerPermissionStatus.granted
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
                        child: const Text('Check Permission'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _requestPermission,
                        child: const Text('Request Permission'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Select & Block
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
                                  strokeWidth: 2),
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
                            'Block ${_selectedApps.length} App(s)'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// App Picker Bottom Sheet
// =============================================================================

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
                  color:
                      isSelected ? colorScheme.primary : colorScheme.outline,
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
