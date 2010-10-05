require 'htmlentities'

module MiniFB
  module Utilities

    def htmlentitydecoder(value)
      case value
      when String
        htmlentities.decode(value)
      when Hash
        value.dup.tap do |hash|
          hash.each {|k,v| hash[k] = htmlentitydecoder(v) }
        end
      when Array
        value.map {|v| htmlentitydecoder(v) }
      else
        value
      end
    end

    def htmlentities
      @coder ||= HTMLEntities.new
    end

  end
end
