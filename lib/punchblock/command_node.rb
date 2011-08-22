require 'state_machine'

module Punchblock
  class CommandNode < RayoNode
    def initialize(*args)
      super
      @response = FutureResource.new
    end

    state_machine :state, :initial => :new do
      event :request do
        transition :new => :requested
      end

      event :execute do
        transition :requested => :executing
      end

      event :complete do
        transition :executing => :complete
      end
    end

    def write_attr(*args)
      raise StandardError, "Cannot alter attributes of a requested command" unless new?
      super
    end

    def response(timeout = nil)
      @response.resource timeout
    end

    def response=(other)
      @response.resource = other
      execute!
    end
  end # CommandNode
end # Punchblock
