class Agent::AutoDemotion
  SOFT_CAP = 500
  GRACE_PERIOD = 7.days
  BATCH_LIMIT = 200

  def initialize(agent)
    @agent = agent
  end

  def run
    active_count = @agent.memories.active.count
    return if active_count <= SOFT_CAP

    excess = active_count - SOFT_CAP
    demote_count = [excess, BATCH_LIMIT].min

    candidates = @agent.memories.active
      .where(created_at: ..GRACE_PERIOD.ago)
      .to_a

    scored = candidates.map do |memory|
      { memory: memory, score: demotion_score(memory) }
    end

    scored.sort_by! { |r| -r[:score] }
    scored.first(demote_count).each do |r|
      r[:memory].demote(reason: "auto_demotion")
    end
  rescue => e
    Rails.logger.error("Agent::AutoDemotion failed: #{e.message}")
  end

  private

    def demotion_score(memory)
      age_days = (Time.current - memory.created_at) / 1.day
      normalized_age = [age_days / 365.0, 1.0].min
      normalized_access = [memory.access_count / 10.0, 1.0].min

      normalized_age + (1 - memory.importance) + (1 - normalized_access)
    end
end
