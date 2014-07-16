require 'spec_helper'

class Double
  include Concord.new(:name, :attributes)

  def self.new(name, attributes = {})
    super
  end

  def update(_attributes)
    self
  end

  def method_missing(name, *arguments)
    super unless attributes.key?(name)
    fail "Arguments provided for #{name}" if arguments.any?
    attributes.fetch(name)
  end
end

# FIXME: This is not even close to a mutation covering spec.
describe Mutant::Runner do
  let(:object) { described_class.new(env) }

  let(:reporter) { Mutant::Reporter::Trace.new                        }
  let(:config)   { Mutant::Config::DEFAULT.update(reporter: reporter, isolation: Mutant::Isolation::None) }
  let(:subjects) { [subject_a, subject_b]                             }

  let(:subject_a) { Double.new('Subject A', mutations: mutations_a, tests: subject_a_tests) }
  let(:subject_b) { Double.new('Subject B', mutations: mutations_b) }

  let(:subject_a_tests) { [test_a1, test_a2] }

  let(:env) do
    subjects = self.subjects
    Class.new(Mutant::Env) do
      define_method(:subjects) { subjects }
    end.new(config)
  end

  let(:mutations_a) { [mutation_a1, mutation_a2] }
  let(:mutations_b) { [] }

  let(:mutation_a1) { Double.new('Mutation A1') }
  let(:mutation_a2) { Double.new('Mutation A2') }

  let(:test_a1) { Double.new('Test A1') }
  let(:test_a2) { Double.new('Test A2') }

  let(:test_report_a1) { Double.new('Test Report A1') }

  before do
    allow(mutation_a1).to receive(:subject).and_return(subject_a)
    allow(mutation_a1).to receive(:insert)
    allow(mutation_a2).to receive(:subject).and_return(subject_a)
    allow(mutation_a2).to receive(:insert)
    allow(test_a1).to receive(:run).and_return(test_report_a1)
    allow(mutation_a1).to receive(:killed_by?).with(test_report_a1).and_return(true)
    allow(mutation_a2).to receive(:killed_by?).with(test_report_a1).and_return(true)
  end

  before do
    time = Time.at(0)
    allow(Time).to receive(:now).and_return(time)
  end

  let(:expected_subject_results) do
    [
      Mutant::Result::Subject.new(
        subject:          subject_a,
        mutation_results: [
          Mutant::Result::Mutation.new(
            index:        0,
            mutation:     mutation_a1,
            runtime:      0.0,
            test_results: [test_report_a1]
          ),
          Mutant::Result::Mutation.new(
            index:        1,
            mutation:     mutation_a2,
            runtime:      0.0,
            test_results: [test_report_a1]
          )
        ],
        runtime:          0.0
      ),
      Mutant::Result::Subject.new(
        subject:          subject_b,
        mutation_results: [],
        runtime:          0.0
      )
    ]
  end

  describe '#result' do
    let(:expected_result) do
      Mutant::Result::Env.new(
        env:             env,
        runtime:         0.0,
        subject_results: expected_subject_results
      )
    end

    context 'on normal execution' do
      subject { object.result }

      its(:env) { should be(env) }
      it {
        subject.subject_results.zip(expected_subject_results) do |left, right|
          unless left == right
            expect(left).to eql(right)
          end
        end
        # should eql(expected_result)
      }

    # it 'reports result' do
    #   subject
    #   p config.reporter.report_calls.first.eql?(expected_result)
    #   # expect { subject }.to change { config.reporter.report_calls }.from([]).to([expected_result])
    # end
    end

    skip 'when isolation raises error' do
      subject { object.result }

      its(:env)             { should be(env)                       }
      its(:subject_results) { should eql(expected_subject_results) }

      it { should eql(expected_result) }

      before do
        expect(Mutant::Isolation::None).to receive(:call)
          .twice
          .and_raise(Mutant::Isolation::Error.new('test-exception-message'))

        expect(Mutant::Result::Test).to receive(:new).with(
          test:     test_a1,
          mutation: mutation_a1,
          runtime:  0.0,
          output:   'test-exception-message',
          passed:   false
        ).and_return(test_report_a1)
        expect(Mutant::Result::Test).to receive(:new).with(
          test:     test_a1,
          mutation: mutation_a2,
          runtime:  0.0,
          output:   'test-exception-message',
          passed:   false
        ).and_return(test_report_a1)
      end

    end
  end
end
