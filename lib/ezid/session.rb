require "uri"
require "net/http"

require_relative "request"

module Ezid
  class Session

    attr_reader :cookie

    def initialize(response=nil)
      open(response) if response
    end

    def inspect
      super.sub(/@cookie="[^\"]+"/, "OPEN")
    end

    def open(response)
      # XXX raise exception if no cookie?
      @cookie = response.cookie if response.cookie
    end

    def close
      @cookie = nil
    end

    def closed?
      cookie.nil?
    end
    
    def open?
      !closed?
    end

  end
end
