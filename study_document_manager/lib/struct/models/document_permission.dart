enum DocumentPermissionRole {
  viewer,
  editor;

  String get value => name;

  static DocumentPermissionRole fromString(String value) {
    return switch (value) {
      'editor' => DocumentPermissionRole.editor,
      _ => DocumentPermissionRole.viewer,
    };
  }
}

class DocumentPermission {
  const DocumentPermission({
    required this.documentId,
    required this.ownerId,
    required this.sharedWithUserId,
    required this.role,
    required this.createdAt,
  });

  final String documentId;
  final String ownerId;
  final String sharedWithUserId;
  final DocumentPermissionRole role;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'document_id': documentId,
    'owner_id': ownerId,
    'shared_with_user_id': sharedWithUserId,
    'role': role.value,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory DocumentPermission.fromMap(Map<String, Object?> map) {
    return DocumentPermission(
      documentId: map['document_id']! as String,
      ownerId: map['owner_id']! as String,
      sharedWithUserId: map['shared_with_user_id']! as String,
      role: DocumentPermissionRole.fromString(map['role']! as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at']! as int,
      ),
    );
  }
}
