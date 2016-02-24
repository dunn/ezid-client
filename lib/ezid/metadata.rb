require "hashie"
require_relative "reserved_metadata"

module Ezid
  #
  # EZID metadata collection for an identifier.
  #
  # @api private
  #
  class Metadata < Hashie::Mash
    include ReservedMetadata

    # EZID metadata field/value separator
    ANVL_SEPARATOR = ": "
    # EZID metadata field value separator
    ELEMENT_VALUE_SEPARATOR = " | "
    # Characters to escape in element values on output to EZID
    # @see http://ezid.cdlib.org/doc/apidoc.html#request-response-bodies
    ESCAPE_VALUES_RE = /[%\r\n]/
    # Characters to escape in element names on output to EZID
    # @see http://ezid.cdlib.org/doc/apidoc.html#request-response-bodies
    ESCAPE_NAMES_RE = /[%:\r\n]/
    # Character sequence to unescape from EZID
    # @see http://ezid.cdlib.org/doc/apidoc.html#request-response-bodies
    UNESCAPE_RE = /%\h\h/
    # A comment line
    COMMENT_RE = /^#.*(\r?\n)?/
    # A line continuation
    LINE_CONTINUATION_RE = /\r?\n\s+/
    # A line ending
    LINE_ENDING_RE = /\r?\n/
    # @api private
    RESERVED_ALIASES = %w(
      coowners datacenter export owner ownergroup
      profile shadowedby shadows status target
    ).freeze

    def initialize(data={})
      super coerce(data)
    end

    def elements
      warn "[DEPRECATION] `elements` is deprecated and will be removed in ezid-client 2.0." \
           " Use the Ezid::Metadata instance itself instead."
      self
    end

    def created
      to_time(_created)
    end

    def updated
      to_time(_updated)
    end

    # Output metadata in EZID ANVL format
    # @see http://ezid.cdlib.org/doc/apidoc.html#request-response-bodies
    # @return [String] the ANVL output
    def to_anvl(include_readonly = true)
      hsh = to_h
      hsh.reject! { |k, v| READONLY.include?(k) } unless include_readonly
      lines = hsh.map do |name, value|
        element = [escape(ESCAPE_NAMES_RE, name), escape(ESCAPE_VALUES_RE, value)]
        element.join(ANVL_SEPARATOR)
      end
      lines.join("\n").force_encoding(Encoding::UTF_8)
    end

    def to_s
      to_anvl
    end

    protected

    # Overrides Hashie::Mash
    def convert_key(key)
      k = super
      if RESERVED_ALIASES.include?(k)
        "_#{k}"
      elsif k =~ /\A(dc|datacite|erc)_/
        k.sub(/_/, ".")
      else
        k
      end
    end

    private

    def to_time(value)
      time = value.to_i
      (time == 0) ? nil : Time.at(time).utc
    end

    # Coerce data into a Hash of elements
    def coerce(data)
      data.to_h
    rescue NoMethodError
      coerce_string(data)
    end

    # Escape string for sending to EZID host
    def escape(regexp, value)
      value.gsub(regexp) { |m| URI.encode_www_form_component(m.force_encoding(Encoding::UTF_8)) }
    end

    # Unescape value from EZID host (or other source)
    def unescape(value)
      value.gsub(UNESCAPE_RE) { |m| URI.decode_www_form_component(m) }
    end

    # Coerce a string of metadata (e.g., from EZID host) into a Hash
    # @note EZID host does not send comments or line continuations.
    def coerce_string(data)
      data.gsub!(COMMENT_RE, "")
      data.gsub!(LINE_CONTINUATION_RE, " ")
      data.split(LINE_ENDING_RE).each_with_object({}) do |line, memo|
        element, value = line.split(ANVL_SEPARATOR, 2)
        memo[unescape(element.strip)] = unescape(value.strip)
      end
    end

  end
end
