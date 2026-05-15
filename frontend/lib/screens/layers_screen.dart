import 'package:flutter/material.dart';

import '../core/service/api_service.dart';

class LayersScreen extends StatefulWidget {
  const LayersScreen({super.key});

  @override
  State<LayersScreen> createState() => _LayersScreenState();
}

class _LayersScreenState extends State<LayersScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _records = const [];

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
      final data = await ApiService.getEggRecords();
      if (!mounted) return;
      setState(() {
        _records = data;
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
        title: const Text('Layers Management'),
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
    if (_records.isEmpty) return const _EmptyView(message: 'No egg records yet.');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final r = _records[index] as Map<String, dynamic>;
        final houseId = (r['houseId'] ?? r['house'] ?? 'Layer ${index + 1}').toString();
        final eggs = r['totalEggs'] ?? r['eggs'] ?? r['count'];
        final date = (r['date'] ?? '').toString().split('T').first;
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'House: $houseId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  eggs == null
                      ? (date.isEmpty ? 'No details available.' : 'Date: $date')
                      : 'Eggs: $eggs   ${date.isEmpty ? '' : '· $date'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.egg_outlined, color: Colors.grey[400], size: 56),
        const SizedBox(height: 12),
        Center(child: Text(message, style: const TextStyle(color: Colors.grey))),
      ],
    );
  }
}
