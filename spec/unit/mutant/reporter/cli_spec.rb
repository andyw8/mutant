require 'spec_helper'

describe Mutant::Reporter::CLI do
  let(:object) { described_class.new(output) }
  let(:output) { StringIO.new }

  def contents
    output.rewind
    output.read
  end

  describe '#warn' do
    subject { object.warn(message) }

    let(:message) { 'message' }

    it 'writes message to output' do
      expect { subject }.to change { contents }.from('').to("message\n")
    end
  end

  let(:result) do
    Mutant::Result::Env.new(
      done:            true,
      env:             env,
      runtime:         1.1,
      subject_results: subject_results
    )
  end

  let(:env) do
    double(
      'Env',
      class: Mutant::Env,
      matchable_scopes: matchable_scopes,
      config: config,
      subjects: subjects,
      mutations: subjects.flat_map(&:mutations)
    )
  end

  let(:config)           { Mutant::Config::DEFAULT                }
  let(:mutation_class)   { Mutant::Mutation::Evil                 }
  let(:matchable_scopes) { double('Matchable Scopes', length: 10) }

  before do
    allow(mutation).to receive(:subject).and_return(_subject)
  end

  let(:mutation) do
    double(
      'Mutation',
      identification:  'mutation_id',
      class:           mutation_class,
      original_source: 'true',
      source:          mutation_source
    )
  end

  let(:mutation_source) { 'false' }

  let(:_subject) do
    double(
      'Subject',
      class:          Mutant::Subject,
      node:           s(:true),
      identification: 'subject_id',
      mutations:      [mutation],
      tests: [
        double('Test', identification: 'test_id')
      ]
    )
  end

  let(:test_results) do
    [
      double(
        'Test Result',
        class: Mutant::Result::Test,
        test: _subject.tests.first,
        runtime: 1.0,
        output: 'test-output',
        success?: mutation_result_success
      )
    ]
  end

  let(:subject_results) do
    [
      Mutant::Result::Subject.new(
        subject: _subject,
        runtime: 1.0,
        mutation_results: [
          double(
            'Mutation Result',
            class: Mutant::Result::Mutation,
            mutation: mutation,
            killtime: 0.5,
            success?: mutation_result_success,
            test_results: test_results,
            failed_test_results: mutation_result_success ? [] : test_results
          )
        ]
      )
    ]
  end

  let(:subjects) { [_subject] }

  describe '#progress' do
    subject { object.progress(collector) }

    let(:config) { Mutant::Config::DEFAULT.update(includes: %w(include-dir), requires: %w(require-name)) }

    let(:collector) do
      collector = Mutant::Runner::Collector.new(env)
    end

    let(:mutation_result_success) { true }

    it 'writes report to output' do
      subject
      expect(contents).to eql(strip_indent(<<-REPORT))
        Mutant configuration:
        Matcher:            #<Mutant::Matcher::Config match_expressions=[] subject_ignores=[] subject_selects=[]>
        Integration:        null
        Expect Coverage:    100.00%
        Includes:           ["include-dir"]
        Requires:           ["require-name"]
        Available Subjects: 10
        Subjects:           1
        Mutations:          1
        subject_id mutations: 1
        - test_id
        .
        (01/01) 100% - killtime: 0.50s runtime: 1.00s overhead: 0.50s
      REPORT
    end
  end

  describe '#report' do
    subject { object.report(result) }

    context 'with subjects' do

      context 'and full covergage' do
        let(:mutation_result_success) { true }

        it 'writes report to output' do
          subject
          expect(contents).to eql(strip_indent(<<-REPORT))
            Subjects:  1
            Mutations: 1
            Kills:     1
            Alive:     0
            Runtime:   1.10s
            Killtime:  0.50s
            Overhead:  120.00%
            Coverage:  100.00%
            Expected:  100.00%
          REPORT
        end
      end

      context 'and partial covergage' do
        let(:mutation_result_success) { false }

        context 'on evil mutation' do
          context 'with a diff' do
            it 'writes report to output' do
              subject
              expect(contents).to eql(strip_indent(<<-REPORT))
                subject_id
                - test_id
                mutation_id
                @@ -1,2 +1,2 @@
                -true
                +false
                -----------------------
                Subjects:  1
                Mutations: 1
                Kills:     0
                Alive:     1
                Runtime:   1.10s
                Killtime:  0.50s
                Overhead:  120.00%
                Coverage:  0.00%
                Expected:  100.00%
              REPORT
            end
          end

          context 'without a diff' do
            let(:mutation_source) { 'true' }

            it 'writes report to output' do
              subject
              expect(contents).to eql(strip_indent(<<-REPORT))
                subject_id
                - test_id
                mutation_id
                BUG: Mutation NOT resulted in exactly one diff. Please report a reproduction!
                -----------------------
                Subjects:  1
                Mutations: 1
                Kills:     0
                Alive:     1
                Runtime:   1.10s
                Killtime:  0.50s
                Overhead:  120.00%
                Coverage:  0.00%
                Expected:  100.00%
              REPORT
            end
          end
        end

        context 'on neutral mutation' do
          let(:mutation_class)  { Mutant::Mutation::Neutral }
          let(:mutation_source) { 'true' }

          it 'writes report to output' do
            subject
            expect(contents).to eql(strip_indent(<<-REPORT))
              subject_id
              - test_id
              mutation_id
              --- Neutral failure ---
              Original code was inserted unmutated. And the test did NOT PASS.
              Your tests do not pass initially or you found a bug in mutant / unparser.
              Subject AST:
              (true)
              Unparsed Source:
              true
              Test Reports: 1
              - test_id / runtime: 1.0
              Test Output:
              test-output
              -----------------------
              Subjects:  1
              Mutations: 1
              Kills:     0
              Alive:     1
              Runtime:   1.10s
              Killtime:  0.50s
              Overhead:  120.00%
              Coverage:  0.00%
              Expected:  100.00%
            REPORT
          end
        end

        context 'on neutral mutation' do
          let(:mutation_class) { Mutant::Mutation::Noop }

          it 'writes report to output' do
            subject
            expect(contents).to eql(strip_indent(<<-REPORT))
              subject_id
              - test_id
              mutation_id
              ---- Noop failure -----
              No code was inserted. And the test did NOT PASS.
              This is typically a problem of your specs not passing unmutated.
              Test Reports: 1
              - test_id / runtime: 1.0
              Test Output:
              test-output
              -----------------------
              Subjects:  1
              Mutations: 1
              Kills:     0
              Alive:     1
              Runtime:   1.10s
              Killtime:  0.50s
              Overhead:  120.00%
              Coverage:  0.00%
              Expected:  100.00%
            REPORT
          end
        end
      end
    end

    context 'without subjects' do
      let(:subjects)        { [] }
      let(:subject_results) { [] }

      it 'writes report to output' do
        subject
        expect(contents).to eql(strip_indent(<<-REPORT))
          Subjects:  0
          Mutations: 0
          Kills:     0
          Alive:     0
          Runtime:   1.10s
          Killtime:  0.00s
          Overhead:  Inf%
          Coverage:  0.00%
          Expected:  100.00%
        REPORT
      end
    end
  end
end
