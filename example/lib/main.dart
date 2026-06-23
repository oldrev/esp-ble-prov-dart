import 'package:esp_ble_prov_dart/esp_ble_prov_dart.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  runApp(const ProvisioningExampleApp());
}

class ProvisioningExampleApp extends StatelessWidget {
  const ProvisioningExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ESP BLE Provisioning',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff246b5a)),
        useMaterial3: true,
      ),
      home: const ProvisioningPage(),
    );
  }
}

class ProvisioningPage extends StatefulWidget {
  const ProvisioningPage({super.key});

  @override
  State<ProvisioningPage> createState() => _ProvisioningPageState();
}

class _ProvisioningPageState extends State<ProvisioningPage> {
  final _devicePrefix = TextEditingController(text: 'PROV_');
  final _pop = TextEditingController();
  final _password = TextEditingController();
  final List<String> _logs = [];

  EspBleProvisioner? _provisioner;
  EspBleDevice? _device;
  List<EspBleDevice> _devices = const [];
  List<WiFiNetwork> _networks = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _requestBlePermissions();
  }

  @override
  void dispose() {
    _devicePrefix.dispose();
    _pop.dispose();
    _password.dispose();
    _provisioner?.disconnect();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _logs.insert(0, '$label...');
    });

    try {
      await action();
      _log('$label complete');
    } catch (error) {
      _log('$label failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestBlePermissions() async {
    try {
      await UniversalBle.requestPermissions();
    } catch (error) {
      _log('Permission request failed: $error');
    }
  }

  Future<void> _scanDevices() async {
    await _provisioner?.disconnect();
    final provisioner = _newProvisioner();
    final devices = await provisioner.scanDevices();
    setState(() {
      _provisioner = provisioner;
      _device = null;
      _devices = devices;
      _networks = const [];
    });
    _log('Found ${devices.length} device(s)');
  }

  Future<void> _selectDevice(EspBleDevice device) async {
    await _run('Prepare ${device.name ?? device.id}', () async {
      await _provisioner?.disconnect();
      final provisioner = _newProvisioner();
      try {
        await provisioner.connect(device: device);
        await provisioner.establishSession();
        final networks = await provisioner.scan();
        setState(() {
          _provisioner = provisioner;
          _device = device;
          _networks = networks;
        });
        _log('Found ${networks.length} Wi-Fi network(s)');
      } catch (_) {
        await provisioner.disconnect();
        setState(() {
          if (identical(_provisioner, provisioner)) {
            _provisioner = null;
          }
          _device = null;
          _networks = const [];
        });
        rethrow;
      }
    });
  }

  Future<void> _selectNetwork(WiFiNetwork network) async {
    _password.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(network.ssid.isEmpty ? '<hidden>' : network.ssid),
        content: TextField(
          controller: _password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Wi-Fi password',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Provision'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run('Provision ${network.ssid}', () async {
      final status = await _requireProvisioner().sendCredentials(
        WiFiConfig(
          ssid: network.ssid,
          passphrase: _password.text,
          channel: network.channel,
          bssid: network.bssid,
        ),
      );
      _log('Wi-Fi state: ${status.state.name}');
    });
  }

  Future<void> _disconnect() async {
    await _provisioner?.disconnect();
    setState(() {
      _provisioner = null;
      _device = null;
      _networks = const [];
    });
  }

  EspBleProvisioner _newProvisioner() {
    final prefix = _devicePrefix.text.trim();
    return EspBleProvisioner(
      deviceNamePrefix: prefix.isEmpty ? 'PROV_' : prefix,
      security: Security1(pop: _pop.text),
      logPayloads: true,
      onLog: _log,
    );
  }

  EspBleProvisioner _requireProvisioner() {
    final provisioner = _provisioner;
    if (provisioner == null || !provisioner.isConnected) {
      throw const ProvisionerError('Select a provisioning device first.');
    }
    return provisioner;
  }

  void _log(String message) {
    debugPrint('[esp_ble_prov_example] $message');
    if (!mounted) return;
    setState(() {
      _logs.insert(0, '${TimeOfDay.now().format(context)}  $message');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP BLE Provisioning'),
        actions: [
          IconButton(
            tooltip: 'Disconnect',
            onPressed: _busy ? null : () => _run('Disconnect', _disconnect),
            icon: const Icon(Icons.link_off),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final content = [
              _DevicePane(
                busy: _busy,
                devicePrefix: _devicePrefix,
                pop: _pop,
                devices: _devices,
                selectedDevice: _device,
                onScanDevices: () => _run('Scan devices', _scanDevices),
                onDeviceSelected: _selectDevice,
              ),
              _NetworkPane(
                busy: _busy,
                networks: _networks,
                onNetworkSelected: _selectNetwork,
              ),
              _LogPane(logs: _logs),
            ];

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 360, child: content[0]),
                  const VerticalDivider(width: 1),
                  Expanded(child: content[1]),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 360, child: content[2]),
                ],
              );
            }

            return DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.bluetooth), text: 'Devices'),
                      Tab(icon: Icon(Icons.wifi), text: 'Wi-Fi'),
                      Tab(icon: Icon(Icons.receipt_long), text: 'Log'),
                    ],
                  ),
                  Expanded(child: TabBarView(children: content)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DevicePane extends StatelessWidget {
  const _DevicePane({
    required this.busy,
    required this.devicePrefix,
    required this.pop,
    required this.devices,
    required this.selectedDevice,
    required this.onScanDevices,
    required this.onDeviceSelected,
  });

  final bool busy;
  final TextEditingController devicePrefix;
  final TextEditingController pop;
  final List<EspBleDevice> devices;
  final EspBleDevice? selectedDevice;
  final VoidCallback onScanDevices;
  final ValueChanged<EspBleDevice> onDeviceSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: devicePrefix,
                      decoration: const InputDecoration(
                        labelText: 'Device prefix',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: pop,
                      decoration: const InputDecoration(
                        labelText: 'Security1 PoP',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : onScanDevices,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Scan Devices'),
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: devices.isEmpty
              ? const Center(child: Text('No devices'))
              : ListView.separated(
                  itemCount: devices.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final selected = selectedDevice?.id == device.id;
                    return ListTile(
                      leading: Icon(
                        selected ? Icons.radio_button_checked : Icons.bluetooth,
                      ),
                      title: Text(device.name ?? 'Unnamed device'),
                      subtitle: Text(device.id),
                      enabled: !busy,
                      onTap: busy ? null : () => onDeviceSelected(device),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NetworkPane extends StatelessWidget {
  const _NetworkPane({
    required this.busy,
    required this.networks,
    required this.onNetworkSelected,
  });

  final bool busy;
  final List<WiFiNetwork> networks;
  final ValueChanged<WiFiNetwork> onNetworkSelected;

  @override
  Widget build(BuildContext context) {
    if (networks.isEmpty) return const Center(child: Text('No Wi-Fi networks'));
    return ListView.separated(
      itemCount: networks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final network = networks[index];
        return ListTile(
          leading: const Icon(Icons.wifi),
          title: Text(network.ssid.isEmpty ? '<hidden>' : network.ssid),
          subtitle: Text(
            'RSSI ${network.rssi} dBm  CH ${network.channel}  ${network.auth.name}',
          ),
          trailing: const Icon(Icons.chevron_right),
          enabled: !busy,
          onTap: busy ? null : () => onNetworkSelected(network),
        );
      },
    );
  }
}

class _LogPane extends StatelessWidget {
  const _LogPane({required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const Center(child: Text('No log entries'));
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) => SelectableText(logs[index]),
    );
  }
}
