import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One finished transfer in the history (UX.md 6, "History"). Kept only on
/// this device; a text message keeps no text, only that it was one.
class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.incoming,
    required this.peerAlias,
    required this.fileNames,
    required this.fileCount,
    required this.totalBytes,
    required this.state,
    required this.at,
    this.savedPath,
    this.text = false,
  });

  /// Unique within the history (stable across restarts).
  final String id;
  final bool incoming;
  final String peerAlias;

  /// The first [HistoryStore.maxNames] file names (relative paths with
  /// '/' for folders); [fileCount] has the real number.
  final List<String> fileNames;
  final int fileCount;
  final int totalBytes;

  /// `TransferState.name`: done, declined, cancelled or failed.
  final String state;
  final DateTime at;

  /// Received: the file, or the folder holding the files.
  final String? savedPath;

  /// A text message (PROTOCOL.md "Text messages").
  final bool text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'incoming': incoming,
        'peer': peerAlias,
        'files': fileNames,
        'count': fileCount,
        'bytes': totalBytes,
        'state': state,
        'at': at.toUtc().toIso8601String(),
        'savedPath': ?savedPath,
        if (text) 'text': true,
      };

  /// Tolerant parser; null when [j] is not an entry.
  static HistoryEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], peer = j['peer'], at = j['at'], state = j['state'];
    if (id is! String || peer is! String || at is! String || state is! String) {
      return null;
    }
    final when = DateTime.tryParse(at);
    if (when == null) return null;
    final files = j['files'];
    final names =
        files is List ? files.whereType<String>().toList() : <String>[];
    final count = j['count'], bytes = j['bytes'], saved = j['savedPath'];
    return HistoryEntry(
      id: id,
      incoming: j['incoming'] == true,
      peerAlias: peer,
      fileNames: names,
      fileCount: count is int ? count : names.length,
      totalBytes: bytes is int ? bytes : 0,
      state: state,
      at: when.toLocal(),
      savedPath: saved is String ? saved : null,
      text: j['text'] == true,
    );
  }
}

/// Persists the transfer history as JSON next to the settings file
/// (`landrop_history.json` in the application support directory).
class HistoryStore {
  const HistoryStore();

  /// Entries kept (newest first); older ones are dropped.
  static const maxEntries = 100;

  /// File names kept per entry.
  static const maxNames = 50;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}landrop_history.json');
  }

  Future<List<HistoryEntry>> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString());
        if (j is Map && j['entries'] is List) {
          return [
            for (final e in j['entries'] as List)
              ?HistoryEntry.fromJson(e)
          ];
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> save(List<HistoryEntry> entries) async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({
        'v': 1,
        'entries': [for (final e in entries) e.toJson()],
      }));
    } catch (_) {}
  }

  /// Deletes the stored history.
  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// Non-persistent history (tests), as JSON like the real file.
class MemoryHistoryStore extends HistoryStore {
  MemoryHistoryStore([List<Map<String, dynamic>>? initial])
      : stored = initial == null ? null : [...initial];

  /// What [save] wrote (null after [clear] or before any save).
  List<Map<String, dynamic>>? stored;
  int clears = 0;

  @override
  Future<List<HistoryEntry>> load() async =>
      [for (final e in stored ?? const []) ?HistoryEntry.fromJson(e)];

  @override
  Future<void> save(List<HistoryEntry> entries) async =>
      stored = [for (final e in entries) e.toJson()];

  @override
  Future<void> clear() async {
    stored = null;
    clears++;
  }
}
