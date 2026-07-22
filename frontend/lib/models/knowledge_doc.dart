// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : knowledge_doc.dart
// Description     : Data model for an admin-authored RAG knowledge-base document used by the per-listing AI chatbot.
// First Written on: Friday,17-Jul-2026
// Edited on       : Friday,17-Jul-2026

/// An admin-uploaded RAG knowledge-base document -- Supabase is the source
/// of truth (title/body live here); a matching vector lives in Pinecone's
/// separate "knowledge" namespace so the per-listing chatbot can retrieve
/// it when relevant.
class KnowledgeDoc {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  const KnowledgeDoc({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory KnowledgeDoc.fromJson(Map<String, dynamic> json) {
    return KnowledgeDoc(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
