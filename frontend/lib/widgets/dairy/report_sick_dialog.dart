import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

/// "Report Sick Animal" dialog. Mirrors the v4.5 mockup, but every
/// free-text picker is now data-backed:
///
///   * Unit *               — gated by the signed-in user's role.
///   * Animal *             — autocomplete over the *real* animals
///                            in the selected unit (cows for Dairy,
///                            sows+boars for Piggery, bulls for
///                            Feedlot, sheep for Doopers, layer
///                            houses for Layers).
///   * Severity *           — UI-only; encoded in `notes` until the
///                            schema grows a column.
///   * Reported by *        — dropdown of managers/supervisors for
///                            the selected unit (CEO + VET + that
///                            unit's manager), with the signed-in
///                            user preselected when they're eligible.
///   * Symptoms *           — free-text textarea (unchanged).
///   * Onset                — date (unchanged).
///
/// RBAC is enforced on three layers:
///   1. Backend route gate admits CEO / VET / ADMIN + *_MANAGER roles.
///   2. Backend controller checks the body.unit against the role's
///      allowed unit list (UNIT_OWNERSHIP) and 403s otherwise.
///   3. This dialog hides units the user can't report against so the
///      403 path is just a safety net, not the everyday UX.
///
/// Submits to POST /api/health/treatments — `medication` is the
/// sentinel "Pending vet review" so the vet PATCHes the real drug
/// once they triage. The treatment row carries severity in `notes`
/// (`[SEVERE] reported by Dr. Mwirigi`) so the queue list still
/// surfaces it at a glance.
class ReportSickDialog extends StatefulWidget {
  const ReportSickDialog({
    super.key,
    this.defaultUnit = 'Dairy',
    this.tagSuggestion,
  });

  /// Initial unit value — caller usually passes the current section
  /// (e.g. dairy page passes 'Dairy', layers page 'Layers'). If the
  /// caller's hint isn't in the *allowed* unit set for the signed-in
  /// user, we fall back to the first allowed unit.
  final String defaultUnit;

  /// Pre-fills the animal field (e.g. when launching from a row
  /// action on a specific cow). The match is by tag string; if it
  /// resolves to a real animal we lock the picker to it.
  final String? tagSuggestion;

  @override
  State<ReportSickDialog> createState() => _ReportSickDialogState();
}

/// Backend HealthUnit enum.
const _allUnits = ['Dairy', 'Layers', 'Piggery', 'Doopers', 'Feedlot'];

/// Mirrors UNIT_OWNERSHIP on the server (health.controller.js). The
/// keys are SCREAMING_SNAKE_CASE because that's what the JWT stores;
/// any role not in this map can report against any unit (CEO, VET,
/// ADMIN). FEEDLOT_MANAGER owns both bulls and sheep so the unit
/// covers Feedlot + Doopers.
const _unitOwnership = <String, List<String>>{
  'DAIRY_MANAGER': ['Dairy'],
  'PIGGERY_MANAGER': ['Piggery'],
  'LAYERS_MANAGER': ['Layers'],
  'FEEDLOT_MANAGER': ['Feedlot', 'Doopers'],
};

/// Roles that may appear in the "Reported by" dropdown for a given
/// unit. The unit's own manager is the obvious one; CEO and VET are
/// cross-unit so they're always eligible.
const _reporterRoles = <String, List<String>>{
  'Dairy':   ['DAIRY_MANAGER',   'CEO', 'VET'],
  'Piggery': ['PIGGERY_MANAGER', 'CEO', 'VET'],
  'Layers':  ['LAYERS_MANAGER',  'CEO', 'VET'],
  'Feedlot': ['FEEDLOT_MANAGER', 'CEO', 'VET'],
  'Doopers': ['FEEDLOT_MANAGER', 'CEO', 'VET'],
};

/// A picker option — every unit's animals get normalised to this so
/// the autocomplete builder doesn't have to branch on unit.
class _AnimalOption {
  const _AnimalOption({required this.tag, required this.label});
  final String tag;
  final String label;
}

class _ReporterOption {
  const _ReporterOption({required this.id, required this.label});
  final String id;
  final String label;
}

class _ReportSickDialogState extends State<ReportSickDialog> {
  static const _primary = Color(0xFF27500A);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _animalCtrl;
  late final TextEditingController _symptoms;

  // Severity is UI-only for now (no backend column). Encoded into
  // notes on submit. Three steps mirror the design mock.
  static const _severities = [
    ('MILD', '🟢 Mild — monitor only'),
    ('MODERATE', '🟡 Moderate — vet attention soon'),
    ('SEVERE', '🔴 Severe — urgent'),
  ];
  String _severity = 'MODERATE';

  String? _userRole;
  List<String> _allowedUnits = _allUnits;
  late String _unit;
  DateTime _onset = DateTime.now();
  bool _submitting = false;

  // Loaded state. Both keyed by unit so switching the dropdown
  // doesn't refetch what we've already seen.
  final Map<String, List<_AnimalOption>> _animalsByUnit = {};
  final Map<String, List<_ReporterOption>> _reportersByUnit = {};
  List<Map<String, dynamic>> _staffRaw = const [];
  bool _loadingAnimals = false;
  bool _loadingStaff = true;

  _AnimalOption? _selectedAnimal;
  _ReporterOption? _selectedReporter;

  @override
  void initState() {
    super.initState();
    _animalCtrl = TextEditingController();
    _symptoms = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _animalCtrl.dispose();
    _symptoms.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final role = await ApiService.readRole();
    final allowed = _unitOwnership[role] ?? _allUnits;
    final initial = allowed.contains(widget.defaultUnit)
        ? widget.defaultUnit
        : allowed.first;
    if (!mounted) return;
    setState(() {
      _userRole = role;
      _allowedUnits = allowed;
      _unit = initial;
    });
    // Kick off animal + staff loads in parallel.
    await Future.wait([_loadAnimalsFor(initial), _loadStaff()]);
    // Pre-fill animal if the caller hinted a tag and the load found it.
    final hint = widget.tagSuggestion?.trim();
    if (hint != null && hint.isNotEmpty) {
      final match = _animalsByUnit[initial]
          ?.where((a) => a.tag.toLowerCase() == hint.toLowerCase())
          .toList();
      if (match != null && match.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _selectedAnimal = match.first;
          _animalCtrl.text = match.first.tag;
        });
      } else {
        _animalCtrl.text = hint;
      }
    }
  }

  Future<void> _loadStaff() async {
    try {
      final raw = await ApiService.getStaffList();
      _staffRaw = raw
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    } catch (_) {
      _staffRaw = const [];
    }
    if (!mounted) return;
    // Recompute reporters for every unit we might switch to so the
    // dropdown is instant on change.
    for (final u in _allUnits) {
      _reportersByUnit[u] = _buildReporters(u);
    }
    setState(() {
      _loadingStaff = false;
      _selectedReporter ??= _defaultReporter(_unit);
    });
  }

  List<_ReporterOption> _buildReporters(String unit) {
    final allowedRoles = _reporterRoles[unit] ?? const [];
    final out = <_ReporterOption>[];
    for (final s in _staffRaw) {
      final role = (s['role'] ?? '').toString();
      if (!allowedRoles.contains(role)) continue;
      // CEO/VET appear in every unit; manager rows must belong to
      // the matching department to avoid e.g. a stale DAIRY_MANAGER
      // showing under Piggery.
      final dept = (s['department'] ?? '').toString();
      final isCrossUnit = role == 'CEO' || role == 'VET';
      if (!isCrossUnit && dept.isNotEmpty && dept != unit) continue;
      final id = (s['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final name = (s['fullName'] ?? s['userName'] ?? id).toString();
      final roleLabel = _humanRole(role);
      out.add(_ReporterOption(id: id, label: '$name · $roleLabel'));
    }
    // Stable order: VET first (clinical), then CEO, then unit
    // manager(s). Within a tier, alphabetical by name.
    out.sort((a, b) {
      int tier(_ReporterOption o) {
        if (o.label.contains('Vet')) return 0;
        if (o.label.contains('CEO')) return 1;
        return 2;
      }
      final t = tier(a) - tier(b);
      return t != 0 ? t : a.label.compareTo(b.label);
    });
    return out;
  }

  /// The "obvious" reporter for a unit when the dialog opens — the
  /// signed-in user if they're in the candidate list, else the first
  /// candidate. Null only when the unit has zero eligible reporters
  /// (a config error the form will then surface as a validator hit).
  _ReporterOption? _defaultReporter(String unit) {
    final list = _reportersByUnit[unit] ?? const <_ReporterOption>[];
    if (list.isEmpty) return null;
    // Best-effort match: the JWT user id isn't persisted next to the
    // role in this client, so we just fall back to first.
    return list.first;
  }

  String _humanRole(String wire) {
    switch (wire) {
      case 'CEO': return 'CEO';
      case 'VET': return 'Vet';
      case 'DAIRY_MANAGER': return 'Dairy Manager';
      case 'PIGGERY_MANAGER': return 'Piggery Manager';
      case 'LAYERS_MANAGER': return 'Layers Manager';
      case 'FEEDLOT_MANAGER': return 'Feedlot Manager';
      case 'ADMIN': return 'Admin';
      default: return wire;
    }
  }

  Future<void> _loadAnimalsFor(String unit) async {
    if (_animalsByUnit.containsKey(unit)) return; // cached
    setState(() => _loadingAnimals = true);
    try {
      final list = await _fetchAnimals(unit);
      _animalsByUnit[unit] = list;
    } catch (_) {
      _animalsByUnit[unit] = const [];
    }
    if (!mounted) return;
    setState(() => _loadingAnimals = false);
  }

  // Per-unit fetcher. Each branch maps the raw API row to the small
  // `_AnimalOption` shape the autocomplete needs (tag + display
  // label). Piggery merges sows and boars into one list.
  Future<List<_AnimalOption>> _fetchAnimals(String unit) async {
    switch (unit) {
      case 'Dairy':
        final rows = await ApiService.getCows();
        return rows
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((m) {
              final tag = (m['tag'] ?? '').toString();
              final nick = (m['nickname'] ?? '').toString();
              final label = nick.isEmpty ? tag : '$tag · $nick';
              return _AnimalOption(tag: tag, label: label);
            })
            .where((a) => a.tag.isNotEmpty)
            .toList();
      case 'Piggery':
        final results = await Future.wait([
          ApiService.getPiggerySows(),
          ApiService.getPiggeryBoars(),
        ]);
        final out = <_AnimalOption>[];
        for (final m in results[0].whereType<Map>()) {
          final j = m.cast<String, dynamic>();
          final tag = (j['tag'] ?? '').toString();
          final pen = (j['pen'] ?? '').toString();
          if (tag.isEmpty) continue;
          out.add(_AnimalOption(
            tag: tag,
            label: 'Sow $tag${pen.isEmpty ? '' : ' · Pen $pen'}',
          ));
        }
        for (final m in results[1].whereType<Map>()) {
          final j = m.cast<String, dynamic>();
          final tag = (j['tag'] ?? '').toString();
          final pen = (j['pen'] ?? '').toString();
          if (tag.isEmpty) continue;
          out.add(_AnimalOption(
            tag: tag,
            label: 'Boar $tag${pen.isEmpty ? '' : ' · Pen $pen'}',
          ));
        }
        return out;
      case 'Feedlot':
        final rows = await ApiService.getFeedlotBulls();
        return rows
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((m) {
              final tag = (m['tag'] ?? '').toString();
              final breed = (m['breed'] ?? '').toString();
              return _AnimalOption(
                tag: tag,
                label: breed.isEmpty ? tag : '$tag · $breed',
              );
            })
            .where((a) => a.tag.isNotEmpty)
            .toList();
      case 'Doopers':
        final rows = await ApiService.getFeedlotSheep();
        return rows
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((m) {
              final tag = (m['tag'] ?? '').toString();
              final cat = (m['category'] ?? '').toString();
              return _AnimalOption(
                tag: tag,
                label: cat.isEmpty ? tag : '$tag · $cat',
              );
            })
            .where((a) => a.tag.isNotEmpty)
            .toList();
      case 'Layers':
        // Layers are flock-managed — a "sick animal" report is filed
        // against the house, not a single bird.
        final rows = await ApiService.getLayersHouses();
        return rows
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((m) {
              final name = (m['name'] ?? '').toString();
              return _AnimalOption(tag: name, label: name);
            })
            .where((a) => a.tag.isNotEmpty)
            .toList();
      default:
        return const [];
    }
  }

  Future<void> _onUnitChanged(String? next) async {
    if (next == null || next == _unit) return;
    setState(() {
      _unit = next;
      _selectedAnimal = null;
      _animalCtrl.text = '';
      _selectedReporter = _defaultReporter(next);
    });
    await _loadAnimalsFor(next);
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final tag = _selectedAnimal?.tag ?? _animalCtrl.text.trim();
    if (tag.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final reporter = _selectedReporter?.label.split(' · ').first ?? '';
      final notes = StringBuffer('[$_severity]');
      if (reporter.isNotEmpty) notes.write(' reported by $reporter');
      await ApiService.createHealthTreatment({
        'tag': tag,
        'unit': _unit,
        'diagnosis': _symptoms.text.trim(),
        'medication': 'Pending vet review',
        'startDate': _onset.toIso8601String(),
        if (reporter.isNotEmpty) 'attendingVet': reporter,
        'notes': notes.toString(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final animals = _animalsByUnit[_unit] ?? const [];
    final reporters = _reportersByUnit[_unit] ?? const [];

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('🩺', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Report Sick Animal',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A7A7A),
                    ),
                    children: [
                      const TextSpan(text: 'Goes straight to the '),
                      const TextSpan(
                        text: 'vet',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' queue for review.'),
                      if (_userRole != null &&
                          _unitOwnership.containsKey(_userRole)) ...[
                        const TextSpan(text: '   You can file reports for: '),
                        TextSpan(
                          text: _allowedUnits.join(', '),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _TwoCol(
                  left: _Field(
                    label: 'UNIT *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: [
                        for (final u in _allowedUnits)
                          DropdownMenuItem(value: u, child: Text(u)),
                      ],
                      onChanged: _submitting ? null : _onUnitChanged,
                    ),
                  ),
                  right: _Field(
                    label: 'ANIMAL *',
                    child: _buildAnimalPicker(animals),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'SEVERITY *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _severity,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: [
                        for (final (wire, label) in _severities)
                          DropdownMenuItem(value: wire, child: Text(label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _severity = v ?? _severity),
                    ),
                  ),
                  right: _Field(
                    label: 'REPORTED BY *',
                    child: _buildReporterPicker(reporters),
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'SYMPTOMS / OBSERVATIONS *',
                  child: TextFormField(
                    controller: _symptoms,
                    maxLines: 3,
                    decoration: _decoration(
                      hint:
                          "What did you notice? E.g. 'off feed since morning', "
                          "'lameness on right hind', 'milk drop 30%', 'diarrhea', "
                          "'isolated from group'…",
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.length < 2) return 'Describe what you observed';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'ONSET',
                  child: InkWell(
                    onTap: _submitting
                        ? null
                        : () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _onset,
                              firstDate: DateTime(now.year - 1),
                              lastDate: now,
                            );
                            if (picked != null && mounted) {
                              setState(() => _onset = picked);
                            }
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: _decoration().copyWith(
                        suffixIcon: const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                      child: Text(
                        dateFmt.format(_onset),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: const Text('Send to Vet'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF555555),
                        side: const BorderSide(color: Color(0x33000000)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimalPicker(List<_AnimalOption> animals) {
    if (_loadingAnimals) {
      return InputDecorator(
        decoration: _decoration(),
        child: Row(
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading…',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
      );
    }
    if (animals.isEmpty) {
      return InputDecorator(
        decoration: _decoration(),
        child: const Text(
          'No animals registered in this unit',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }
    return Autocomplete<_AnimalOption>(
      initialValue: TextEditingValue(text: _animalCtrl.text),
      displayStringForOption: (a) => a.label,
      optionsBuilder: (text) {
        final q = text.text.trim().toLowerCase();
        if (q.isEmpty) return animals;
        return animals.where((a) =>
            a.tag.toLowerCase().contains(q) ||
            a.label.toLowerCase().contains(q));
      },
      onSelected: (a) {
        setState(() {
          _selectedAnimal = a;
          _animalCtrl.text = a.tag;
        });
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        textController.addListener(() {
          if (textController.text != _animalCtrl.text) {
            _animalCtrl.text = textController.text;
            // Re-bind selection if the user typed an exact tag.
            final exact = animals
                .where((a) => a.tag.toLowerCase() ==
                    textController.text.trim().toLowerCase())
                .toList();
            _selectedAnimal = exact.isEmpty ? null : exact.first;
          }
        });
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: _decoration(
            hint: 'Pick from ${animals.length}…',
            suffix: const Icon(Icons.arrow_drop_down, size: 20),
          ),
          validator: (v) {
            final s = v?.trim() ?? '';
            if (s.isEmpty) return 'Pick an animal';
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final a = list[i];
                  return ListTile(
                    dense: true,
                    title: Text(a.label),
                    onTap: () => onSelected(a),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReporterPicker(List<_ReporterOption> reporters) {
    if (_loadingStaff) {
      return InputDecorator(
        decoration: _decoration(),
        child: Row(
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading…',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
      );
    }
    if (reporters.isEmpty) {
      return InputDecorator(
        decoration: _decoration(),
        child: const Text(
          'No managers registered for this unit',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }
    return DropdownButtonFormField<_ReporterOption>(
      initialValue: _selectedReporter != null &&
              reporters.any((r) => r.id == _selectedReporter!.id)
          ? reporters.firstWhere((r) => r.id == _selectedReporter!.id)
          : null,
      decoration: _decoration(),
      isExpanded: true,
      items: [
        for (final r in reporters)
          DropdownMenuItem(value: r, child: Text(r.label)),
      ],
      onChanged: _submitting
          ? null
          : (v) => setState(() => _selectedReporter = v),
      validator: (v) => v == null ? 'Pick the reporter' : null,
    );
  }

  InputDecoration _decoration({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0x22000000)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0x22000000)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: _primary, width: 1.6),
      ),
    );
  }
}

class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 14), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF7A7A7A),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
