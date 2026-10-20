import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/document_models.dart';

// =====================================================================
// [CHECKLIST 05 - THUẬT TOÁN GỢI Ý (RECOMMENDATION ENGINE)]
// File: lib/struct/recommendation_service.dart
// Phụ trách: Thành viên 4 - Lý Đình Sơn
// Mô tả: Thuật toán Content-Based Filtering tính điểm độ tương đồng
// giữa hồ sơ sở thích người dùng và tài liệu học tập:
// Score(doc) = 2.0 * |Tags_doc ∩ Tags_user| + 1.5 * (Trùng môn) + 1.0 * (Ưu tiên cao)
// =====================================================================

/// Mô hình lưu trữ sở thích của người dùng (User Interests / Profile)
class UserInterests {
  final List<String> favoriteTags;
  final List<String> favoriteSubjectIds;

  const UserInterests({
    this.favoriteTags = const [],
    this.favoriteSubjectIds = const [],
  });

  bool get isEmpty => favoriteTags.isEmpty && favoriteSubjectIds.isEmpty;
  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'favoriteTags': favoriteTags,
      'favoriteSubjectIds': favoriteSubjectIds,
    };
  }

  factory UserInterests.fromMap(Map<String, dynamic> map) {
    return UserInterests(
      favoriteTags: (map['favoriteTags'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      favoriteSubjectIds: (map['favoriteSubjectIds'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserInterests.fromJson(String jsonStr) {
    if (jsonStr.trim().isEmpty) return const UserInterests();
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return UserInterests.fromMap(decoded);
      }
    } catch (e) {
      debugPrint('Lỗi giải mã UserInterests JSON: $e');
    }
    return const UserInterests();
  }

  UserInterests copyWith({
    List<String>? favoriteTags,
    List<String>? favoriteSubjectIds,
  }) {
    return UserInterests(
      favoriteTags: favoriteTags ?? this.favoriteTags,
      favoriteSubjectIds: favoriteSubjectIds ?? this.favoriteSubjectIds,
    );
  }
}

/// Kết quả gợi ý tài liệu kèm theo điểm số và chuỗi lý do giải thích
class RecommendationResult {
  final DocumentModel document;
  final double score;
  final List<String> matchedTags;
  final bool matchedSubject;
  final bool isHighPriority;
  final String reason;

  const RecommendationResult({
    required this.document,
    required this.score,
    required this.matchedTags,
    required this.matchedSubject,
    required this.isHighPriority,
    required this.reason,
  });
}

/// Dịch vụ gợi ý tài liệu học tập thông minh (Recommendation Service)
class RecommendationService {
  RecommendationService._();

  static const String _prefPrefix = 'study_user_interests_';
  static final ValueNotifier<UserInterests> interestsNotifier =
      ValueNotifier<UserInterests>(const UserInterests());

  /// Chuẩn hóa chuỗi tag để so khớp (bỏ dấu cách, chữ thường, bỏ dấu # nếu có)
  static String normalizeTag(String tag) {
    var cleaned = tag.trim().toLowerCase();
    if (cleaned.startsWith('#')) {
      cleaned = cleaned.substring(1).trim();
    }
    return cleaned;
  }

  /// Tìm danh sách các thẻ trùng giữa tài liệu và sở thích người dùng
  static List<String> findMatchedTags(
    List<String> docTags,
    List<String> userTags,
  ) {
    if (docTags.isEmpty || userTags.isEmpty) return const [];

    final normalizedUserTags = {
      for (final t in userTags) normalizeTag(t): t,
    };

    final matched = <String>[];
    for (final docTag in docTags) {
      final norm = normalizeTag(docTag);
      if (norm.isNotEmpty && normalizedUserTags.containsKey(norm)) {
        matched.add(docTag);
      }
    }
    return matched;
  }

  /// Tính điểm độ tương đồng cho một tài liệu dựa theo công thức:
  /// Score(doc) = 2.0 * |Tags_doc ∩ Tags_user| + 1.5 * (Nếu trùng môn) + 1.0 * (Ưu tiên cao)
  static double calculateScore(DocumentModel doc, UserInterests interests) {
    double score = 0.0;

    // 1. Điểm từ thẻ Tags (2.0 mỗi tag khớp)
    final matchedTags = findMatchedTags(doc.tags, interests.favoriteTags);
    score += matchedTags.length * 2.0;

    // 2. Điểm từ môn học quan tâm (1.5 điểm nếu trùng môn)
    if (interests.favoriteSubjectIds.contains(doc.subjectId)) {
      score += 1.5;
    }

    // 3. Điểm từ mức độ ưu tiên của tài liệu (1.0 nếu priority == high)
    if (doc.priority == PriorityLevel.high) {
      score += 1.0;
    }

    return score;
  }

  /// Sinh chuỗi lý do gợi ý minh bạch (Explainable Recommendation)
  static String generateReason(
    DocumentModel doc,
    UserInterests interests, {
    SubjectModel? subject,
  }) {
    final matchedTags = findMatchedTags(doc.tags, interests.favoriteTags);
    final matchedSubject = interests.favoriteSubjectIds.contains(doc.subjectId);
    final isHigh = doc.priority == PriorityLevel.high;

    final reasons = <String>[];

    if (matchedSubject) {
      final subName = subject?.name ?? doc.subjectId;
      reasons.add('môn $subName');
    }

    if (matchedTags.isNotEmpty) {
      final formattedTags = matchedTags.map((t) => t.startsWith('#') ? t : '#$t').join(', ');
      reasons.add('thẻ $formattedTags');
    }

    if (isHigh) {
      reasons.add('độ ưu tiên cao');
    }

    if (reasons.isEmpty) {
      return 'Gợi ý tài liệu nổi bật';
    }

    return 'Gợi ý vì bạn quan tâm ${reasons.join(' và ')}';
  }

  /// Lấy danh sách tài liệu gợi ý theo điểm giảm dần
  static List<RecommendationResult> getRecommendations({
    required List<DocumentModel> allDocs,
    required UserInterests interests,
    Map<String, SubjectModel>? subjectMap,
    int limit = 5,
  }) {
    final results = <RecommendationResult>[];

    for (final doc in allDocs) {
      if (doc.isDeleted) continue;

      final matchedTags = findMatchedTags(doc.tags, interests.favoriteTags);
      final matchedSubject = interests.favoriteSubjectIds.contains(doc.subjectId);
      final isHigh = doc.priority == PriorityLevel.high;

      final score = calculateScore(doc, interests);

      // Chỉ gợi ý các tài liệu có điểm tương đồng > 0
      if (score > 0) {
        final subject = subjectMap?[doc.subjectId];
        final reason = generateReason(doc, interests, subject: subject);

        results.add(
          RecommendationResult(
            document: doc,
            score: score,
            matchedTags: matchedTags,
            matchedSubject: matchedSubject,
            isHighPriority: isHigh,
            reason: reason,
          ),
        );
      }
    }

    // Sắp xếp giảm dần theo điểm số (Score), nếu bằng điểm thì ưu tiên tài liệu cập nhật mới hơn
    results.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) return scoreComparison;
      return b.document.updatedDate.compareTo(a.document.updatedDate);
    });

    if (limit > 0 && results.length > limit) {
      return results.sublist(0, limit);
    }

    return results;
  }

  /// Đọc sở thích người dùng từ SharedPreferences
  static Future<UserInterests> getUserInterests(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefPrefix$userId';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final interests = UserInterests.fromJson(raw);
        interestsNotifier.value = interests;
        return interests;
      }
    } catch (e) {
      debugPrint('Lỗi đọc sở thích người dùng ($userId): $e');
    }
    const empty = UserInterests();
    interestsNotifier.value = empty;
    return empty;
  }

  /// Lưu sở thích người dùng vào SharedPreferences
  static Future<void> saveUserInterests(
    String userId,
    UserInterests interests,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefPrefix$userId';
      await prefs.setString(key, interests.toJson());
      interestsNotifier.value = interests;
    } catch (e) {
      debugPrint('Lỗi lưu sở thích người dùng ($userId): $e');
    }
  }

  /// Trích xuất danh sách tất cả các tag duy nhất từ các tài liệu để gợi ý
  static List<String> extractAllTags(List<DocumentModel> docs) {
    final tagSet = <String>{};
    for (final doc in docs) {
      if (doc.isDeleted) continue;
      for (final tag in doc.tags) {
        final t = tag.trim();
        if (t.isNotEmpty) tagSet.add(t);
      }
    }
    final list = tagSet.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}
