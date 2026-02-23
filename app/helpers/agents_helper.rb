module AgentsHelper
  def format_message_content(message)
    html = MarkdownHelper.to_html(message.content)
    chat = message.chat
    tokens = []

    if chat
      tokens.concat(chat.users.map { |u| "#{u.first_name}#{u.last_name}".gsub(/[^A-Za-z0-9]/, "") })
      tokens.concat(chat.agents.map { |a| a.name.gsub(/[^A-Za-z0-9]/, "") })
    end

    if tokens.any?
      pattern = tokens.map { |n| Regexp.escape(n) }.join("|")
      html = html.gsub(/@(#{pattern})\b/) do
        "<span class=\"mention\">@#{$1}</span>"
      end
    end
    html.html_safe
  end
end
