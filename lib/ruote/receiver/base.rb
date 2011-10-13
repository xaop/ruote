#--
# Copyright (c) 2005-2011, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++


module Ruote

  #
  # The core methods for the Receiver class (sometimes a Mixin is easier
  # to integrate).
  #
  # (The dashboard itself includes this mixin, the LocalParticipant module
  # includes it as well).
  #
  module ReceiverMixin

    # This method pipes back a workitem into the engine, letting it resume
    # in its flow, hopefully.
    #
    def receive(workitem)

      workitem = workitem.to_h if workitem.respond_to?(:to_h)

      @context.storage.put_msg(
        'receive',
        'fei' => workitem['fei'],
        'workitem' => workitem,
        'participant_name' => workitem['participant_name'],
        'receiver' => sign)
    end

    # Wraps a call to receive(workitem)
    #
    # Not aliasing so that if someone changes the receive implementation,
    # reply is affected as well.
    #
    def reply(workitem)

      receive(workitem)
    end

    # Given a process definitions and optional initial fields and variables,
    # launches a new process instance.
    #
    # This method is mostly used from the Ruote::Engine class (which includes
    # this mixin).
    #
    # process_definition must be a result of Ruote.process_definition call
    # or XML or JSON serialized process definition, as accepted by
    # Ruote::Reader#read.
    #
    # fields are workflow parameters that will be placed in workitem.fields.
    #
    # variables contain engine variables.
    #
    def launch(process_definition, fields={}, variables={}, root_stash=nil)

      wfid = @context.wfidgen.generate

      @context.storage.put_msg(
        'launch',
        'wfid' => wfid,
        'tree' => @context.reader.read(process_definition),
        'workitem' => { 'fields' => fields },
        'variables' => variables,
        'stash' => root_stash)

      wfid
    end

    # A receiver signs a workitem when it comes back.
    #
    # Not used much as of now.
    #
    def sign

      self.class.to_s
    end

    # Convenience method, given a workitem or a fei, returns the
    # corresponding flow expession.
    #
    def fetch_flow_expression(workitem_or_fei)

      Ruote::Exp::FlowExpression.fetch(
        @context,
        Ruote::FlowExpressionId.extract_h(workitem_or_fei))
    end

    alias fexp fetch_flow_expression
    alias flow_expression fetch_flow_expression

    # A convenience methods for advanced users (like Oleg).
    #
    # Given a fei (flow expression id), fetches the workitem as stored in
    # the expression with that fei.
    # This is the "applied workitem", if the workitem is currently handed to
    # a participant, this method will return the workitem as applied, not
    # the workitem as saved by the participant/user in whatever worklist it
    # uses. If you need that workitem, do the vanilla thing and ask it to
    # the [storage] participant or its worklist.
    #
    # The fei might be a string fei (result of fei.to_storage_id), a
    # FlowExpressionId instance or a hash.
    #
    # on_terminate processes are not triggered for on_error processes.
    # on_error processes are triggered for on_terminate processes as well.
    #
    def fetch_workitem(fexp_or_fei)

      Ruote::Workitem.new(flow_expression(fexp_or_fei).h.applied_workitem)
    end

    alias workitem fetch_workitem
    alias applied_workitem fetch_workitem

    protected

    # Stashes values in the participant expression (in the storage).
    #
    #   put(workitem.fei, 'key' => 'value', 'colour' => 'blue')
    #
    # Remember that keys/values must be serializable in JSON.
    #
    # put & get are useful for a participant that needs to communicate
    # between its consume and its cancel.
    #
    # See the thread at
    # http://groups.google.com/group/openwferu-users/t/2e6a95708c10847b for the
    # justification.
    #
    def stash_put(workitem_or_fei, key, value=nil)

      hash = key.is_a?(Hash) ? key : { key => value }

      exp = fetch_flow_expression(workitem_or_fei)

      (exp.h['stash'] ||= {}).merge!(hash)

      r = exp.try_persist

      return hash if r == nil
      return stash_put(workitem_or_fei, key, value) if r != true

      fei = Ruote::FlowExpressionId.extract(workitem_or_fei).sid rescue 'xxx'
      raise ArgumentError.new("failed to put, expression #{fei} is gone")
    end

    alias put stash_put

    # Fetches back a stashed value.
    #
    #   get(fei, 'colour')
    #     # => 'blue'
    #
    # To return the whole stash
    #
    #   get(fei)
    #     # => { 'colour' => 'blue' }
    #
    # put & get are useful for a participant that needs to communicate
    # between its consume and its cancel.
    #
    def stash_get(workitem_or_fei, key=nil)

      stash = fetch_flow_expression(workitem_or_fei).h['stash'] rescue nil
      stash ||= {}

      key ? stash[key] : stash
    end

    alias get stash_get
  end

  #
  # A receiver is meant to receive workitems and feed them back into the
  # engine (the storage actually).
  #
  class Receiver
    include ReceiverMixin

    # Accepts context, worker, engine or storage as first argument.
    #
    def initialize(cwes, options={})

      @context = cwes.context
      @options = options
    end
  end
end

