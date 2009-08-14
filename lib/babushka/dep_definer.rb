module Babushka
  class DepDefiner
    include ShellHelpers
    include PromptHelpers
    include VersionList

    attr_reader :dep, :payload, :source_path

    delegate :name, :var, :define_var, :to => :dep
    delegate :set, :merge, :to => :runner

    def initialize dep, &block
      @dep = dep
      @payload = {}
      @block = block
      @source_path = self.class.current_load_path
    end

    def runner
      @dep.runner
    end

    def process
      instance_eval &@block unless @block.nil?
    end

    def self.current_load_path
      @@current_load_path ||= nil
    end

    def self.load_deps_from path
      $stdout.flush
      previous_length = Dep.deps.length
      returning(Dir.glob(pathify(path) / '**/*.rb').all? {|f|
        @@current_load_path = f
        begin
          returning require f do
            @@current_load_path = nil
          end
        rescue Exception => e
          log "#{e.backtrace.first}: #{e.message}"
          # log "#{e.backtrace.grep(/#{f}/).first}"
          log "Failed to load #{f}."
          return nil
        end
      }) do |result|
        log "Loaded #{Dep.deps.length - previous_length} dependencies from #{path}."
      end
    end

    def self.accepts_block_for method_name
      (@@accepted_blocks ||= []).push method_name
      class_eval %Q{
        def #{method_name} *args, &block
          if block.nil?
            block_for #{method_name.inspect}
          else
            store_block_for #{method_name.inspect}, args, block
          end
        end
      }
    end

    def default_task task_name
      L{
        send({:met? => :log_extra, :meet => :log_extra}[task_name] || :debug, [
          "#{@dep.name} / #{task_name} not defined",
          "#{" for #{uname_str}" unless (@dep.send(:payload)[task_name] || {})[:all].nil?}",
          {
            :met => ", moving on",
            :meet => " - nothing to do"
          }[task_name],
          "."
        ].join)
        true
      }
    end


    private

    def store_block_for method_name, args, block
      opts = {:on => :all}.merge(args.first || {})
      (payload[method_name] = {})[opts[:on]] = block
    end

    def block_for method_name
      payload[method_name][uname] || payload[method_name][:all] unless payload[method_name].nil?
    end

    def self.accepted_blocks
      @@accepted_blocks
    end

    def self.set_up_delegating_for method_name
      runner_class.send :delegate, method_name, :to => :definer
    end

    def self.runner_class
      Object.recursive_const_get name.to_s.sub('Definer', 'Runner')
    end

  end
end
