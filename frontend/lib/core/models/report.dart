// Report DTO models — match the backend reports.catalog.service shape.
// Every report has: title, period, summary, kpis, sections, footnote.
// Sections are typed via the `type` field; the renderer dispatches.

class ReportListItem {
  ReportListItem({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.iconBg,
    required this.category,
    required this.formats,
  });

  final String key;
  final String label;
  final String description;
  final String icon;
  final String iconBg;
  final String category;
  final List<String> formats;

  factory ReportListItem.fromJson(Map<String, dynamic> j) => ReportListItem(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        icon: (j['icon'] ?? '📄').toString(),
        iconBg: (j['iconBg'] ?? '#EAF3DE').toString(),
        category: (j['category'] ?? 'Reports').toString(),
        formats: ((j['formats'] as List?) ?? const ['PDF'])
            .map((e) => e.toString())
            .toList(),
      );
}

class ReportSpec {
  ReportSpec({
    required this.title,
    required this.period,
    required this.summary,
    required this.kpis,
    required this.sections,
    this.footnote,
  });

  final String title;
  final String period;
  final String summary;
  final List<ReportKpi> kpis;
  final List<ReportSection> sections;
  final String? footnote;

  factory ReportSpec.fromJson(Map<String, dynamic> j) => ReportSpec(
        title: (j['title'] ?? '').toString(),
        period: (j['period'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
        kpis: ((j['kpis'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => ReportKpi.fromJson(m.cast<String, dynamic>()))
            .toList(),
        sections: ((j['sections'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => ReportSection.fromJson(m.cast<String, dynamic>()))
            .toList(),
        footnote: j['footnote']?.toString(),
      );
}

class ReportKpi {
  ReportKpi({
    required this.label,
    required this.value,
    this.unit,
    this.target,
    this.colorClass,
  });

  final String label;
  final String value;
  final String? unit;
  final String? target;
  /// "g" green · "a" amber · "r" red · "b" blue
  final String? colorClass;

  factory ReportKpi.fromJson(Map<String, dynamic> j) => ReportKpi(
        label: (j['label'] ?? '').toString(),
        value: (j['value'] ?? '').toString(),
        unit: j['unit']?.toString(),
        target: j['target']?.toString(),
        colorClass: j['colorClass']?.toString(),
      );
}

/// Tagged union — `type` discriminates which optional fields apply.
class ReportSection {
  ReportSection({
    required this.type,
    this.title,
    this.body,
    this.headers,
    this.rows,
    this.items,
    this.sessions,
    this.limit,
    this.lines,
    this.roles,
  });

  final String type;
  // narrative / table / progress / split / reminders headers
  final String? title;
  // narrative
  final String? body;
  // table
  final List<String>? headers;
  final List<List<String>>? rows;
  // progress / split
  final List<ReportSectionItem>? items;
  // session-breakdown
  final List<ReportSessionRow>? sessions;
  // reminders
  final int? limit;
  // comments
  final int? lines;
  // signature
  final List<String>? roles;

  factory ReportSection.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] ?? '').toString();
    return ReportSection(
      type: type,
      title: j['title']?.toString(),
      body: j['body']?.toString(),
      headers: j['headers'] is List
          ? (j['headers'] as List).map((e) => e.toString()).toList()
          : null,
      rows: j['rows'] is List
          ? (j['rows'] as List)
              .whereType<List>()
              .map((r) => r.map((c) => c.toString()).toList())
              .toList()
          : null,
      items: j['items'] is List
          ? (j['items'] as List)
              .whereType<Map>()
              .map((m) => ReportSectionItem.fromJson(m.cast<String, dynamic>()))
              .toList()
          : null,
      sessions: j['sessions'] is List
          ? (j['sessions'] as List)
              .whereType<Map>()
              .map((m) => ReportSessionRow.fromJson(m.cast<String, dynamic>()))
              .toList()
          : null,
      limit: j['limit'] is num ? (j['limit'] as num).toInt() : null,
      lines: j['lines'] is num ? (j['lines'] as num).toInt() : null,
      roles: j['roles'] is List
          ? (j['roles'] as List).map((e) => e.toString()).toList()
          : null,
    );
  }
}

class ReportSectionItem {
  ReportSectionItem({
    required this.label,
    this.value,
    this.sub,
    this.color,
    this.pct,
    this.detail,
  });

  final String label;
  // split items
  final String? value;
  final String? sub;
  final String? color;
  // progress items
  final num? pct;
  final String? detail;

  factory ReportSectionItem.fromJson(Map<String, dynamic> j) =>
      ReportSectionItem(
        label: (j['label'] ?? '').toString(),
        value: j['value']?.toString(),
        sub: j['sub']?.toString(),
        color: j['color']?.toString(),
        pct: j['pct'] is num ? (j['pct'] as num) : null,
        detail: j['detail']?.toString(),
      );
}

class ReportSessionRow {
  ReportSessionRow({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  factory ReportSessionRow.fromJson(Map<String, dynamic> j) => ReportSessionRow(
        label: (j['label'] ?? '').toString(),
        value: (j['value'] ?? '').toString(),
        highlight: j['highlight'] == true,
      );
}
