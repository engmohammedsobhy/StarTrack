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
      chunkId: json['chunk_id'] as String? ?? '',
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

class RagQueryResponse {
  final String entity;
  final String answer;
  final List<String> imageUrls;
  final List<ChunkMetadata> retrievedChunks;
  final PerformanceTelemetry telemetry;

  RagQueryResponse({
    required this.entity,
    required this.answer,
    required this.imageUrls,
    required this.retrievedChunks,
    required this.telemetry,
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

    return RagQueryResponse(
      entity: json['entity'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      imageUrls: sanitizedUrls,
      retrievedChunks: (json['retrieved_chunks'] as List<dynamic>?)
              ?.map((e) => ChunkMetadata.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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

  Map<String, dynamic> toJson() {
    return {
      'entity': entity,
      'answer': answer,
      'image_urls': imageUrls,
      'retrieved_chunks': retrievedChunks.map((e) => e.toJson()).toList(),
      'telemetry': telemetry.toJson(),
    };
  }
}
