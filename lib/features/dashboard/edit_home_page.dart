// File: lib/features/dashboard/edit_home_page.dart
// Editor: live vPin locks during all edits and reliable settings opening.
// - Rebuilds VpinRegistry after any change (add/edit/remove/drag/resize/save).
// - Includes proper import for showWidgetSettingsSheet to avoid red-underline.

import 'package:flutter/material.dart';

import '../../services/storage_service.dart';
import '../../services/mqtt_service.dart';
import '../../services/vpin_registry.dart';
import '../devices/device_registry.dart';

import 'models.dart';
import 'editor_canvas.dart';
import 'widget_gallery_panel.dart';
import 'widgets_gallery.dart' as wg;
import 'widget_settings_sheet.dart';

class EditHomePage extends StatefulWidget {
  const EditHomePage({super.key});
  @override
  State<EditHomePage> createState() => _EditHomePageState();
}

class _EditHomePageState extends State<EditHomePage> {
  List<DashPageModel> pages = [];

  @override
  void initState() {
    super.initState();
    VpinRegistry.I.start(); // bootstrap locks
    _loadPages();
  }

  Future<void> _loadPages() async {
    pages = await StorageService.loadPages();
    VpinRegistry.I.rebuildFromPages(pages);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    await StorageService.savePages(pages);
    VpinRegistry.I.rebuildFromPages(pages);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved pages & layout')));
    Navigator.pop(context, true);
  }

  void _addPage() {
    final idx = pages.length + 1;
    setState(() {
      pages.add(DashPageModel(id: 'page$idx', title: 'Page $idx', items: []));
      VpinRegistry.I.rebuildFromPages(pages);
    });
  }

  void _deleteCurrent(int tabIndex) {
    if (pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least one page required')));
      return;
    }
    setState(() {
      pages.removeAt(tabIndex);
      VpinRegistry.I.rebuildFromPages(pages);
    });
  }

  Future<void> _renameCurrent(int tabIndex) async {
    final ctrl = TextEditingController(text: pages[tabIndex].title);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Page'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Title')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() => pages[tabIndex].title = name);
    }
  }

  String? _scopeTopic(String? t, String? device) {
    if (t == null) return null;
    if (device == null || device.isEmpty) return t;
    return t.replaceAll('{device}', device);
  }

  @override
  Widget build(BuildContext context) {
    final device = DeviceRegistry.I.selected.value;
    final int length = pages.isEmpty ? 1 : pages.length;

    return DefaultTabController(
      key: ValueKey('edit_tabs_len_$length'),
      length: length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Home'),
          bottom: pages.isNotEmpty
              ? TabBar(
                  isScrollable: true,
                  tabs: [for (final p in pages) Tab(text: p.title)])
              : null,
          actions: [
            IconButton(
                tooltip: 'Add Page',
                icon: const Icon(Icons.tab),
                onPressed: _addPage),
            Builder(
              builder: (context) {
                return PopupMenuButton<String>(
                  onSelected: (v) {
                    final controller = DefaultTabController.of(context);
                    final idx = controller.index;
                    if (v == 'rename') _renameCurrent(idx);
                    if (v == 'delete') _deleteCurrent(idx);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename Page')),
                    PopupMenuItem(value: 'delete', child: Text('Delete Page')),
                  ],
                );
              },
            ),
            IconButton(
                tooltip: 'Save',
                icon: const Icon(Icons.save),
                onPressed: _save),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton.extended(
              onPressed: () async {
                final controller = DefaultTabController.of(context);
                final idx = controller.index
                    .clamp(0, pages.isEmpty ? 0 : pages.length - 1);
                await showWidgetGallery(context, (w) {
                  setState(() => pages[idx].items.add(w));
                  VpinRegistry.I.rebuildFromPages(pages);
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Widget'),
            );
          },
        ),
        body: pages.isEmpty
            ? const Center(child: Text('Add a page to start'))
            : TabBarView(
                children: pages.map((p) {
                  return LayoutBuilder(builder: (context, box) {
                    Widget builder(BuildContext ctx, DashWidget dw) {
                      final show = dw.copyWith(
                        readTopic: _scopeTopic(dw.readTopic, device),
                        writeTopic: _scopeTopic(dw.writeTopic, device),
                      );
                      return wg.buildWidgetCard(
                        ctx,
                        show,
                        MqttService.I,
                        editable: true,
                        onEdit: () {
                          showWidgetSettingsSheet(ctx, show, onApplied: (upd) {
                            final i = p.items.indexWhere((x) => x.id == upd.id);
                            if (i != -1) {
                              setState(() => p.items[i] = upd);
                              VpinRegistry.I.rebuildFromPages(pages);
                            }
                          });
                        },
                      );
                    }

                    return EditorCanvas(
                      size: Size(box.maxWidth, box.maxHeight),
                      items: p.items,
                      onChanged: (_) {
                        setState(() {});
                        VpinRegistry.I.rebuildFromPages(pages);
                      },
                      widgetBuilder: builder,
                      editable: true,
                    );
                  });
                }).toList(),
              ),
      ),
    );
  }
}
