import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:wifi_scan/wifi_scan.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<WiFiAccessPoint> _discoveredNetworks = [];
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
    final can = await WiFiScan.instance.canStartScan(askPermissions: true);

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

    Set<String> uniqueSSIDs = {};
    List<WiFiAccessPoint> filteredNetworks = [];

    for (var network in discoveredNetworks) {
      if (!uniqueSSIDs.contains(network.ssid)) {
        uniqueSSIDs.add(network.ssid);
        filteredNetworks.add(network);
      }
    }

    setState(() {
      _discoveredNetworks.clear();
      _discoveredNetworks.addAll(filteredNetworks);
      _isScanning = false;
    });
  }

  void _showWifiData(WiFiAccessPoint wifiAccessPoint) async {
    // Show modal with network details (replace with your desired modal implementation)
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('WiFi Network: ${wifiAccessPoint.ssid}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BSSID: ${wifiAccessPoint.bssid}'),
                Text('Signal Strength: ${wifiAccessPoint.level}'),
                Text('Frequency: ${wifiAccessPoint.frequency} MHz'),
                Text('Capabilities: ${wifiAccessPoint.capabilities}'),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // _showConnectedWifiData(wifiAccessPoint);
                    _connectToDevice(wifiAccessPoint);
                  },
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.green)),
                  child: const Text(
                    'Connect',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _connectToDevice(WiFiAccessPoint wifiNetwork) async {
    try {
      await WiFiForIoTPlugin.disconnect();

      NetworkSecurity networkSecurity =
          getSecurityType(wifiNetwork.capabilities);

      if (!(networkSecurity == NetworkSecurity.WEP ||
          networkSecurity == NetworkSecurity.WPA)) {
        await WiFiForIoTPlugin.connect(wifiNetwork.ssid);
        print('Conectado a ${wifiNetwork.ssid}');
        _showWifiData(wifiNetwork);
        return;
      }

      // WiFi requires password, show modal to input password
      TextEditingController passwordController = TextEditingController();
      // ignore: use_build_context_synchronously
      await showDialog<String?>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Enter the password for ${wifiNetwork.ssid}'),
            content: TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Password',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (passwordController.text != '') {
                    log('connecting to ${wifiNetwork.ssid} with password ${passwordController.text}');

                    log('capabilities: ${getSecurityType(wifiNetwork.capabilities)}');
                    await WiFiForIoTPlugin.connect(wifiNetwork.ssid,
                        bssid: wifiNetwork.bssid,
                        withInternet: true,
                        password: passwordController.text,
                        security: getSecurityType(wifiNetwork.capabilities));
                    log('Conected to ${wifiNetwork.ssid}');
                  }
                  _showConnectedWifiData(wifiNetwork);
                  // ignore: use_build_context_synchronously
                  Navigator.pop(context);
                },
                child: const Text('Connect'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      log('Error connecting to wifi: $error');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to wifi: $error'),
        ),
      );
    }
  }

  void _showConnectedWifiData(WiFiAccessPoint wifiAccessPoint) async {
    String? ipv4Address = await WiFiForIoTPlugin.getIP();
    Socket? socket;

    try {
      socket = await Socket.connect('192.168.6.29', 8080);
      log('Connected to TCP server');

      TextEditingController messageController = TextEditingController();
      List<String> messages = [];

      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Connected WiFi Network: ${wifiAccessPoint.ssid}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IPv4 Address: $ipv4Address'),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message to send',
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      String message = messageController.text;
                      if (message.isNotEmpty && socket != null) {
                        socket.write(message);
                        messages.add('Sent: $message');
                        messageController.clear();
                        setState(
                            () {}); // Update the UI after sending a message
                      }
                    },
                    child: const Text('Send Message'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Messages:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // ListView.builder(
                  //   shrinkWrap: true,
                  //   itemCount: messages.length,
                  //   itemBuilder: (context, index) {
                  //     return Text(messages[index]);
                  //   },
                  // ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      if (socket != null) {
                        socket.close();
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          );
        },
      );

      // Setup a listener to receive data from the server
      socket.listen(
        (List<int> event) {
          String receivedMessage = utf8.decode(event);
          messages.add('Received: $receivedMessage');
          setState(() {}); // Update the UI when receiving a message
        },
        onError: (error) {
          print('Error receiving data: $error');
        },
        onDone: () {
          print('Connection closed');
        },
      );
    } catch (error) {
      log('Error connecting to TCP server: $error');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to TCP server: $error'),
        ),
      );
    }
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
                      title: Text(network.ssid.toString()),
                      subtitle: Text('Signal strength: ${network.level} dBm'),
                      onTap: () {
                        _showWifiData(network);
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

  NetworkSecurity getSecurityType(String text) {
    if (text.toLowerCase().contains('wpa')) {
      return NetworkSecurity.WPA;
    } else if (text.toLowerCase().contains('wep')) {
      return NetworkSecurity.WEP;
    } else {
      return NetworkSecurity.NONE;
    }
  }
}

void main() {
  runApp(const MaterialApp(
    home: MyHomePage(),
  ));
}
