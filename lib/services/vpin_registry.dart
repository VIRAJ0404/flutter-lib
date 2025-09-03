// lib/services/vpin_registry.dart
// vPin registry for locks plus dashboard "pin usage" utilities expected by the UI.
// Adds start(), rebuildFromPages(...), reserve(oldPin:, newPin:), isUsed(...),
// getters allPins (List<String>) and usedPins (ValueListenable<Set<String>>) to satisfy UI.

import 'dart:convert';
import 'package:flutter/foundation.dart';

class VPinLock {
  final String vpinId;
  final bool locked;
  final String? owner;
  final DateTime? expiresAt;
  final DateTime updatedAt;

  VPinLock({
    required this.vpinId,
    required this.locked,
    this.owner,
    this.expiresAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  VPinLock copyWith({
    bool? locked,
    String? owner,
    DateTime? expiresAt,
    DateTime? updatedAt,
  }) {
    return VPinLock(
      vpinId: vpinId,
      locked: locked ?? this.locked,
      owner: owner ?? this.owner,
      expiresAt: expiresAt ?? this.expiresAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'vpinId': vpinId,
        'locked': locked,
        'owner': owner,
        'expiresAt': expiresAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static VPinLock fromJson(Map<String, dynamic> json) {
    return VPinLock(
      vpinId: json['vpinId'] as String,
      locked: json['locked'] as bool? ?? false,
      owner: json['owner'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt']) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

// Match expected name in UI (case pattern seen): VpinRegistry
class VpinRegistry {
  // Optional singleton for convenient access
  static final VpinRegistry I = VpinRegistry();

  // vpinId -> lock
  final Map<String, VPinLock> _locks = {};

  // Sets tracking pin usage in dashboard/editor
  final Set<String> _allPins = <String>{};
  final Set<String> _reservedPins = <String>{};

  // Value listenables for UI expecting ValueListenable<Set<String>>
  final ValueNotifier<Set<String>> _usedPinsVN =
      ValueNotifier<Set<String>>(<String>{});

  // Locks API
  List<VPinLock> get all => _locks.values.toList(growable: false);

  VPinLock? get(String vpinId) => _locks[vpinId];

  bool isLocked(String vpinId) => _locks[vpinId]?.locked ?? false;

  void setLock(String vpinId,
      {required bool locked, String? owner, DateTime? expiresAt}) {
    final existing = _locks[vpinId];
    final next = (existing ??
            VPinLock(
              vpinId: vpinId,
              locked: locked,
              owner: owner,
              expiresAt: expiresAt,
            ))
        .copyWith(
            locked: locked,
            owner: owner,
            expiresAt: expiresAt,
            updatedAt: DateTime.now());
    _locks[vpinId] = next;
  }

  // Apply inbound lock message payloads: supports JSON and primitive payloads.
  void applyLockMessage(String vpinId, String payload) {
    try {
      final data = json.decode(payload);
      if (data is Map<String, dynamic>) {
        setLock(
          vpinId,
          locked: (data['locked'] as bool?) ?? isLocked(vpinId),
          owner: data['owner'] as String?,
          expiresAt: data['expiresAt'] != null
              ? DateTime.tryParse(data['expiresAt'])
              : null,
        );
        return;
      }
    } catch (_) {
      // fallthrough for non-JSON
    }

    final p = payload.trim().toLowerCase();
    if (p == '1' || p == 'true' || p == 'lock' || p == 'locked') {
      setLock(vpinId, locked: true);
    } else if (p == '0' || p == 'false' || p == 'unlock' || p == 'unlocked') {
      setLock(vpinId, locked: false);
    }
  }

  // Dashboard/editor API expected by UI

  // Kick off any background tracking as needed (stub for compatibility)
  void start() {
    // No-op: place for wiring timers/refresh if needed.
  }

  // Rebuild used pins from provided "pages" structure (dynamic to accept various models)
  void rebuildFromPages(dynamic pages) {
    final found = _extractPinsFromPages(pages);
    _allPins
      ..clear()
      ..addAll(found);
    // used = union(found, reserved)
    final used = <String>{}
      ..addAll(found)
      ..addAll(_reservedPins);
    _usedPinsVN.value = used;
  }

  // Reserve change: Some UIs call reserve(oldPin: ..., newPin: ...)
  void reserve({String? oldPin, String? newPin}) {
    if (oldPin != null && oldPin.isNotEmpty) {
      _reservedPins.remove(oldPin);
    }
    if (newPin != null && newPin.isNotEmpty) {
      _reservedPins.add(newPin);
      _allPins.add(newPin);
    }
    final used = <String>{}
      ..addAll(_usedPinsVN.value)
      ..addAll(_reservedPins);
    _usedPinsVN.value = used;
  }

  // Back-compat convenience if any code passes a single pin (not used by current errors)
  void reserveSingle(String vpinId) {
    reserve(newPin: vpinId);
  }

  bool isUsed(String vpinId) => _usedPinsVN.value.contains(vpinId);

  // Some code expects List<String>, others expect ValueListenable<Set<String>>
  List<String> get allPins => _allPins.toList()..sort();

  ValueListenable<Set<String>> get usedPins => _usedPinsVN;

  List<String> get usedPinsList => _usedPinsVN.value.toList()..sort();

  // Heuristic extraction of pin IDs from arbitrary page/widget models.
  // Looks for fields like 'vpinId' or string topics like 'vpin/{id}/state' etc.
  Set<String> _extractPinsFromPages(dynamic root) {
    final out = <String>{};

    void walk(dynamic node) {
      if (node == null) return;

      if (node is Map) {
        final keys = node.keys.map((e) => e.toString()).toList();
        if (keys.contains('vpinId')) {
          final id = node['vpinId'];
          if (id is String && id.isNotEmpty) out.add(id);
        }
        for (final v in node.values) {
          walk(v);
        }
        return;
      }

      if (node is Iterable) {
        for (final v in node) {
          walk(v);
        }
        return;
      }

      if (node is String) {
        final s = node;
        final idx = s.indexOf('vpin/');
        if (idx >= 0) {
          final cut = s.substring(idx + 5); // after 'vpin/'
          final slash = cut.indexOf('/');
          final id = slash >= 0 ? cut.substring(0, slash) : cut;
          if (id.isNotEmpty) out.add(id);
        }
      }
    }

    walk(root);
    return out;
  }
}
