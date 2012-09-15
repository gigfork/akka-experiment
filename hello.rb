require 'java'
require 'scala-library.jar'
require 'config-0.3.1.jar'
require 'akka-actor-2.0.3.jar'

java_import 'java.io.Serializable'
java_import 'akka.actor.UntypedActor'
java_import 'akka.actor.ActorRef'
java_import 'akka.actor.ActorSystem'
java_import 'akka.actor.Props'

class Greeting 
  include Serializable
  
  attr_reader :who

  def initialize(who)
    @who = who
  end

end
 
class GreetingActor < UntypedActor

  class << self
    alias_method :apply, :new
    alias_method :create, :new
  end

  def onReceive(message)
    puts "Hello " + message.who;
  end

end
 
system = ActorSystem.create("GreetingSystem");
props = Props.new(GreetingActor)
greeter = system.actorOf(props, "greeter");
greeter.tell(Greeting.new("Rocky Jaiswal"));

system.shutdown
system.await_termination