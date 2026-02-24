class Providers::ToolCall
  attr_reader :id, :name, :arguments

  def initialize(id:, name:, arguments:)
    @id = self.class.normalize_id(id)
    @name = name
    @arguments = arguments
  end

  def self.normalize_id(id)
    return id unless id
    return id if id.start_with?("call_")
    id.start_with?("fc_") ? id.sub("fc_", "call_") : "call_#{id}"
  end

  def parsed_arguments
    JSON.parse(arguments)
  rescue JSON::ParserError
    {}
  end
end
