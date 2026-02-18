class Agent::MemoryRecall
  def initialize(agent)
    @agent = agent
    @embedding = Agent::Embedding.new(agent.account)
  end

  def recall(query, top_n: 10, min_score: 0.3)
    unless @embedding.available?
      return @agent.memories.active.order(created_at: :desc).limit(top_n)
    end

    vec = @embedding.embed(query)
    unless vec
      return @agent.memories.active.order(created_at: :desc).limit(top_n)
    end

    candidates = @agent.memories.active.with_embedding.recent(90).limit(500)
    scored = candidates.filter_map do |memory|
      mvec = memory.embedding_vector
      score = cosine_similarity(vec, mvec)
      { memory: memory, score: score } if score >= min_score
    end

    results = scored.sort_by { |r| -r[:score] }.first(top_n)
    results.each { |r| r[:memory].track_access! }
    results
  end

  def build_seed(conversation, current_message)
    recent = conversation.messages
      .where(compacted_at: nil)
      .where.not(role: "system")
      .order(created_at: :desc)
      .limit(10)
      .reverse
      .map(&:content)

    text = (recent + [ current_message ]).compact.join("\n")
    text.truncate(2000)
  end

  def format_memories(results)
    lines = results.map do |item|
      if item.is_a?(Hash)
        "- [id:#{item[:memory].id}] #{item[:memory].content}"
      else
        "- [id:#{item.id}] #{item.content}"
      end
    end
    lines.join("\n")
  end

  private

    def cosine_similarity(a, b)
      return 0.0 if a.nil? || b.nil? || a.length != b.length

      dot = 0.0
      norm_a = 0.0
      norm_b = 0.0

      a.length.times do |i|
        dot += a[i] * b[i]
        norm_a += a[i] * a[i]
        norm_b += b[i] * b[i]
      end

      denominator = Math.sqrt(norm_a) * Math.sqrt(norm_b)
      denominator.zero? ? 0.0 : dot / denominator
    end
end
