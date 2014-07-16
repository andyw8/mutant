module Mutant
  class Reporter
    # Reporter that reports in human readable format
    class CLI < self
      include Concord.new(:output)

      # Rate per second progress report fires
      OUTPUT_RATE = 1.0 / 20

      # Initialize object
      #
      # @return [undefined]
      #
      # @api private
      #
      def initialize(*)
        super
        @last = nil
      end

      # Report progress object
      #
      # @param [Object] object
      #
      # @return [self]
      #
      # @api private
      #
      def progress(object)
        throttle do
          Progress.run(output, object)
        end

        self
      end

      # Report warning
      #
      # @param [String] message
      #
      # @return [self]
      #
      # @api private
      #
      def warn(message)
        output.puts(message)
        self
      end

      # Report object
      #
      # @param [Object] object
      #
      # @return [self]
      #
      # @api private
      #
      def report(object)
        Report.run(output, object)
        self
      end

      private

      # Call block throttled
      #
      # @return [undefined]
      #
      # @api private
      #
      def throttle
        now = Time.now
        if @last && now - @last >= OUTPUT_RATE
          yield
        end
        @last = now
      end

    end # CLI
  end # Reporter
end # Mutant
