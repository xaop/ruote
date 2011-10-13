
#
# testing ruote
#
# Mon Jun 29 18:34:02 JST 2009
#

require File.expand_path('../base', __FILE__)

require 'ruote/part/no_op_participant'


class EftCursorTest < Test::Unit::TestCase
  include FunctionalBase

  def test_empty_cursor

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
      end
    end

    #noisy

    assert_trace('', pdef)
  end

  def test_cursor

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
        echo 'a'
        echo 'b'
      end
    end

    #noisy

    assert_trace(%w[ a b ], pdef)
  end

  def test_skip

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
        echo 'a'
        skip 1
        echo 'b'
        echo 'c'
      end
    end

    #noisy

    assert_trace(%w[ a c ], pdef)
  end

  def test_break

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
        echo 'a'
        _break
        echo 'b'
      end
    end

    #noisy

    assert_trace('a', pdef)
  end

  def test_stop

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
        echo 'a'
        stop
        echo 'b'
      end
    end

    #noisy

    assert_trace('a', pdef)
  end

  def test_over

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
        echo 'a'
        over
        echo 'b'
      end
    end

    #noisy

    assert_trace('a', pdef)
  end

  def test_jump_to_tag

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
        echo 'a'
        jump :to => 'c'
        echo 'b'
        echo 'c', :tag => 'c'
      end
    end

    #noisy

    assert_trace(%w[ a c ], pdef)
  end

  def test_jump_to_variable_tag

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
        echo 'a'
        jump :to => 'd'
        echo 'b'
        set :var => 'v0', :val => 'd'
        jump :to => 'd'
        echo 'c'
        echo 'd', :tag => '${v:v0}'
      end
    end

    #noisy

    assert_trace(%w[ a b d ], pdef)
  end

  def test_rewind_if

    pdef = Ruote.process_definition :name => 'test' do
      sequence do
        set :f => 'counter', :val => 0
        set :f => 'rewind', :val => false
        cursor :rewind_if => '${f:rewind}' do
          alpha
        end
      end
    end

    @dashboard.register_participant :alpha do |workitem|
      workitem.fields['counter'] += 1
      workitem.fields['rewind'] = workitem.fields['counter'] < 5
      @tracer << "a\n"
    end

    #noisy

    assert_trace(%w[ a ] * 5, pdef)
  end

  def test_jump_to

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
        author
        reviewer
        jump :to => 'author', :if => '${not_ok}'
        publisher
      end
    end

    @dashboard.register_participant :author do |workitem|
      @tracer << "a\n"
      stash[:count] ||= 0
      stash[:count] += 1
    end
    @dashboard.register_participant :reviewer do |workitem|
      @tracer << "r\n"
      workitem.fields['not_ok'] = (stash[:count] < 3)
    end
    @dashboard.register_participant :publisher do |workitem|
      @tracer << "p\n"
    end

    #noisy

    assert_trace %w[ a r a r a r p ], pdef
      # ARP nostalgy....
  end

  def test_deep_rewind

    pdef = Ruote.process_definition :name => 'test' do
      cursor do
        sequence do
          echo 'a'
          rewind
          echo 'b'
        end
      end
    end

    #noisy

    wfid = @dashboard.launch(pdef)

    wait_for(14)

    #p @tracer.to_s

    assert_equal [ 'a', 'a' ], @tracer.to_a[0..1]
  end

  def test_external_break

    pdef = Ruote.process_definition :name => 'test' do
      concurrence do
        repeat :tag => 'cu' do
          echo 'a'
        end
        sequence do
          wait '1.1'
          stop :ref => 'cu'
          alpha
        end
      end
    end

    @dashboard.register_participant :alpha, Ruote::NoOpParticipant

    #noisy

    wfid = @dashboard.launch(pdef)

    wait_for(:alpha)
    wait_for(wfid)

    #p @tracer.to_s
    assert_equal %w[ a a a ], @tracer.to_a[0, 3]

    assert_nil @dashboard.process(wfid)
  end

  def test_nested_break

    pdef = Ruote.process_definition :name => 'test' do
      cursor :tag => 'cu' do
        echo 'a'
        cursor do
          echo 'b'
          _break :ref => 'cu'
          echo 'c'
        end
        echo 'd'
      end
    end

    #noisy

    assert_trace %w[ a b ], pdef
  end

  def test_break_if

    pdef = Ruote.process_definition :name => 'test' do
      cursor :break_if => 'true' do
        echo 'c'
      end
      echo 'done.'
    end

    #noisy

    assert_trace 'done.', pdef
  end

  def test_over_unless

    pdef = Ruote.process_definition :name => 'test' do
      cursor :over_unless => 'false' do
        echo 'c'
      end
      echo 'done.'
    end

    #noisy

    assert_trace 'done.', pdef
  end

  class Alpha
    include Ruote::LocalParticipant
    def consume(workitem)
      workitem.command = 'break'
      reply_to_engine(workitem)
    end
    def cancel(fei, flavour)
    end
  end
  class Bravo < Alpha
    def consume(workitem)
      workitem.command = 'skip 1'
      reply_to_engine(workitem)
    end
  end

  def test_cursor_and_workitem

    pdef = Ruote.define do
      cursor do
        echo 'in'
        bravo
        echo 'mid'
        alpha
        echo 'out'
      end
      echo 'done.'
    end

    #noisy

    @dashboard.register do
      alpha EftCursorTest::Alpha
      bravo EftCursorTest::Bravo
    end

    assert_trace "in\ndone.", pdef
  end

  def test_cursor_with_lonely_rewind

    pdef = Ruote.define do
      cursor do
        rewind
      end
    end

    #@dashboard.noisy = true

    wfid = @dashboard.launch(pdef)

    @dashboard.wait_for(9)

    assert_not_nil @dashboard.process(wfid)
  end

  class Charly
    include Ruote::LocalParticipant
    def initialize(opts)
      @opts = opts
    end
    def consume(workitem)
      workitem.command = @opts['command']
      reply_to_engine(workitem)
    end
    def cancel(fei, flavour)
    end
  end

  JUMP_DEF = Ruote.process_definition do
    cursor do
      echo 'top'
      charly
      echo 'middle'
      delta
      echo 'bottom'
    end
  end

  def test_workitem_command_and_jump_array

    #noisy

    @dashboard.register do
      charly EftCursorTest::Charly, 'command' => [ 'jump', 'delta' ]
      catchall Ruote::NoOpParticipant
    end

    assert_trace "top\nbottom", JUMP_DEF
  end

  def test_workitem_command_and_jump_string

    #noisy

    @dashboard.register do
      charly EftCursorTest::Charly, 'command' => 'jump delta'
      catchall Ruote::NoOpParticipant
    end

    assert_trace "top\nbottom", JUMP_DEF
  end

  def test_workitem_command_and_jump_to_string

    #noisy

    @dashboard.register do
      charly EftCursorTest::Charly, 'command' => 'jump to delta'
      catchall Ruote::NoOpParticipant
    end

    assert_trace "top\nbottom", JUMP_DEF
  end

  def test_reset

    pdef = Ruote.define do
      cursor do
        alpha
        set 'f:toto' => 'oops'
        reset
      end
    end

    @dashboard.register { catchall }

    #@dashboard.noisy = true

    wfid = @dashboard.launch(pdef)
    @dashboard.wait_for(:alpha)

    assert_nil @dashboard.storage_participant.first.fields['toto']

    @dashboard.storage_participant.proceed(@dashboard.storage_participant.first)
    @dashboard.wait_for(:alpha)

    assert_nil @dashboard.storage_participant.first.fields['toto']
  end

  def test_reset_if

    pdef = Ruote.define do
      cursor :reset_if => '${f:reset} == true' do
        alpha
        set 'f:toto' => 'oops'
        set 'f:reset' => true
      end
    end

    @dashboard.register { catchall }

    #@dashboard.noisy = true

    wfid = @dashboard.launch(pdef)
    @dashboard.wait_for(:alpha)

    assert_nil @dashboard.storage_participant.first.fields['toto']

    @dashboard.storage_participant.proceed(@dashboard.storage_participant.first)
    @dashboard.wait_for(:alpha)

    assert_nil @dashboard.storage_participant.first.fields['toto']
  end
end

