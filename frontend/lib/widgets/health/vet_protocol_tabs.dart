import 'package:flutter/material.dart';

import '../../core/models/health.dart';

/// "Vet protocol reference" card — three tabs (Chicks / Calves / Piglets).
/// Tab content is fully driven by `GET /api/health/protocol-reference`.
class VetProtocolTabs extends StatefulWidget {
  const VetProtocolTabs({super.key, required this.reference});
  final ProtocolReference reference;

  @override
  State<VetProtocolTabs> createState() => _VetProtocolTabsState();
}

class _VetProtocolTabsState extends State<VetProtocolTabs> {
  int _selected = 0;

  late final List<_Tab> _tabs = [
    _Tab(emoji: '🐣', label: 'Chicks (Day 1 → Cage)', steps: widget.reference.chicks),
    _Tab(emoji: '🐄', label: 'Calves (Birth → Service)', steps: widget.reference.calves),
    _Tab(emoji: '🐷', label: 'Piglets (Farrow → Market)', steps: widget.reference.piglets),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_selected];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '📋 VET PROTOCOL REFERENCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reference protocols from the farm vet. Tap a tab to see the schedule for that animal type.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 14),
          _TabBar(
            tabs: _tabs,
            selected: _selected,
            onSelect: (i) => setState(() => _selected = i),
          ),
          const SizedBox(height: 14),
          if (tab.steps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No protocol steps recorded yet.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            Column(
              children: [
                for (final s in tab.steps) ...[
                  _StepRow(step: s),
                  if (s != tab.steps.last)
                    const Divider(height: 1, color: Color(0x0F000000)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _Tab {
  _Tab({required this.emoji, required this.label, required this.steps});
  final String emoji;
  final String label;
  final List<ProtocolStep> steps;
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });
  final List<_Tab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4F0),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Stack vertically on very narrow screens to keep labels readable.
          if (constraints.maxWidth < 520) {
            return Column(
              children: [
                for (var i = 0; i < tabs.length; i += 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _TabButton(
                      tab: tabs[i],
                      active: i == selected,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < tabs.length; i += 1)
                Expanded(
                  child: _TabButton(
                    tab: tabs[i],
                    active: i == selected,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.active,
    required this.onTap,
  });
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '${tab.emoji}  ${tab.label}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active
                    ? const Color(0xFF27500A)
                    : Colors.black54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final ProtocolStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 88),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5E6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              step.dayLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF27500A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF27500A),
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: step.procedure,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (step.notes != null && step.notes!.isNotEmpty)
                    TextSpan(
                      text: ' — ${step.notes}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF333333),
                      ),
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
