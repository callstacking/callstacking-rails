require 'securerandom'

class TimeBasedUUID
  EPOCH_OFFSET = 1468418800000  # A custom epoch, it could be the UNIX timestamp when the application was created (in milliseconds)
  MAX_INT8_VALUE = 9223372036854775807

  def self.generate
    # Get the current time in milliseconds
    current_time = (Time.now.to_f * 1000).to_i

    # Subtract the custom epoch to reduce the timestamp size
    timestamp = current_time - EPOCH_OFFSET

    # Generate a random 64-bit number using SecureRandom
    random_bits = SecureRandom.random_number(1 << 64)

    # Combine the timestamp and the random bits
    uuid = (timestamp << 64) | random_bits

    # Ensure the UUID fits into a PostgreSQL int8 column
    uuid = uuid % MAX_INT8_VALUE if uuid > MAX_INT8_VALUE

    uuid
  end
end