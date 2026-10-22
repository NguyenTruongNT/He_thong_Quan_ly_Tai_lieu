import 'package:flutter/material.dart';

class MapDocumentItem {
  const MapDocumentItem({
    required this.id,
    required this.title,
    required this.subjectName,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.tags,
    this.isBorrowed = false,
    this.markerColor = Colors.blue,
  });

  final String id;
  final String title;
  final String subjectName;
  final String locationName;
  final double latitude;
  final double longitude;
  final List<String> tags;
  final bool isBorrowed;
  final Color markerColor;

  bool containsTag(String value) {
    final String normalizedValue = normalizeTag(value);

    return tags.any((String tag) => normalizeTag(tag) == normalizedValue);
  }

  static String normalizeTag(String value) {
    final String trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final String withoutHash = trimmed.startsWith('#')
        ? trimmed.substring(1)
        : trimmed;

    final String normalized = withoutHash
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();

    return normalized.isEmpty ? '' : '#$normalized';
  }
}
