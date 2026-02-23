class Agent::ReplyJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(thread, agent: nil, tts_enabled: false)
    if thread.is_a?(Chat)
      thread.generate_agent_reply(agent: agent, tts_enabled: tts_enabled)
    else
      thread.generate_agent_reply(tts_enabled: tts_enabled)
    end
  end
end
