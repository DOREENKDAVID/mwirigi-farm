import 'package:flutter/material.dart';

import '../core/service/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _today = const {};
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getTodayMetrics(),
        ApiService.getDailySummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _today = results[0];
        _summary = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: const Color(0xFF27500A),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);

    final entries = <_ReportRow>[
      _ReportRow('Today\'s metrics', _flatten(_today)),
      _ReportRow('Daily summary', _flatten(_summary)),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Reports Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          );
        }
        final row = entries[index - 1];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insert_chart, color: Color(0xFF27500A)),
                    const SizedBox(width: 8),
                    Text(
                      row.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (row.lines.isEmpty)
                  const Text('No data yet.',
                      style: TextStyle(color: Colors.grey))
                else
                  ...row.lines.map(
                    (l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(l),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Flattens a one-level map into "key: value" strings for quick display.
  List<String> _flatten(Map<String, dynamic> map) {
    if (map.isEmpty) return const [];
    return map.entries.map((e) {
      final v = e.value;
      if (v is Map || v is List) {
        return '${e.key}: ${v.toString()}';
      }
      return '${e.key}: $v';
    }).toList();
  }
}

class _ReportRow {
  final String title;
  final List<String> lines;
  _ReportRow(this.title, this.lines);
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.error_outline, color: Colors.red[400], size: 48),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
