module AgentsHelper
  def format_message_content(message)
    escaped = h(message.content)
    names = message.conversation.users.pluck(:first_name) + [message.conversation.agent.name]
    if names.any?
      pattern = names.map { |n| Regexp.escape(n) }.join("|")
      escaped = escaped.gsub(/@(#{pattern})\b/) do
        "<span class=\"mention\">@#{$1}</span>"
      end
    end
    simple_format(escaped)
  end
end
