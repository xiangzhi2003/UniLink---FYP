import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HealthCheckScreen(),
    );
  }
}

class HealthCheckScreen extends StatefulWidget {
  const HealthCheckScreen({super.key});

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  final _apiService = ApiService();
  String _result = 'Not checked yet';
  bool _loading = false;

  Future<void> _checkHealth() async {
    setState(() {
      _loading = true;
      _result = 'Checking...';
    });

    try {
      final response = await _apiService.checkHealth();
      setState(() => _result = response.toString());
    } catch (e) {
      setState(() => _result = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UniLink — Backend Health Check')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Backend response:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(_result, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _checkHealth,
              child: const Text('Check /health'),
            ),
          ],
        ),
      ),
    );
  }
}
