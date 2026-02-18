class Providers::ToolCall
  attr_reader :id, :name, :arguments

  def initialize(id:, name:, arguments:)
    @id = id
    @name = name
    @arguments = arguments
  end

  def parsed_arguments
    JSON.parse(arguments)
  rescue JSON::ParserError
    {}
  end
end
