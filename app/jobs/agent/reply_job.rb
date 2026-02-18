class Agent::ReplyJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(conversation, tts_enabled: false)
    conversation.generate_agent_reply(tts_enabled: tts_enabled)
  end
end
