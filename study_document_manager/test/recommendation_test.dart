import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/struct/models/document_models.dart';
import 'package:study_document_manager/struct/recommendation_service.dart';

void main() {
  group('Kiểm thử Thuật toán Gợi ý (RecommendationService - Checklist 05)', () {
    final now = DateTime.now();

    final docFlutter = DocumentModel(
      id: 'doc-1',
      title: 'Giáo trình Lập trình Flutter nâng cao',
      subjectId: 'sub-mobile',
      type: DocumentType.reference,
      tags: ['#Flutter', '#Mobile', '#Dart'],
      priority: PriorityLevel.high,
      createdDate: now.subtract(const Duration(days: 2)),
      updatedDate: now.subtract(const Duration(hours: 5)),
    );

    final docAI = DocumentModel(
      id: 'doc-2',
      title: 'Slide Nhập môn Trí tuệ nhân tạo',
      subjectId: 'sub-ai',
      type: DocumentType.lecture,
      tags: ['#AI', '#MachineLearning', '#Python'],
      priority: PriorityLevel.medium,
      createdDate: now.subtract(const Duration(days: 5)),
      updatedDate: now.subtract(const Duration(days: 1)),
    );

    final docDatabase = DocumentModel(
      id: 'doc-3',
      title: 'Đề thi Hệ cơ sở dữ liệu phân tán',
      subjectId: 'sub-db',
      type: DocumentType.exam,
      tags: ['#Database', '#SQL', '#Distributed'],
      priority: PriorityLevel.low,
      createdDate: now.subtract(const Duration(days: 10)),
      updatedDate: now.subtract(const Duration(days: 3)),
    );

    final docUnrelated = DocumentModel(
      id: 'doc-4',
      title: 'Bài tập Tiếng Anh chuyên ngành',
      subjectId: 'sub-english',
      type: DocumentType.assignment,
      tags: ['#English', '#Grammar'],
      priority: PriorityLevel.low,
      createdDate: now.subtract(const Duration(days: 4)),
      updatedDate: now.subtract(const Duration(days: 2)),
    );

    final docDeleted = DocumentModel(
      id: 'doc-5',
      title: 'Tài liệu Flutter cũ (Đã xóa)',
      subjectId: 'sub-mobile',
      type: DocumentType.reference,
      tags: ['#Flutter'],
      priority: PriorityLevel.high,
      isDeleted: true,
      createdDate: now.subtract(const Duration(days: 20)),
      updatedDate: now.subtract(const Duration(days: 15)),
    );

    test('1. Công thức tính điểm chuẩn xác theo Data Contract', () {
      // User quan tâm: tag #Flutter, #Dart, môn 'sub-mobile'
      const interests = UserInterests(
        favoriteTags: ['#Flutter', '#Dart'],
        favoriteSubjectIds: ['sub-mobile'],
      );

      // docFlutter:
      // - 2 tags trùng (#Flutter, #Dart) => 2 * 2.0 = 4.0
      // - Trùng môn ('sub-mobile') => + 1.5
      // - Priority high => + 1.0
      // Tổng điểm kỳ vọng = 4.0 + 1.5 + 1.0 = 6.5
      final score = RecommendationService.calculateScore(docFlutter, interests);
      expect(score, closeTo(6.5, 0.001));

      // docAI: Không khớp tag nào, không khớp môn, priority medium (không cộng)
      // Tổng điểm kỳ vọng = 0.0
      final scoreAI = RecommendationService.calculateScore(docAI, interests);
      expect(scoreAI, closeTo(0.0, 0.001));
    });

    test('2. So khớp Tags không phân biệt chữ hoa/thường và tiền tố #', () {
      const interests = UserInterests(
        favoriteTags: ['flutter', 'DART', '#Mobile'],
      );

      final matched = RecommendationService.findMatchedTags(
        docFlutter.tags,
        interests.favoriteTags,
      );

      // docFlutter có ['#Flutter', '#Mobile', '#Dart']
      expect(matched.length, equals(3));
    });

    test('3. Chỉ có điểm môn học và độ ưu tiên', () {
      const interests = UserInterests(
        favoriteTags: ['#Rust'],
        favoriteSubjectIds: ['sub-db'],
      );

      // docDatabase: không trùng tag, trùng môn (+1.5), priority low (0.0) => 1.5
      final score = RecommendationService.calculateScore(docDatabase, interests);
      expect(score, closeTo(1.5, 0.001));
    });

    test('4. Sắp xếp danh sách gợi ý theo điểm số giảm dần và lọc bỏ doc bị xóa', () {
      const interests = UserInterests(
        favoriteTags: ['#Flutter', '#Dart', '#AI'],
        favoriteSubjectIds: ['sub-mobile', 'sub-ai'],
      );

      final recommendations = RecommendationService.getRecommendations(
        allDocs: [docFlutter, docAI, docDatabase, docUnrelated, docDeleted],
        interests: interests,
      );

      // docDeleted (isDeleted == true) phải bị bỏ qua
      expect(recommendations.any((r) => r.document.id == 'doc-5'), isFalse);

      // docUnrelated có điểm 0.0 nên bị lọc bỏ
      expect(recommendations.any((r) => r.document.id == 'doc-4'), isFalse);

      // docFlutter có điểm cao hơn docAI => đứng đầu
      expect(recommendations.first.document.id, equals('doc-1'));
      expect(recommendations[1].document.id, equals('doc-2'));
    });

    test('5. Sinh chuỗi lý do gợi ý minh bạch (Explainable Recommendation)', () {
      const interests = UserInterests(
        favoriteTags: ['#Flutter'],
        favoriteSubjectIds: ['sub-mobile'],
      );

      final subMobile = SubjectModel(
        id: 'sub-mobile',
        name: 'Lập trình Thiết bị Di động',
        code: 'CSE441',
        colorValue: 0xFF2196F3,
        iconName: 'phone_android',
        createdDate: DateTime.now(),
      );

      final reason = RecommendationService.generateReason(
        docFlutter,
        interests,
        subject: subMobile,
      );

      expect(reason, contains('Lập trình Thiết bị Di động'));
      expect(reason, contains('#Flutter'));
      expect(reason, contains('độ ưu tiên cao'));
    });

    test('6. Tuần tự hóa JSON của UserInterests (Serialization)', () {
      const interests = UserInterests(
        favoriteTags: ['#Flutter', '#AI'],
        favoriteSubjectIds: ['sub-1', 'sub-2'],
      );

      final jsonStr = interests.toJson();
      final decoded = UserInterests.fromJson(jsonStr);

      expect(decoded.favoriteTags, equals(['#Flutter', '#AI']));
      expect(decoded.favoriteSubjectIds, equals(['sub-1', 'sub-2']));
    });

    test('7. Trích xuất danh sách thẻ duy nhất (extractAllTags)', () {
      final tags = RecommendationService.extractAllTags([
        docFlutter,
        docAI,
        docDeleted, // Đã xóa nên không tính
      ]);

      expect(tags.contains('#Flutter'), isTrue);
      expect(tags.contains('#Mobile'), isTrue);
      expect(tags.contains('#Dart'), isTrue);
      expect(tags.contains('#AI'), isTrue);
    });
  });
}
