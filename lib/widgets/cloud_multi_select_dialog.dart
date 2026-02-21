import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:altyazi_editoru/app_settings.dart';

class CloudMultiSelectDialog<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function() loadFiles;
  final String Function(T) getName;
  final int? Function(T) getSize;
  final DateTime? Function(T) getDate;
  final bool Function(T)? filter;

  const CloudMultiSelectDialog({
    super.key,
    required this.title,
    required this.loadFiles,
    required this.getName,
    required this.getSize,
    required this.getDate,
    this.filter,
  });

  @override
  State<CloudMultiSelectDialog<T>> createState() => _CloudMultiSelectDialogState<T>();
}

class _CloudMultiSelectDialogState<T> extends State<CloudMultiSelectDialog<T>> {
  List<T>? _files;
  final Set<T> _selected = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.loadFiles();
      if (mounted) {
        setState(() {
          _files = widget.filter != null 
              ? list.where(widget.filter!).toList() 
              : list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final trans = context.read<AppSettings>().trans;
    final errorTemplate = trans['error_with_details'] ?? 'Error: {error}';

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      errorTemplate.replaceAll('{error}', _error ?? ''),
                    ),
                  )
                : _files == null || _files!.isEmpty
                    ? Center(
                        child: Text(
                          trans['cloud_no_files_found'] ?? 'No files found.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _files!.length,
                        itemBuilder: (context, index) {
                          final file = _files![index];
                          final isSelected = _selected.contains(file);
                          return CheckboxListTile(
                            title: Text(widget.getName(file)),
                            subtitle: Text('${_formatSize(widget.getSize(file))} • ${widget.getDate(file)?.toString().split(' ')[0] ?? ''}'),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selected.add(file);
                                } else {
                                  _selected.remove(file);
                                }
                              });
                            },
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            trans['btn_cancel'] ?? trans['cancel'] ?? 'Cancel',
          ),
        ),
        ElevatedButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          child: Text(
            '${trans['select'] ?? 'Select'} (${_selected.length})',
          ),
        ),
      ],
    );
  }
}
