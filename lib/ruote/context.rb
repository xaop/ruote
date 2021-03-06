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

require 'ruote/util/misc'


module Ruote

  #
  # A sort of internal registry, via a shared instance of this class, the worker
  # and the engine can access subservices like reader, treechecker,
  # wfid_generator and so on.
  #
  class Context

    SERVICE_PREFIX = /^s\_/

    attr_reader :storage
    attr_accessor :dashboard

    def initialize(storage)

      @storage = storage
      @storage.context = self

      @dashboard = nil

      @services = {}
      initialize_services
    end

    # A trick : in order to avoid
    #
    #   @context = o.respond_to?(:context) ? o.context : o
    #   # or
    #   #@context = o.is_a?(Ruote::Context) ? o : o.context
    #
    # simply letting a context say its context is itself.
    #
    def context

      self
    end

    # Returns the engine_id (as set in the configuration under the key
    # "engine_id"), or, by default, "engine".
    #
    def engine_id

      get_conf['engine_id'] || 'engine'
    end

    # Used for things like
    #
    #   if @context['ruby_eval_allowed']
    #     # ...
    #   end
    #
    def [](key)

      SERVICE_PREFIX.match(key) ? @services[key] : get_conf[key]
    end

    # Mostly used by engine#configure
    #
    def []=(key, value)

      raise(
        ArgumentError.new('use context#add_service to register services')
      ) if SERVICE_PREFIX.match(key)

      cf = get_conf
      cf[key] = value

      @storage.put(cf)
        # TODO blindly trust the put ? retry in case of failure ?

      value
    end

    # Configuration keys and service keys.
    #
    def keys

      #get_conf.keys
      (@services.keys + get_conf.keys).uniq.sort
    end

    # Called by Ruote::Dashboard#add_service
    #
    def add_service(key, *args)

      raise ArgumentError.new(
        '#add_service: at least two arguments please'
      ) if args.empty?

      key = key.to_s
      path, klass, opts = args

      key = "s_#{key}" unless SERVICE_PREFIX.match(key)

      service = if klass

        require(path)

        aa = [ self ]
        aa << opts if opts

        @services[key] = Ruote.constantize(klass).new(*aa)
      else

        @services[key] = path
      end

      self.class.class_eval %{ def #{key[2..-1]}; @services['#{key}']; end }
        #
        # This 'one-liner' will add an instance method to Context for this
        # service.
        #
        # If the service key is 's_dishwasher', then the service will be
        # available via Context#dishwasher.
        #
        # I.e. dishwasher = engine.context.dishwasher

      service
    end

    # This method is called by the worker each time it sucessfully processed
    # a msg. This method calls in turn the #on_msg method for each of the
    # services (that respond to that method).
    #
    def notify(msg)

      @services.values.each { |s| s.on_msg(msg) if s.respond_to?(:on_msg) }
    end

    # Takes care of shutting down every service registered in this context.
    #
    def shutdown

      @storage.shutdown if @storage.respond_to?(:shutdown)

      @services.values.each { |s| s.shutdown if s.respond_to?(:shutdown) }
    end

    alias engine dashboard
    alias engine= dashboard=

    # Returns true if this context has a given service registered.
    #
    def has_service?(service_name)

      service_name = service_name.to_s
      service_name = "s_#{service_name}" if ! SERVICE_PREFIX.match(service_name)

      @services.has_key?(service_name)
    end

    # List of services in this context, sorted by their name in alphabetical
    # order.
    #
    def services

      @services.keys.sort.collect { |k| @services[k] }
    end

    protected

    def get_conf

      @storage.get_configuration('engine') || {}
    end

    def initialize_services

      default_conf.merge(get_conf).each do |key, value|

        next unless SERVICE_PREFIX.match(key)

        add_service(key, *value)
      end
    end

    def default_conf

      { 's_wfidgen' => [
          'ruote/id/mnemo_wfid_generator', 'Ruote::MnemoWfidGenerator' ],
        's_reader' => [
          'ruote/reader', 'Ruote::Reader' ],
        's_treechecker' => [
          'ruote/svc/treechecker', 'Ruote::TreeChecker' ],
        's_expmap' => [
           'ruote/svc/expression_map', 'Ruote::ExpressionMap' ],
        's_tracker' => [
          'ruote/svc/tracker', 'Ruote::Tracker' ],
        's_plist' => [
          'ruote/svc/participant_list', 'Ruote::ParticipantList' ],
        's_dispatch_pool' => [
          'ruote/svc/dispatch_pool', 'Ruote::DispatchPool' ],
        's_dollar_sub' => [
          'ruote/svc/dollar_sub', 'Ruote::DollarSubstitution' ],
        's_error_handler' => [
          'ruote/svc/error_handler', 'Ruote::ErrorHandler' ],
        's_logger' => [
          'ruote/log/wait_logger', 'Ruote::WaitLogger' ],
        's_history' => [
          'ruote/log/default_history', 'Ruote::DefaultHistory' ] }
    end
  end
end

