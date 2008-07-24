%w(rubygems active_support).each { |d| require d }

class Lumberjack
  
  def self.construct(initial_scope = [], &block)
    builder = new(initial_scope)
    builder.__process(block)    
  end
  
  @@methods_to_keep = /^__/, /class/, /instance_eval/, /method_missing/
  
  instance_methods.each do |m|
    undef_method m unless @@methods_to_keep.find { |r| r.match m }
  end
  
  def initialize(initial_scope)
    @initial_scope = initial_scope
  end
  
  def __process(block)
    prepare_scope
    instance_eval(&block) if block
    tree
  rescue
    puts @scope.inspect
    raise $!
  end
  
  def method_missing(*args, &block)
    #
    # now we've changed this here, we're assuming any scope that responds
    # to << must be a collection, so we treat it as such - i can't think
    # of any scenarios where this may bunk up, but best to remind myself
    # for later just in case...
    #
    if !current_scope.respond_to?(:<<) # we're working inside an Instance
      accessor = args.shift # grab the accessor name
      if accessor.to_s[-1].chr == '!' # hacky hack instance something
        instance = eval(accessor.to_s[0...-1].classify).new(*args)
        current_scope.send("#{accessor.to_s[0...-1]}=", instance)
        if block # we got a block, change scope to set accessors
          append_scope_with instance
          instance_eval(&block)
          jump_out_of_scope
        end
      elsif block and args.empty? # we're making an accessor into an array of Instances
        if current_scope.send("#{accessor}").nil?
          current_scope.send("#{accessor}=", [])
        end
        collection = current_scope.send("#{accessor}")
        append_scope_with collection
        instance_eval(&block)
        jump_out_of_scope
      else # it's just a plain old assignment to the accessor
        if args.length == 1
          current_scope.send("#{accessor}=", *args)
        else # it looks like someone is trying to pass an array... so
          #
          # THIS BIT IS FUCKED, take this crap out, it makes the API
          # way too confusing and inconsistent
          #
          current_scope.send("#{accessor}=", args)
        end
      end
    else # scope is an Array, so create an Instance
      klass = args.shift
      instance = eval(klass.to_s.classify).new(*args)
      current_scope << instance # add this instance to the scoped Array
      if block # we got a block, change scope to set accessors
        append_scope_with instance
        instance_eval(&block)
        jump_out_of_scope
      end
    end
  end
  
private

  def prepare_scope
    @scope = [@initial_scope]
  end
  
  def append_scope_with(new_scope)
    scope.push new_scope
  end
  
  def jump_out_of_scope
    scope.pop
  end
  
  def current_scope
    scope.last
  end
  
  def tree
    scope.first
  end
  
  def scope
    @scope
  end
  
end