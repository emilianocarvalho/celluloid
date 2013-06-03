module Celluloid
  OWNER_IVAR = :@celluloid_owner # reference to owning actor

  # Wrap the given subject with an Actor
  class CellActor < Actor
    def before_spawn(options)
      handle(Call) do |message|
        task(:call, message.method) {
          if @receiver_block_executions && meth = message.method
            if meth == :__send__
              meth = message.arguments.first
            end
            if @receiver_block_executions.include?(meth.to_sym)
              message.execute_block_on_receiver
            end
          end
          subject = @subjects.fetch(message.uuid)
          message.dispatch(subject)
        }
      end
      handle(BlockCall) do |message|
        task(:invoke_block) { message.dispatch }
      end
      handle(BlockResponse, Response) do |message|
        message.dispatch
      end
    end

    def after_spawn(options)
      @subjects = {}
      @proxy_class = (options[:proxy_class] || CellProxy)
    end

    def create_cell(subject, receiver_block_executions)
      uuid = Celluloid.uuid
      @cells[uuid] = Cell.new(subject)
      subject.instance_variable_set(OWNER_IVAR, self)
      @proxy_class.new(@actor_proxy, @mailbox, subject.class.to_s, uuid)
    end
  end

  class MultiCellActor < CellActor
    
  end

  class SingleCellActor < CellActor
    attr_reader :cell, :cell_proxy

    def after_spawn(options)
      # TODO: per subject
      @receiver_block_executions = options[:receiver_block_executions]

      @subject = options.delete(:subject)
      options[:subjects] = []
      super(options)
      @subject = options.fetch(:subject)
      @proxy = create_proxy(@subject)
    end
  end
end