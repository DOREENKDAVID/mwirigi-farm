import 'package:flutter/material.dart';

import '../../core/models/layers.dart';

/// Horizontal row of house picker tabs. Each tab shows a numbered color
/// chip + name + capacity. The selected tab gets a colored border.
///
/// Designed for ~3 houses; wraps onto new lines if more are added.
class HouseTabs extends StatelessWidget {
  const HouseTabs({
    super.key,
    required this.houses,
    required this.selectedId,
    required this.onSelect,
  });

  final List<LayerHouse> houses;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < houses.length; i++)
          _Tab(
            index: i + 1,
            house: houses[i],
            selected: houses[i].id == selectedId,
            onTap: () => onSelect(houses[i].id),
          ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.index,
    required this.house,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final LayerHouse house;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(house.color);

    return Material(
      color: selected ? const Color(0xFFEAF3DE) : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? color : const Color(0x14000000),
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    house.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${house.capacity} birds',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  var s = hex.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFF27500A);
}
