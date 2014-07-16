module Mutant
  class Reporter
    class CLI
      class Progress
        class Collector < self

          handle(Mutant::Runner::Collector)

          # Print progress for collector
          #
          # @return [self]
          #
          # @api private
          #
          def run
            clear
            visit(object.env)
            CLI::Report::Env.run(output, object.result)
            active_subject_results = object.active_subject_results
            info('Active Subjects: %d', active_subject_results.length)
            visit_collection(active_subject_results)
            self
          end

        end # Collector
      end # Progress
    end # CLI
  end # Reporter
end # Mutant
