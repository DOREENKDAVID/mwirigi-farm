import 'package:flutter/material.dart';

import '../core/models/dashboard.models.dart';
import '../core/service/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardModel? dashboardData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    try {
      final data = await ApiService.getDashboardData();
      if (!mounted) return;
      setState(() {
        dashboardData = DashboardModel.fromJson(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF27500A),
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: const Color(0xFFEAF3DE),
              child: const Text(
                'MF',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Mwirigi Farm'),
          ],
        ),
        actions: [
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'John Doe',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Admin',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFC0DD97),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _buildDashboardBody(),
    );
  }

  Widget _buildDashboardBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dashboardData == null) {
      return const Center(
        child: Text(
          'Unable to load dashboard data.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Row(
      children: [
        NavigationRail(
          backgroundColor: Colors.white,
          selectedIndex: 0,
          labelType: NavigationRailLabelType.all,
          selectedIconTheme: const IconThemeData(color: Color(0xFF27500A)),
          selectedLabelTextStyle: const TextStyle(
            color: Color(0xFF27500A),
            fontWeight: FontWeight.bold,
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: Text('Dashboard'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.water_drop_outlined),
              label: Text('Dairy'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.egg_outlined),
              label: Text('Layers'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.pets_outlined),
              label: Text('Piggery'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.bar_chart),
              label: Text('Reports'),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Farm Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF27500A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Today | 30 April 2026',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildKpiCard(
                      title: 'Milk - net today',
                      value: '${dashboardData!.milkNet} L',
                      subtitle: 'Target: ${dashboardData!.milkTarget}',
                    ),
                    _buildKpiCard(
                      title: 'Eggs - today',
                      value: '${dashboardData!.eggs}',
                      subtitle: 'Target: ${dashboardData!.eggsTarget}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8E8E4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27500A),
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
