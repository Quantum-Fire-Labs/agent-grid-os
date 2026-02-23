module AgentsHelper
  def format_message_content(message)
    html = MarkdownHelper.to_html(message.content)
    names = message.conversation.users.pluck(:first_name) + [ message.conversation.agent.name ]
    if names.any?
      pattern = names.map { |n| Regexp.escape(n) }.join("|")
      html = html.gsub(/@(#{pattern})\b/) do
        "<span class=\"mention\">@#{$1}</span>"
      end
    end
    html.html_safe
  end
end
