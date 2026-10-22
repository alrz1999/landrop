import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import 'app_controller.dart';
import 'format.dart';
import 'l10n.dart';
import 'ltr_text.dart';
import 'widgets.dart' show AppScope;

// Nearby shares (docs/NEARBY_PLAN.md section 4): what a trusted device
// offers to this one (a section of the Details sheet) and the owner's
// "allow this device to see my shares?" dialog.

/// True for a device that can list nearby shares: a LanDrop app (it sent a
/// capability record) with a verified fingerprint, never a browser.
bool offersNearby(DeviceInfo peer) =>
    peer.fingerprint.isNotEmpty &&
    peer.capabilities != null &&
    peer.deviceType != 'web';

typedef _Pick = (String shareId, String fileId);

/// "Nearby shares" in the Details sheet. Asks the device when it opens (a
/// spinner meanwhile); no polling, only the Refresh button asks again.
class NearbySharesSection extends StatefulWidget {
  const NearbySharesSection({super.key, required this.peer});
  final DeviceInfo peer;

  @override
  State<NearbySharesSection> createState() => _NearbySharesSectionState();
}

class _NearbySharesSectionState extends State<NearbySharesSection> {
  NearbyListing? _listing;
  bool _loading = true;
  bool _busy = false; // a download is starting
  int _seq = 0;
  final Set<_Pick> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<NearbyListing?> _load() async {
    if (!mounted) return null;
    final seq = ++_seq;
    setState(() => _loading = true);
    final listing = await AppScope.read(context).listNearby(widget.peer);
    if (!mounted || seq != _seq) return null;
    setState(() {
      _listing = listing;
      _loading = false;
      _selected.removeWhere((p) => !_has(listing, p));
    });
    return listing;
  }

  static bool _has(NearbyListing l, _Pick p) => l.shares.any(
      (s) => s.id == p.$1 && s.files.any((f) => f.id == p.$2));

  Iterable<_Pick> get _all => [
        for (final s in _listing?.shares ?? const <NearbyShare>[])
          for (final f in s.files) (s.id, f.id)
      ];

  Future<void> _download() async {
    if (_busy || _selected.isEmpty) return;
    final c = AppScope.read(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    var listing = _listing!;
    // The ticket only lives a few minutes: ask again first when it ended.
    final until = listing.ticketExpires;
    if (until != null && !DateTime.now().isBefore(until)) {
      final fresh = await _load();
      if (!mounted) return;
      if (fresh == null) {
        setState(() => _busy = false);
        return;
      }
      listing = fresh;
    }
    final items = [
      for (final p in _all)
        if (_selected.contains(p)) p
    ];
    setState(() => _busy = false);
    if (items.isEmpty) return;
    // Progress shows in the transfer cards on Home: close the sheet.
    unawaited(c.downloadNearby(widget.peer, listing, items));
    if (nav.canPop()) nav.pop();
  }

  void _toggleAll(bool on) => setState(() {
        _selected.clear();
        if (on) _selected.addAll(_all);
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final listing = _listing;
    final shares = listing?.shares ?? const <NearbyShare>[];
    final total = _all.length;
    Widget body;
    if (_loading && listing == null) {
      body = Semantics(
        label: l.nearbyLoading,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
          child: Row(children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    key: Key('nearbySpinner'), strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text(l.nearbyLoading, style: t.bodyMedium)),
          ]),
        ),
      );
    } else if (shares.isEmpty) {
      body = Column(
        key: const Key('nearbyEmpty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.nearbyEmpty, style: t.bodyMedium),
          const SizedBox(height: 2),
          Text(l.nearbyEmptyHint, style: t.bodySmall),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: const Key('nearbySelectAll'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _selected.length == total,
            onChanged: (v) => _toggleAll(v ?? false),
            title: Text(l.nearbySelectAll),
          ),
          for (final s in shares) _shareTile(l, s),
          if (shares.any((s) => s.truncated))
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4),
              child: Text(l.nearbyTruncated,
                  key: const Key('nearbyTruncated'), style: t.bodySmall),
            ),
        ],
      );
    }
    return Semantics(
      container: true,
      label: l.nearbySharesTitle,
      child: Padding(
        key: const Key('nearbySection'),
        padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.nearbySharesTitle, style: t.titleSmall),
            const SizedBox(height: 4),
            body,
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (shares.isNotEmpty)
                FilledButton(
                  key: const Key('nearbyDownload'),
                  onPressed: _selected.isEmpty || _busy ? null : _download,
                  child: Text(l.nearbyDownloadSelected(_selected.length)),
                ),
              TextButton.icon(
                key: const Key('nearbyRefresh'),
                onPressed: _loading || _busy ? null : _load,
                icon: _loading && listing != null
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(l.nearbyRefresh),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _shareTile(AppLocalizations l, NearbyShare s) {
    final bytes = s.files.fold<int>(0, (a, f) => a + f.size);
    return ExpansionTile(
      key: Key('nearbyShare-${s.id}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: (_listing?.shares.length ?? 0) == 1,
      title: s.files.length == 1
          ? AutoDirText(s.files.first.name,
              fileName: true,
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : Text(l.fileCount(s.files.length)),
      subtitle: Text(formatBytes(bytes, l)),
      children: [
        for (final f in s.files)
          CheckboxListTile(
            key: Key('nearbyFile-${s.id}-${f.id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _selected.contains((s.id, f.id)),
            onChanged: (v) => setState(() {
              if (v ?? false) {
                _selected.add((s.id, f.id));
              } else {
                _selected.remove((s.id, f.id));
              }
            }),
            title: AutoDirText(f.name,
                fileName: true, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(formatBytes(f.size, l)),
          ),
      ],
    );
  }
}

/// The owner's question: may this device see my nearby shares? Answers the
/// controller itself and closes by itself when the request is answered
/// elsewhere or the core stopped waiting (it drops a prompt after 60 s).
Future<void> showNearbyAccessDialog(
    BuildContext context, AppController c, NearbyAccessRequest r) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NearbyAccessDialog(c, r),
  );
}

class _NearbyAccessDialog extends StatefulWidget {
  const _NearbyAccessDialog(this.controller, this.request);
  final AppController controller;
  final NearbyAccessRequest request;
  @override
  State<_NearbyAccessDialog> createState() => _NearbyAccessDialogState();
}

class _NearbyAccessDialogState extends State<_NearbyAccessDialog> {
  static const _lifetime = Duration(seconds: 60);
  bool _closed = false;
  Timer? _expiry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
    var left = _lifetime - DateTime.now().difference(widget.request.at);
    if (left > _lifetime) left = _lifetime;
    if (left.isNegative) left = Duration.zero;
    _expiry = Timer(left, () {
      // Late answers are ignored by the core; this drops the entry here.
      widget.controller
          .answerNearbyRequest(widget.request.id, NearbyDecision.deny);
      _close();
    });
  }

  void _check() {
    if (widget.controller.pendingNearbyRequest?.id != widget.request.id) {
      _close();
    }
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.pop(context);
  }

  void _answer(NearbyDecision d) {
    if (_closed) return;
    widget.controller.answerNearbyRequest(widget.request.id, d);
    _close();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    widget.controller.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final r = widget.request;
    final code = (r.fingerprint.length > 8
            ? r.fingerprint.substring(0, 8)
            : r.fingerprint)
        .toUpperCase();
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('nearbyAccessDialog'),
        icon: const Icon(Icons.folder_shared_outlined),
        title: Text(l.nearbyAccessTitle(
            l.isoName(r.alias.isEmpty ? code : r.alias))),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.securityCode, style: t.labelMedium),
              const SizedBox(height: 2),
              LtrText(code, key: const Key('nearbyAccessFingerprint')),
            ],
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            key: const Key('nearbyAccessDeny'),
            onPressed: () => _answer(NearbyDecision.deny),
            child: Text(l.nearbyAccessDeny),
          ),
          TextButton(
            key: const Key('nearbyAccessOnce'),
            onPressed: () => _answer(NearbyDecision.allowOnce),
            child: Text(l.nearbyAccessOnce),
          ),
          FilledButton(
            key: const Key('nearbyAccessAlways'),
            onPressed: () => _answer(NearbyDecision.alwaysAllow),
            child: Text(l.nearbyAccessAlways),
          ),
        ],
      ),
    );
  }
}
