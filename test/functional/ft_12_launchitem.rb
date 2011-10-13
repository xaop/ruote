
#
# testing ruote
#
# Tue Jun 23 10:55:16 JST 2009
#

require File.expand_path('../base', __FILE__)


class FtLaunchitemTest < Test::Unit::TestCase
  include FunctionalBase

  def test_launch

    pdef = Ruote.process_definition do
      alpha
    end

    @dashboard.register_participant :alpha do |workitem|
      stash[:fields] = workitem.fields
      @tracer << 'a'
      nil
    end

    #noisy

    wfid = @dashboard.launch(pdef, 'a' => 0, 'b' => 1)
    wait_for(wfid)

    assert_equal('a', @tracer.to_s)

    @dashboard.context.stash[:fields].delete('__result__')

    assert_not_nil(
      @dashboard.context.stash[:fields].delete('dispatched_at'))

    assert_equal(
      {"a"=>0, "b"=>1, "params"=>{"ref"=>"alpha"}},
      @dashboard.context.stash[:fields])
  end
end

