class Providers::Client
  attr_reader :provider

  def initialize(provider)
    @provider = provider
  end

  def self.display_name
    raise NotImplementedError
  end

  def self.models(_key_chain)
    []
  end

  def connected?(agent: nil)
    raise NotImplementedError
  end

  def chat(messages:, model: nil, tools: nil, &on_token)
    raise NotImplementedError
  end

  private
    def resolved_model(model)
      model || provider.model
    end
end
