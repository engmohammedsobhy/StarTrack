import 'dart:convert';
import 'package:itiproject/core/services/persona_label_service.dart';

class PerformanceTelemetry {
  final double hydrationLatencyMs;
  final double vectorIndexingLatencyMs;
  final double vectorSearchLatencyMs;
  final double llmInferenceLatencyMs;
  final double totalExecutionMs;
  final double avgSimilarityScore;

  PerformanceTelemetry({
    required this.hydrationLatencyMs,
    required this.vectorIndexingLatencyMs,
    required this.vectorSearchLatencyMs,
    required this.llmInferenceLatencyMs,
    required this.totalExecutionMs,
    required this.avgSimilarityScore,
  });

  factory PerformanceTelemetry.fromJson(Map<String, dynamic> json) {
    return PerformanceTelemetry(
      hydrationLatencyMs: (json['hydration_latency_ms'] as num?)?.toDouble() ?? 0.0,
      vectorIndexingLatencyMs: (json['vector_indexing_latency_ms'] as num?)?.toDouble() ?? 0.0,
      vectorSearchLatencyMs: (json['vector_search_latency_ms'] as num?)?.toDouble() ?? 0.0,
      llmInferenceLatencyMs: (json['llm_inference_latency_ms'] as num?)?.toDouble() ?? 0.0,
      totalExecutionMs: (json['total_execution_ms'] as num?)?.toDouble() ?? 0.0,
      avgSimilarityScore: (json['avg_similarity_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hydration_latency_ms': hydrationLatencyMs,
      'vector_indexing_latency_ms': vectorIndexingLatencyMs,
      'vector_search_latency_ms': vectorSearchLatencyMs,
      'llm_inference_latency_ms': llmInferenceLatencyMs,
      'total_execution_ms': totalExecutionMs,
      'avg_similarity_score': avgSimilarityScore,
    };
  }
}

class ChunkMetadata {
  final String chunkId;
  final String text;
  final double similarityScore;

  ChunkMetadata({
    required this.chunkId,
    required this.text,
    required this.similarityScore,
  });

  factory ChunkMetadata.fromJson(Map<String, dynamic> json) {
    return ChunkMetadata(
      chunkId: json['chunk_id']?.toString() ?? '',
      text: json['text'] as String? ?? '',
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chunk_id': chunkId,
      'text': text,
      'similarity_score': similarityScore,
    };
  }
}

class OverviewCardModel {
  final String title;
  final String content;
  final String category;
  final String? subtitle;
  final String icon;
  final List<String> keyPoints;

  const OverviewCardModel({
    required this.title,
    required this.content,
    this.category = 'PROFILE',
    this.subtitle,
    this.icon = 'sparkles',
    this.keyPoints = const [],
  });

  factory OverviewCardModel.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['key_points'] as List<dynamic>?;
    var contentStr = (json['content'] as String? ?? '').trim();

    // Strip any raw json leak
    if (contentStr.startsWith('```') ||
        contentStr.startsWith('{') ||
        contentStr.startsWith('[') ||
        contentStr.contains('"category"') ||
        contentStr.contains("'category'")) {
      contentStr = '';
    }

    return OverviewCardModel(
      title: json['title'] as String? ?? 'Overview',
      content: contentStr,
      category: json['category'] as String? ?? 'PROFILE',
      subtitle: json['subtitle'] as String?,
      icon: json['icon'] as String? ?? 'sparkles',
      keyPoints: rawPoints?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'category': category,
      if (subtitle != null) 'subtitle': subtitle,
      'icon': icon,
      'key_points': keyPoints,
    };
  }
}

class RagQueryResponse {
  final String entity;
  final String answer;
  final List<String> imageUrls;
  final List<ChunkMetadata> retrievedChunks;
  final PerformanceTelemetry telemetry;
  final List<OverviewCardModel> overviewCards;
  final List<String> labels;

  RagQueryResponse({
    required this.entity,
    required this.answer,
    required this.imageUrls,
    required this.retrievedChunks,
    required this.telemetry,
    this.overviewCards = const [],
    this.labels = const [],
  });

  factory RagQueryResponse.fromJson(Map<String, dynamic> json) {
    final rawUrls = (json['image_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final List<String> sanitizedUrls = [];
    for (var url in rawUrls) {
      var trimmed = url.trim();
      if (trimmed.isEmpty) continue;

      // Fix missing or HTTP protocol
      if (trimmed.startsWith('//')) {
        trimmed = 'https:$trimmed';
      } else if (trimmed.startsWith('http://')) {
        trimmed = 'https://${trimmed.substring(7)}';
      }

      if (!sanitizedUrls.contains(trimmed)) {
        sanitizedUrls.add(trimmed);
      }
    }

    final String entityName = json['entity'] as String? ?? '';
    final String answerText = json['answer'] as String? ?? '';
    final List<ChunkMetadata> chunks = (json['retrieved_chunks'] as List<dynamic>?)
            ?.map((e) => ChunkMetadata.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Parse overview cards if returned from backend
    List<OverviewCardModel> parsedCards = [];
    if (json['overview_cards'] != null && json['overview_cards'] is List) {
      parsedCards = (json['overview_cards'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((item) => OverviewCardModel.fromJson(item))
          .toList();
    }

    // If backend did not supply at least 6 cards, synthesize 7 domain-specific cards
    if (parsedCards.length < 6) {
      parsedCards = _synthesizeCards(entityName, answerText, chunks);
    }

    final rawLabels = (json['labels'] as List<dynamic>?)?.map((e) => e.toString()).toList();
    final List<String> parsedLabels = (rawLabels != null && rawLabels.isNotEmpty)
        ? rawLabels
        : PersonaLabelService.getLabelsForPersona(entityName, answerText);

    return RagQueryResponse(
      entity: entityName,
      answer: answerText,
      imageUrls: sanitizedUrls,
      retrievedChunks: chunks,
      overviewCards: parsedCards,
      labels: parsedLabels,
      telemetry: json['telemetry'] != null
          ? PerformanceTelemetry.fromJson(json['telemetry'] as Map<String, dynamic>)
          : PerformanceTelemetry(
              hydrationLatencyMs: 0,
              vectorIndexingLatencyMs: 0,
              vectorSearchLatencyMs: 0,
              llmInferenceLatencyMs: 0,
              totalExecutionMs: 0,
              avgSimilarityScore: 0,
            ),
    );
  }

  static List<OverviewCardModel> _synthesizeCards(
    String entityName,
    String rawAnswer,
    List<ChunkMetadata> chunks,
  ) {
    final cleanName = entityName.isNotEmpty ? entityName : 'Persona';
    // 1. Attempt to decode cards directly from JSON if rawAnswer contains JSON
    if (rawAnswer.contains('{"cards"') || rawAnswer.contains('[{') || rawAnswer.contains('"title"')) {
      try {
        var cleanJsonStr = rawAnswer.trim();
        if (cleanJsonStr.startsWith('```')) {
          cleanJsonStr = cleanJsonStr.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
          cleanJsonStr = cleanJsonStr.replaceAll(RegExp(r'\s*```$'), '');
        }
        final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleanJsonStr);
        if (match != null) {
          final decoded = json.decode(match.group(0)!);
          final rawCards = decoded is Map ? (decoded['cards'] ?? decoded['overview_cards']) : decoded;
          if (rawCards is List && rawCards.isNotEmpty) {
            final List<OverviewCardModel> extracted = [];
            for (final item in rawCards) {
              if (item is Map<String, dynamic> && item.containsKey('title') && item.containsKey('content')) {
                final card = OverviewCardModel.fromJson(item);
                if (card.content.isNotEmpty) {
                  extracted.add(card);
                }
              }
            }
            if (extracted.length >= 4) {
              return extracted;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Strip any JSON fragments before splitting into natural text
    final cleanText = rawAnswer
        .replaceAll(RegExp(r'```(?:json)?[\s\S]*?```'), '')
        .replaceAll(RegExp(r'\{[\s\S]*?\}'), '')
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll('**', '')
        .replaceAll('*', '')
        .trim();

    final paragraphs = cleanText
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) =>
            p.length > 25 &&
            !p.startsWith('{') &&
            !p.startsWith('[') &&
            !p.startsWith('`') &&
            !p.contains('"category"') &&
            !p.contains("'category'"))
        .toList();

    // Collect additional snippet text from chunks if paragraphs are limited
    final List<String> allPool = [...paragraphs];
    for (final c in chunks) {
      final t = c.text.trim();
      if (t.length > 30 &&
          !t.startsWith('{') &&
          !t.startsWith('[') &&
          !t.contains('"category"') &&
          !allPool.contains(t)) {
        allPool.add(t);
      }
    }

    String getSection(int index, String fallback) {
      if (allPool.isNotEmpty && index < allPool.length) {
        final text = allPool[index];
        return text.length > 300 ? '${text.substring(0, 297)}...' : text;
      }
      return fallback;
    }

    final defaultIdentity = '$cleanName is an internationally celebrated figure recognized for exceptional artistry, cultural prominence, and enduring legacy.';
    final defaultOrigins = 'Emerging through focused early dedication, $cleanName cultivated distinctive strengths during their formative beginnings.';
    final defaultCareer = 'Throughout a landmark career, $cleanName achieved breakthrough milestones and delivered works celebrated worldwide.';
    final defaultSignature = 'Characterized by an unmistakable personal method and compelling presence, $cleanName redefined standards in their craft.';
    final defaultHonors = '$cleanName has earned significant accolades, prestigious recognition, and widespread acclaim across their career.';
    final defaultLegacy = '$cleanName leaves an indelible footprint on modern culture, inspiring future generations and colleagues across the globe.';
    final defaultTrivia = 'Beyond the spotlight, $cleanName is known for intriguing anecdotes, disciplined routines, and unexpected personal passions.';

    return [
      OverviewCardModel(
        title: 'Who is $cleanName?',
        content: getSection(0, defaultIdentity),
      ),
      OverviewCardModel(
        title: 'Origins & Early Life',
        content: getSection(1, defaultOrigins),
      ),
      OverviewCardModel(
        title: 'Career Breakthroughs',
        content: getSection(2, defaultCareer),
      ),
      OverviewCardModel(
        title: 'Signature Style & Craft',
        content: getSection(3, defaultSignature),
      ),
      OverviewCardModel(
        title: 'Accolades & Milestones',
        content: getSection(4, defaultHonors),
      ),
      OverviewCardModel(
        title: 'Cultural Impact & Legacy',
        content: getSection(5, defaultLegacy),
      ),
      OverviewCardModel(
        title: 'Fascinating Curiosities',
        content: getSection(6, defaultTrivia),
      ),
    ];
  }

  Map<String, dynamic> toJson() {
    return {
      'entity': entity,
      'answer': answer,
      'image_urls': imageUrls,
      'retrieved_chunks': retrievedChunks.map((e) => e.toJson()).toList(),
      'overview_cards': overviewCards.map((e) => e.toJson()).toList(),
      'telemetry': telemetry.toJson(),
    };
  }
}
