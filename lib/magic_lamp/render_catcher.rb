module MagicLamp
  class RenderCatcher
    include Callbacks

    attr_accessor :render_argument

    def render(first_arg, *args)
      self.render_argument = first_arg
    end

    def first_render_argument(&block)
      execute_callbacks_around { instance_eval(&block) }
      render_argument
    end

    def method_missing(method, *args, &block)
      self
    end
  end
end
