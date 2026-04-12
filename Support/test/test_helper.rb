TEST_ROOT = File.dirname(__FILE__)
FIXTURES_DIR = File.expand_path("#{TEST_ROOT}/fixtures")

# Define TextMate::UI stub BEFORE loading environment.rb, so that
# the real TM_SUPPORT_PATH/lib/ui.rb (which requires plist gem) is
# never needed.
module TextMate; module UI; end; end

def self.request_item(options = {}, &block)
  yield options[:items].first if block_given?
  options[:items].first
end

require TEST_ROOT + '/../environment.rb'
require 'test/unit'
require 'stringio'

# Do NOT require LIB_ROOT + "/ui.rb" -- it pulls in TM_SUPPORT_PATH's
# ui.rb which depends on the plist gem, unavailable on Ruby 2.6 stdlib.
# Instead we define the minimal TextMate::UI interface needed for tests.

module TextMate::UI
  def self.request_item(options = {}, &block)
    yield options[:items].first if block_given?
    options[:items].first
  end
end

# --- ArrayKeyedHash: allows multi-arg keys for command_response ---
class ArrayKeyedHash < Hash
  def []=(*args)
    value = args.pop
    super(args, value)
  end

  def [](*args)
    super(args)
  end
end

# --- Git mock infrastructure ---
# Replaces the real Git#command with a stubbed version that returns
# pre-configured responses, tracks commands ran, etc.
class Git
  alias :initialize_without_autopath :initialize
  def initialize(options = {})
    options = options.dup
    options[:path] ||= "/base"
    initialize_without_autopath(options)
  end

  class << self
    def reset_mock!
      command_response.clear
      command_output.clear
      commands_ran.clear
    end

    def command_response
      @@command_response ||= ArrayKeyedHash.new
    end

    def command_output
      @@command_output ||= []
    end

    def commands_ran
      @@commands_ran ||= []
    end

    def stubbed_command(*args)
      commands_ran << args
      if command_response.empty?
        command_output.shift
      else
        r = command_response[*args] || ""
        if r.is_a?(Array)
          r.shift
        else
          r
        end
      end
    end
  end

  def command(*args)
    Git.stubbed_command(*args)
  end

  def popen_command(*args)
    StringIO.new(command(*args))
  end

  def git_dir(file_or_dir = paths.first)
    "/base/.git"
  end

  def paths(*args)
    [path]
  end

  def nca(*args)
    path
  end

  attr_writer :version
  def version; @version ||= "1.5.4.3"; end
end

# --- Stub exit methods ---
def exit_with_output_status
end

[:exit_show_html, :exit_discard, :exit_show_tool_tip].each do |exit_method|
  Object.send :define_method, exit_method do
    $exit_status = Object.const_get(exit_method.to_s.upcase)
  end
end

# --- TestHelpers module (replaces SpecHelpers) ---
module TestHelpers
  PUTS_CAPTURE_CLASSES = [::Git]

  def fixture_file(filename)
    File.read("#{FIXTURES_DIR}/#{filename}")
  end

  def set_constant_forced(klass, constant_name, constant)
    klass.class_eval do
      remove_const(constant_name) if const_defined?(constant_name)
      const_set(constant_name, constant)
    end
  end

  def capture_output(&block)
    old_stdout = Object::STDOUT
    io_stream = StringIO.new
    begin
      set_constant_forced(Object, "STDOUT", io_stream)
      PUTS_CAPTURE_CLASSES.each do |klass|
        klass.class_eval do
          def puts(*args)
            args.each { |arg| Object::STDOUT.puts arg }
          end
        end
      end
      yield
    ensure
      set_constant_forced(Object, "STDOUT", old_stdout)
    end
    io_stream.rewind
    io_stream.read
  end
end
