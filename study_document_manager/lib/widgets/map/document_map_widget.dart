import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/map_document_item.dart';

class DocumentMapWidget extends StatelessWidget {
  const DocumentMapWidget({
    super.key,
    required this.documents,
    required this.onDocumentSelected,
    this.initialCenter = const LatLng(21.00745, 105.82472),
    this.initialZoom = 16.5,
  });

  final List<MapDocumentItem> documents;

  final ValueChanged<MapDocumentItem> onDocumentSelected;

  final LatLng initialCenter;

  final double initialZoom;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 5,
        maxZoom: 19,
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'vn.edu.tlu.study_document_manager',
        ),
        MarkerLayer(
          markers: documents.map((MapDocumentItem document) {
            return Marker(
              point: LatLng(document.latitude, document.longitude),
              width: 52,
              height: 52,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {
                  onDocumentSelected(document);
                },
                child: Tooltip(
                  message: document.title,
                  child: Icon(
                    document.isBorrowed
                        ? Icons.location_off_rounded
                        : Icons.location_on_rounded,
                    color: document.markerColor,
                    size: 46,
                    shadows: const <Shadow>[
                      Shadow(color: Colors.black38, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        RichAttributionWidget(
          attributions: const <SourceAttribution>[
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}
