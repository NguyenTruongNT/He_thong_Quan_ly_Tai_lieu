import 'package:flutter/material.dart';

import 'pages/document_map_page.dart';
import 'widgets/map/location_picker_bottom_sheet.dart';
import 'widgets/tags/tag_input_field.dart';

void main() {
  runApp(const MapTaggingDemoApp());
}

class MapTaggingDemoApp extends StatelessWidget {
  const MapTaggingDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map & Tagging Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const MapTaggingDemoPage(),
    );
  }
}

class MapTaggingDemoPage extends StatefulWidget {
  const MapTaggingDemoPage({super.key});

  @override
  State<MapTaggingDemoPage> createState() => _MapTaggingDemoPageState();
}

class _MapTaggingDemoPageState extends State<MapTaggingDemoPage> {
  List<String> _tags = <String>['#Flutter'];

  LocationSelection? _location;

  Future<void> _pickLocation() async {
    final LocationSelection? selection = await LocationPickerBottomSheet.show(
      context,
      initialLatitude: _location?.latitude,
      initialLongitude: _location?.longitude,
      initialLocationName: _location?.locationName,
    );

    if (selection == null) {
      return;
    }

    setState(() {
      _location = selection;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Tagging & Bản đồ'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Xem bản đồ tài liệu',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DocumentMapPage(),
                ),
              );
            },
            icon: const Icon(Icons.map_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            'Gắn thẻ tài liệu',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TagInputField(
            initialTags: _tags,
            onChanged: (List<String> tags) {
              setState(() {
                _tags = tags;
              });
            },
          ),
          const SizedBox(height: 30),
          Text(
            'Vị trí vật lý',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(_location?.locationName ?? 'Chưa chọn vị trí'),
              subtitle: _location == null
                  ? const Text('Bấm để chọn vị trí trên bản đồ')
                  : Text(
                      '${_location!.latitude.toStringAsFixed(6)}, '
                      '${_location!.longitude.toStringAsFixed(6)}',
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickLocation,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DocumentMapPage(),
                ),
              );
            },
            icon: const Icon(Icons.map_rounded),
            label: const Text('Xem bản đồ tài liệu mẫu'),
          ),
          const SizedBox(height: 20),
          Text(
            'Dữ liệu hiện tại',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(
            'Tags: ${_tags.join(', ')}\n'
            'Vị trí: '
            '${_location?.locationName ?? 'Chưa chọn'}',
          ),
        ],
      ),
    );
  }
}
