import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationSelection {
  const LocationSelection({
    required this.latitude,
    required this.longitude,
    required this.locationName,
  });

  final double latitude;
  final double longitude;
  final String locationName;
}

class LocationPickerBottomSheet extends StatefulWidget {
  const LocationPickerBottomSheet({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLocationName,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLocationName;

  static Future<LocationSelection?> show(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    String? initialLocationName,
  }) {
    return showModalBottomSheet<LocationSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return LocationPickerBottomSheet(
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          initialLocationName: initialLocationName,
        );
      },
    );
  }

  @override
  State<LocationPickerBottomSheet> createState() =>
      _LocationPickerBottomSheetState();
}

class _LocationPickerBottomSheetState extends State<LocationPickerBottomSheet> {
  static const LatLng _defaultLocation = LatLng(21.00745, 105.82472);

  final MapController _mapController = MapController();

  late final TextEditingController _locationNameController;

  LatLng? _selectedPoint;

  bool _isGettingCurrentLocation = false;

  @override
  void initState() {
    super.initState();

    _locationNameController = TextEditingController(
      text: widget.initialLocationName ?? '',
    );

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _getCurrentLocation() async {
    if (_isGettingCurrentLocation) {
      return;
    }

    setState(() {
      _isGettingCurrentLocation = true;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage(
          'Dịch vụ vị trí đang tắt. '
          'Hãy bật GPS hoặc Location rồi thử lại.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Bạn chưa cấp quyền truy cập vị trí.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Quyền vị trí đã bị từ chối vĩnh viễn. '
          'Hãy mở cài đặt ứng dụng để cấp lại quyền.',
        );

        await Geolocator.openAppSettings();
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) {
        return;
      }

      final LatLng currentPoint = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedPoint = currentPoint;

        if (_locationNameController.text.trim().isEmpty) {
          _locationNameController.text = 'Vị trí hiện tại của tôi';
        }
      });

      _mapController.move(currentPoint, 17);

      _showMessage('Đã lấy vị trí hiện tại thành công.');
    } on TimeoutException {
      _showMessage(
        'Không lấy được vị trí trong thời gian cho phép. '
        'Hãy kiểm tra GPS và thử lại.',
      );
    } on PermissionDeniedException {
      _showMessage('Ứng dụng không được cấp quyền truy cập vị trí.');
    } on LocationServiceDisabledException {
      _showMessage('Dịch vụ vị trí đang bị tắt.');
    } catch (error) {
      _showMessage('Không thể lấy vị trí hiện tại: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isGettingCurrentLocation = false;
        });
      }
    }
  }

  void _selectPoint(LatLng point) {
    setState(() {
      _selectedPoint = point;
    });
  }

  void _confirmLocation() {
    final LatLng? point = _selectedPoint;
    final String locationName = _locationNameController.text.trim();

    if (point == null) {
      _showMessage(
        'Hãy bấm lên bản đồ hoặc chọn '
        '"Lấy vị trí hiện tại".',
      );
      return;
    }

    if (locationName.isEmpty) {
      _showMessage('Hãy nhập tên hoặc mô tả vị trí.');
      return;
    }

    Navigator.of(context).pop(
      LocationSelection(
        latitude: point.latitude,
        longitude: point.longitude,
        locationName: locationName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialCenter = _selectedPoint ?? _defaultLocation;

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Chọn vị trí tài liệu',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _locationNameController,
              decoration: const InputDecoration(
                labelText: 'Tên hoặc mô tả vị trí',
                hintText: 'Ví dụ: Kệ số 4, Phòng tự học A2',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGettingCurrentLocation
                    ? null
                    : _getCurrentLocation,
                icon: _isGettingCurrentLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(
                  _isGettingCurrentLocation
                      ? 'Đang lấy vị trí...'
                      : 'Lấy vị trí hiện tại',
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 17,
                minZoom: 5,
                maxZoom: 19,
                onTap: (TapPosition tapPosition, LatLng point) {
                  _selectPoint(point);
                },
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/'
                      '{z}/{x}/{y}.png',
                  userAgentPackageName: 'vn.edu.tlu.study_document_manager',
                ),
                if (_selectedPoint != null)
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: _selectedPoint!,
                        width: 52,
                        height: 52,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.location_on_rounded,
                          color: colors.error,
                          size: 48,
                          shadows: const <Shadow>[
                            Shadow(color: Colors.black38, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                RichAttributionWidget(
                  attributions: const <SourceAttribution>[
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                if (_selectedPoint != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.location_on_rounded,
                          color: colors.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tọa độ: '
                            '${_selectedPoint!.latitude.toStringAsFixed(6)}, '
                            '${_selectedPoint!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _confirmLocation,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Xác nhận vị trí'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
