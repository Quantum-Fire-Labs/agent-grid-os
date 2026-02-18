class Providers::Response
  attr_reader :content, :tool_calls, :usage

  def initialize(content:, tool_calls: [], usage: {})
    @content = content
    @tool_calls = tool_calls
    @usage = usage
  end

  def tool_calls?
    tool_calls.any?
  end
end
