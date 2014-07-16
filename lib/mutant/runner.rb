module Mutant
  # Runner baseclass
  class Runner
    include Adamantium::Flat, Concord.new(:env), Procto.call(:result)

    # Initialize object
    #
    # @return [undefined]
    #
    # @api private
    #
    def initialize(env)
      super

      @collector   = Collector.new(env)
      @mutex       = Mutex.new

      config.integration.setup

      progress(env)
      run

      @result = @collector.result.update(done: true)

      config.reporter.report(result)
    end

    # Return result
    #
    # @return [Result::Env]
    #
    # @api private
    #
    attr_reader :result

  private

    # Run mutation analysis
    #
    # @return [Report::Subject]
    #
    # @api private
    #
    def run
      Parallel.map(env.mutations, finish: method(:finish), start: method(:start)) do |mutation, index|
        run_mutation(mutation)
      end
    end

    # Handle started mutation
    #
    # @param [Mutation] mutation
    # @param [Fixnum] _index
    #
    # @return [undefined]
    #
    # @api private
    #
    def start(mutation, _index)
      @mutex.synchronize do
        @collector.start(mutation)
      end
    end

    # Handle finished mutation
    #
    # @param [Mutation] mutation
    # @param [Fixnum] index
    # @param [Object] result
    #
    # @return [undefined]
    #
    # @api private
    #
    def finish(mutation, index, result)
      return unless result.kind_of?(Mutant::Result::Mutation)

      test_results = result.test_results.zip(mutation.subject.tests).map do |test_result, test|
        test_result.update(test: test, mutation: mutation) if test_result
      end.compact

      @mutex.synchronize do
        @collector.finish(result.update(index: index, mutation: mutation, test_results: test_results))
        progress(@collector)
      end
    end

    # Run mutation
    #
    # @param [Mutation] mutation
    # @param [Fixnum] index
    #
    # @return [Report::Mutation]
    #
    # @api private
    #
    def run_mutation(mutation)
      Result::Mutation.compute do
        {
          index:        nil,
          mutation:     nil,
          test_results: kill_mutation(mutation)
        }
      end
    end

    # Kill mutation
    #
    # @param [Mutation] mutation
    #
    # @return [Array<Result::Test>]
    #
    # @api private
    #
    def kill_mutation(mutation)
      mutation.subject.tests.each_with_object([]) do |test, results|
        results << result = run_mutation_test(mutation, test)
        return results if mutation.killed_by?(result)
      end
    end

    # Return config
    #
    # @return [Config]
    #
    # @api private
    #
    def config
      env.config
    end

    # Report progress
    #
    # @param [Object] object
    #
    # @return [undefined]
    #
    # @api private
    #
    def progress(object)
      config.reporter.progress(object)
    end

    # Return test result
    #
    # @return [Report::Test]
    #
    # @api private
    #
    def run_mutation_test(mutation, test)
      time = Time.now
      config.isolation.call do
        mutation.insert
        test.run
      end
    rescue Isolation::Error => exception
      Result::Test.new(
        test:     nil,
        mutation: nil,
        runtime:  Time.now - time,
        output:   exception.message,
        passed:   false
      )
    end

  end # Runner
end # Mutant
