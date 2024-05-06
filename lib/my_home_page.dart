import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:wifi_scan/wifi_scan.dart'; // Importa el paquete wifi_scan

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<WiFiAccessPoint> _discoveredNetworks = <WiFiAccessPoint>[];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
    });
    final can = await WiFiScan.instance.canStartScan();

    if (can != CanStartScan.yes) {
      if (mounted) kShowSnackBar(context, "Cannot start scan: $can");
      return;
    }

    final result = await WiFiScan.instance.startScan();
    if (mounted) kShowSnackBar(context, "startScan: $result");

    List<WiFiAccessPoint> discoveredNetworks;

    try {
      discoveredNetworks = await WiFiScan.instance.getScannedResults();
    } catch (e) {
      log(e.toString());
      return;
    }

    setState(() {
      _discoveredNetworks.clear();
      _discoveredNetworks.addAll(discoveredNetworks);
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(WiFiAccessPoint wifiAccessPoint) async {
    try {
      // Connect to device using TCP
      final Socket socket = await Socket.connect(wifiAccessPoint.bssid, 80);

      socket.listen((List<int> event) {
        // Handle received data
        final data = utf8.decode(event);
        log('Received data: $data');
        // Handle received data accordingly
      });

      _showWifiService(wifiAccessPoint); // Call to show modal
    } catch (error) {
      debugPrint('Error connecting to device: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to device: $error'),
        ),
      );
    }
  }

  void _showWifiService(WiFiAccessPoint wifiAccessPoint) async {
    // Show modal with list of services (replace with your desired modal implementation)
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Access Point: ${wifiAccessPoint.ssid}'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                    title: Text('bssid: ${wifiAccessPoint.bssid}'),
                    onTap: () => {}),
                ListTile(
                    title:
                        Text('capabilities: ${wifiAccessPoint.capabilities}'),
                    onTap: () => {}),
                ListTile(
                    title: Text('standard: ${wifiAccessPoint.standard}'),
                    onTap: () => {}),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Network Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
      body: _isScanning
          ? const Center(child: CircularProgressIndicator())
          : _discoveredNetworks.isEmpty
              ? const Center(child: Text('No networks found'))
              : ListView.builder(
                  itemCount: _discoveredNetworks.length,
                  itemBuilder: (context, index) {
                    final network = _discoveredNetworks[index];
                    return ListTile(
                      title: Text(network.ssid),
                      subtitle: Text('Signal strength: ${network.level} dBm'),
                      onTap: () {
                        _connectToDevice(_discoveredNetworks[index]);
                      },
                    );
                  },
                ),
    );
  }

  void kShowSnackBar(BuildContext context, String message) {
    if (kDebugMode) print(message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
