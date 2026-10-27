import 'package:flutter/material.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'theme.dart';

class FileExplorerSheet extends StatefulWidget {
  final void Function(String path, String label, bool isDir) onSelectPath;
  const FileExplorerSheet({required this.onSelectPath, super.key});

  @override
  State<FileExplorerSheet> createState() => _FileExplorerSheetState();
}

class _FileExplorerSheetState extends State<FileExplorerSheet> {
  String _currentPath = '/storage/emulated/0';
  List<FsEntryItem> _entries = [];
  bool _loading = true;
  String _filter = '';

  static const List<(String, String)> _quickDirs = [
    ('Память', '/storage/emulated/0'),
    ('Download', '/storage/emulated/0/Download'),
    ('DCIM', '/storage/emulated/0/DCIM'),
    ('Documents', '/storage/emulated/0/Documents'),
    ('Pictures', '/storage/emulated/0/Pictures'),
    ('Root /data', '/data/data'),
  ];

  @override
  void initState() {
    super.initState();
    _loadDir(_currentPath);
  }

  Future<void> _loadDir(String path) async {
    setState(() {
      _loading = true;
      _currentPath = path;
    });
    final list = await NativeBridge.listDirectory(path);
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  void _goUp() {
    if (_currentPath == '/' || _currentPath.isEmpty) return;
    final idx = _currentPath.lastIndexOf('/');
    final parent = idx <= 0 ? '/' : _currentPath.substring(0, idx);
    _loadDir(parent);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where((e) {
      if (_filter.trim().isEmpty) return true;
      return e.name.toLowerCase().contains(_filter.trim().toLowerCase());
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.84,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_special_rounded, color: C.jd, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Файловый менеджер (Root & Storage)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: C.tx2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final q in _quickDirs)
                      PeriodPill(
                        q.$1,
                        _currentPath == q.$2,
                        () => _loadDir(q.$2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final p = await NativeBridge.pickSystemFile();
                        if (p != null && p.isNotEmpty && context.mounted) {
                          final parts = p.split('/').where((s) => s.isNotEmpty).toList();
                          widget.onSelectPath(p, parts.isNotEmpty ? parts.last : p, false);
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.file_open_rounded, size: 16, color: C.pk),
                      label: const Text('Системный файл', style: TextStyle(color: C.tx, fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: C.line),
                        backgroundColor: C.s2,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final p = await NativeBridge.pickSystemFolder();
                        if (p != null && p.isNotEmpty && context.mounted) {
                          final parts = p.split('/').where((s) => s.isNotEmpty).toList();
                          widget.onSelectPath(p, parts.isNotEmpty ? parts.last : p, true);
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.create_new_folder_rounded, size: 16, color: C.jd),
                      label: const Text('Системная папка', style: TextStyle(color: C.tx, fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: C.line),
                        backgroundColor: C.s2,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: C.bg,
                  border: Border.all(color: C.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _goUp,
                      icon: const Icon(Icons.arrow_upward_rounded, color: C.jd, size: 18),
                      tooltip: 'На уровень вверх',
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _currentPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: C.tx,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        final parts = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
                        final name = parts.isNotEmpty ? parts.last : _currentPath;
                        widget.onSelectPath(_currentPath, 'Папка: $name', true);
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: C.jd,
                        foregroundColor: C.bg,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text(
                        'Выбрать эту папку',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setState(() => _filter = v),
                style: const TextStyle(color: C.tx, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Фильтр файлов и папок в текущем каталоге…',
                  hintStyle: const TextStyle(color: C.tx2, fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: C.tx2, size: 18),
                  filled: true,
                  fillColor: C.s2,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: C.jd),
                        ),
                      )
                    : visible.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text(
                                'Папка пуста или нет файлов по фильтру',
                                style: TextStyle(color: C.tx2),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => const Divider(color: C.line, height: 1),
                            itemBuilder: (_, i) {
                              final item = visible[i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                leading: Icon(
                                  item.isDir
                                      ? Icons.folder_rounded
                                      : Icons.insert_drive_file_rounded,
                                  color: item.isDir ? C.gd : C.jd,
                                  size: 22,
                                ),
                                title: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: C.tx,
                                  ),
                                ),
                                subtitle: Text(
                                  item.isDir
                                      ? 'Папка · Нажмите чтобы открыть'
                                      : '${fmtBytes(item.sizeBytes)} · ${item.path}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: C.tx2, fontSize: 11.5),
                                ),
                                onTap: () {
                                  if (item.isDir) {
                                    _loadDir(item.path);
                                  } else {
                                    widget.onSelectPath(item.path, item.name, false);
                                    Navigator.of(context).pop();
                                  }
                                },
                                trailing: IconButton(
                                  onPressed: () {
                                    widget.onSelectPath(
                                      item.path,
                                      item.isDir ? 'Папка: ${item.name}' : item.name,
                                      item.isDir,
                                    );
                                    Navigator.of(context).pop();
                                  },
                                  icon: const Icon(Icons.add_circle_rounded, color: C.pk, size: 22),
                                  tooltip: 'Добавить в автоудаление',
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
