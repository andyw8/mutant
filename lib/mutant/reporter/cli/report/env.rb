module Mutant
  class Reporter
    class CLI
      class Report

        # Env result reporter
        class Env < self

          handle(Result::Env)

          delegate(
            :coverage, :failed_subject_results, :amount_subjects, :amount_mutations,
            :amount_mutations_alive, :amount_mutations_killed, :runtime, :killtime, :overhead, :env
          )

          # Run printer
          #
          # @return [self]
          #
          # @api private
          #
          def run
            if object.done
              clear
              visit_collection(failed_subject_results)
            end
            info 'Kills:     %s',        amount_mutations_killed
            info 'Alive:     %s',        amount_mutations_alive
            info 'Runtime:   %0.2fs',    runtime
            info 'Killtime:  %0.2fs',    killtime
            info 'Overhead:  %0.2f%%',   overhead_percent
            status 'Coverage:  %0.2f%%', coverage_percent
            status 'Expected:  %0.2f%%', env.config.expected_coverage
            self
          end

        private

          # Return coverage percent
          #
          # @return [Float]
          #
          # @api private
          #
          def coverage_percent
            coverage * 100
          end

          # Return overhead percent
          #
          # @return [Float]
          #
          # @api private
          #
          def overhead_percent
            (overhead / killtime) * 100
          end

        end # Env
      end # Report
    end # CLI
  end # Reporter
end # Mutant
