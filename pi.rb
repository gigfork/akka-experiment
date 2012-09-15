require 'java'
require 'scala-library.jar'
require 'config-0.3.1.jar'
require 'akka-actor-2.0.3.jar'

java_import 'java.io.Serializable'
java_import 'akka.actor.UntypedActor'
java_import 'akka.actor.ActorRef'
java_import 'akka.actor.ActorSystem'
java_import 'akka.actor.UntypedActorFactory'
java_import 'akka.routing.RoundRobinRouter'
java_import 'akka.actor.Props'
java_import 'java.lang.System'
java_import 'akka.util.Duration'
java_import 'java.util.concurrent.TimeUnit'


class Calculate
end

class Work
  attr_reader :start, :no_of_chunks

  def initialize(start, no_of_chunks)
    @start = start
    @no_of_chunks = no_of_chunks
  end
end

class Result
  attr_reader :value

  def initialize(value)
    @value = value
  end
end

class PiApproximation
  attr_reader :pi, :duration

  def initialize(pi, duration)
    @pi = pi
    @duration = duration
  end
end

class Worker < UntypedActor
  class << self
    alias_method :apply, :new
    alias_method :create, :new
  end

  def calculate_for_pi(start, no_of_chunks)
    acc = 0.0
    start_elem = start * no_of_chunks
    end_elem = (start + 1) * no_of_chunks - 1

    (start_elem..end_elem).each do |elem|
      acc = acc + (4.0 * (1 - (elem % 2) * 2) / (2 * elem + 1))
    end
    
    return acc
  end

  def onReceive(work)
    result = calculate_for_pi(work.start, work.no_of_chunks)
    getSender().tell(Result.new(result), get_self)
  end
end

class Master < UntypedActor
  attr_accessor :start, :no_of_workers, :no_of_chunks, :no_of_elements, :listener, :pi, :no_of_results
  
  class << self
    alias_method :apply, :new
    alias_method :create, :new
  end

  def init_worker
    props = Props.new(Worker).withRouter(RoundRobinRouter.new(no_of_workers))
    @worker_router = self.get_context.actorOf(props, "workerRouter")
  end

  def onReceive(message)
    if (message.is_a?(Calculate))
      (0...@no_of_chunks).each do |number|
        @worker_router.tell(Work.new(number, @no_of_elements), get_self)
      end
    else
      result = message
      @pi = @pi + result.value
      @no_of_results = @no_of_results + 1

      if (@no_of_results == @no_of_chunks)
        duration = Duration.create(System.currentTimeMillis - @start, TimeUnit::MILLISECONDS)
        @listener.tell(PiApproximation.new(@pi, duration), get_self)
        get_context.stop(get_self)
      end
    end
  end
end

class Listener < UntypedActor
  class << self
    alias_method :apply, :new
    alias_method :create, :new
  end

  def onReceive(message)
    puts "Value of Pi - " + message.pi.to_s
    puts "Duration of calculation - " + message.duration.to_s

    get_context.system.shutdown
    #get_context.system.await_termination
  end
end

class MasterFactory 
  include UntypedActorFactory

  def initialize(listener)
    @@listener = listener
  end

  def create
    self.class.create
  end

  def self.create
    master = Master.new
    master.no_of_workers = 4
    master.no_of_chunks = 10000
    master.no_of_elements = 10000
    master.listener = @@listener
    master.start = System.currentTimeMillis
    master.pi = 0
    master.no_of_results = 0
    master.init_worker
    return master
  end
end


system = ActorSystem.create("PiSystem")
listener = system.actorOf(Props.new(Listener), "listener")

props_2 = Props.new(MasterFactory.new(listener))
master = system.actorOf(props_2, "master")
master.tell(Calculate.new)