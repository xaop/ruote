
#
# testing ruote
#
# Sat Jan 24 22:40:35 JST 2009
#

require File.expand_path('../base', __FILE__)


class EftSequenceTest < Test::Unit::TestCase
  include FunctionalBase

  def test_empty_sequence

    pdef = Ruote.process_definition :name => 'test' do
      sequence do
      end
    end

    #noisy

    assert_trace('', pdef)
  end

  def test_a_b_sequence

    pdef = Ruote.process_definition :name => 'test' do
      sequence do
        echo 'a'
        echo 'b'
      end
    end

    #noisy

    assert_trace("a\nb", pdef)
  end

  def test_alice_bob_sequence

    pdef = Ruote.process_definition :name => 'test' do
      sequence do
        participant :ref => 'alice'
        participant :ref => 'bob'
      end
    end

    @dashboard.register_participant '.+' do |workitem|
      context.tracer << workitem.participant_name + "\n"
    end

    #noisy

    assert_trace("alice\nbob", pdef)
  end
end

