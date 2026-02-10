# Custom UUID attribute type for MySQL binary storage with base36 string representation.
# URLs use hyphenated format (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).
module ActiveRecord
  module Type
    class Uuid < Binary
      BASE36_LENGTH = 25 # 36^25 > 2^128
      HYPHENATED_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

      class << self
        def generate
          uuid = SecureRandom.uuid_v7
          hex = uuid.delete("-")
          hex_to_base36(hex)
        end

        def hex_to_base36(hex)
          hex.to_i(16).to_s(36).rjust(BASE36_LENGTH, "0")
        end

        def base36_to_hex(base36)
          base36.to_s.to_i(36).to_s(16).rjust(32, "0")
        end

        def hex_to_hyphenated(hex)
          h = hex.to_s.downcase.delete("^0-9a-f").rjust(32, "0")[0, 32]
          "#{h[0, 8]}-#{h[8, 4]}-#{h[12, 4]}-#{h[16, 4]}-#{h[20, 12]}"
        end

        def hyphenated_to_hex(str)
          str.to_s.delete("-").downcase.rjust(32, "0")[0, 32]
        end

        # Internal id (base36) → URL segment (hyphenated)
        def to_url_format(base36)
          return base36 if base36.blank?
          hex = base36_to_hex(base36)
          hex_to_hyphenated(hex)
        end

        # URL segment (hyphenated) → internal id (base36)
        def from_url_format(hyphenated)
          return hyphenated if hyphenated.blank?
          hex = hyphenated_to_hex(hyphenated)
          hex_to_base36(hex)
        end
      end

      def serialize(value)
        return unless value

        normalized = value.to_s.match?(HYPHENATED_PATTERN) ? self.class.from_url_format(value) : value
        binary = self.class.base36_to_hex(normalized).scan(/../).map(&:hex).pack("C*")
        super(binary)
      end

      def deserialize(value)
        return unless value

        hex = value.to_s.unpack1("H*")
        self.class.hex_to_base36(hex)
      end

      def cast(value)
        return value if value.blank?
        return self.class.from_url_format(value) if value.to_s.match?(HYPHENATED_PATTERN)
        value
      end
    end
  end
end

# Register the UUID type for Trilogy (MySQL) and SQLite3 adapters
ActiveRecord::Type.register(:uuid, ActiveRecord::Type::Uuid, adapter: :trilogy)
ActiveRecord::Type.register(:uuid, ActiveRecord::Type::Uuid, adapter: :sqlite3)
