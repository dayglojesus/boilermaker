
# Extend the Symbol class so that they may be sorted like Strings
class Symbol
  include Comparable
  def <=>(other)
    self.to_s <=> other.to_s
  end
end

class BoilerMakerErr < RuntimeError
end

class Boilermaker
  
  MSG_NO_RADMIND  = 'The radmind tools are not installed.'
  MSG_NO_DEVTOOLS = 'The Apple developer tools are not installed.'
  MSG_NO_HDIUTIL  = 'Cannot find the required Apple hdiutil.'
  MSG_NO_ROOT     = "You must be root to execute this option."
  
  attr_reader :options

  # Initialize the arguments and options variables
  def initialize(arguments)
    @arguments  = arguments
    @options    = {}
  end
  
  # The main method
  # * This method is called from the boilermaker executable after the Boilermaker object is instantiated.
  # * It serves as a jumping off point point for processing the arguments and options passed to the main executable.
  def run    
    if parsed_options? && arguments_valid? 
      puts "Start at #{DateTime.now}"
      process_arguments(@validoptions.args)
      puts "Finished at #{DateTime.now}"
    else
      raise BoilerMakerErr.new("Could not parse options. An unknown error has ocurred.")
      exit $!
    end
  end
  
  # Checks the effective UID of the operator 
  def self.gotroot?
    true if Process.euid == 0
  end
  
  # Tests for the radmind tools
  def self.gotradmind?
    Radmind.tools?
  end
  
  # Tests for the Developer Tools
  def self.gotdevtools?
    PkgProj.devtools?
  end
  
  # Tests for the hdiutil CLI 
  def self.gothdiutil?
    PkgProj.hdiutil?
  end
    
  protected
    
    # Parse the options passed through ARGV
    # * Options passed inthrough ARGV are stored in "@optparse"
    def parsed_options?
      @optparse = OptionParser.new do |opts|
        
        # A usage banner
        opts.banner = "Usage: #{File.basename($0)} [options]"
        
        # Returns the current version of the tool
        opts.on_tail('-v', '--version', "Display version")    { output_version ; exit 0 }
        
        # Quick distribution
        options[:quickpkg] = nil
        opts.on( '-Q', '--quickpkg <app>', 'Create a quick application distribution (simple)' ) do |app|
          options[:quickpkg] = app
        end
        
        # Create a new project
        options[:createproj] = nil
        opts.on_head( '-C', '--createproj <dir>', String, 'Create a project directory (advanced)' ) do |proj|
          options[:createproj] = proj
        end
  
        # Specify an existing project
        options[:projectdir] = nil
        opts.on_head( '-D', '--projectdir <dir>', String, 'Specify a project directory to work with' ) do |dir|
          options[:projectdir] = dir
        end
    
        # Update the Radmind command file
        options[:ktcheck] = nil
        opts.on( '-K', '--ktcheck', 'Update the Radmind client command file' ) do |check|
          options[:ktcheck] = check
          # puts "Updating the client's command file: #{options[:ktcheck]}"
        end

        # Convert a Radmind transcript
        options[:convert] = nil
        opts.on( '-t', '--tconvert <transcript>', 'Convert a createable transcript to an appliable transcript' ) do |transcript|
          options[:tconvert] = transcript
        end

        # Fetch a converted Radmind loadset
        options[:fetch] = nil
        opts.on( '-f', '--fetch <transcript>', 'Fetch a converted Radmind transcript' ) do |transcript|
          options[:fetch] = transcript
        end
        
        # Specify a radmind host
        options[:radhost] = nil
        opts.on( '-h', '--radhost <host>', 'Specify the Radmind server host' ) do |host|
          options[:radhost] = host
        end

        # Generate the boilerplate
        options[:boil] = nil
        opts.on( '-b', '--boil', 'Generate boilerplate ' ) do |boil|
          options[:boil] = boil
        end
        
        # Package up the project's pkgroot
        options[:package] = nil
        opts.on('-p', '--package', 'Package your project ') do |package|
          options[:package] = package
        end

        # Archive the package inside a disk image
        options[:rollup] = nil
        opts.on('-r', '--rollup', 'Create a disk image of your package ') do |rollup|
          options[:rollup] = rollup
        end
                        
        # Use Radmind security?
        options[:security] = nil
        opts.on( '-w', '--secure <level>', 'Use security level 0, 1 or 2 for Radmind operations' ) do |level|
          options[:secure] = level
        end

        # Use Radmind checksums
        options[:cksum] = nil
        opts.on( '-c', '--cksum <hash>', 'Update the Radmind client command file' ) do |hash|
          options[:cksum] = hash
        end
        
        # Prints a detailed help message
        opts.on_tail('--help', 'Show detailed help and information') do
          output_version
          output_help
        end
      
      end
      
      # Parse the options
      # * A non-successful parse operation presents a list of the acceptable options
      begin
        @optparse.parse!
      rescue => error
        puts error.message + "\n"
        puts @optparse
        exit 1
      end

      # Pre-process the options before we validate them
      process_options
      true
  
    end # parsed_options? method
    
    # Performs post-parse processing on options
    # * Deletes any keypairs that have nil values and if there aren't any options, shows available options
    # * Raises an exception if an option's arg begins with a hyphen
    def process_options
      options.delete_if { |x,y| y.nil? }
      if options.empty?
        puts @optparse 
        exit 0
      end
      options.each do |x,y|
        begin
          if y.to_s.match('^-')
            raise BoilerMakerErr.new("Bad args: \"#{y}\" is not a valid arg to option, \"--#{x}\". Use the -h flag for syntax help.")
          end
        rescue => error
          puts error.message + "\n"
          exit 1
        end
      end
    end

    # Returns options/args if required arguments are valid
    # * Options are validated by the BoilermakerOptions class
    def arguments_valid?
      begin
        @validoptions = BoilermakerOptions.new(options)
        @validoptions.validate
        # pp @validoptions.args
        return @validoptions.args
      rescue => error
        # pp x.args
        puts error.message + "\n"
        exit
      end
    end
    
    # Arguments/Options are processed and passed to their applicable methods
    # * Options/Args are handed off to the various class methods that implement their functionality
    # * These directives are passed in alphanumeric order to re-order option strings like -brp
    def process_arguments(args)
      begin
        args.keys.sort.each do |k,v|
          case k
            when :quickpkg
              unless Boilermaker.gotroot?     
                raise BoilerMakerErr.new(MSG_NO_ROOT)
                exit $!
              end
              unless Boilermaker.gotdevtools?
                raise BoilerMakerErr.new(MSG_NO_DEVTOOLS)
                exit $!
              end
              unless Boilermaker.gothdiutil?     
                raise BoilerMakerErr.new(MSG_NO_HDIUTIL)
                exit $!
              end
              project = QuickPkg.new(args)
              # pp project.vars
              project.prep(args)
              project.build(args)
            when :createproj
              project = PkgProj.new(args)
              project.prep
            when :ktcheck
              unless Boilermaker.gotroot?     
                raise BoilerMakerErr.new(MSG_NO_ROOT)
                exit $!
              end
              unless Boilermaker.gotradmind?   
                raise BoilerMakerErr.new(MSG_NO_RADMIND)
                exit $!
              end
              Radmind.updateK(args)
            when :tconvert
              Radmind.convert(args)
            when :fetch
              unless Boilermaker.gotroot?   
                raise BoilerMakerErr.new(MSG_NO_ROOT)
                exit $!
              end
              unless Boilermaker.gotradmind?   
                raise BoilerMakerErr.new(MSG_NO_RADMIND)
                exit $!
              end              
              Radmind.fetch(args)
            when :boil
              project = PkgProj.new(args)
              project.boil
            when :rollup
              unless Boilermaker.gotroot?     
                raise BoilerMakerErr.new(MSG_NO_ROOT)
                exit $!
              end
              unless Boilermaker.gothdiutil?     
                raise BoilerMakerErr.new(MSG_NO_HDIUTIL)
                exit $!
              end
              project = PkgProj.new(args)
              project.rollup
            when :package
              unless Boilermaker.gotroot?     
                raise BoilerMakerErr.new(MSG_NO_ROOT)
                exit $!
              end
              unless Boilermaker.gotdevtools?
                raise BoilerMakerErr.new(MSG_NO_DEVTOOLS)
                exit $!
              end
              project = PkgProj.new(args)
              project.package(args)
          end
        end
      rescue => error
        puts error.message + "\n"
        exit 1
      end
      
    end
    
    # Implements a detailed usage document
    def output_help
      RDoc::usage()
    end
    
    # Implements a boilermaker version check
    def output_version
      puts "#{File.basename($0)} version #{BM_VERSION}"
    end
        
end

class BoilermakerOptions
  
  attr_reader :args
  
  # Accepts options passed from the "@optparse" variable
  def initialize(options)
    @options = options
    @args = {}
  end
  
  # Iterates over each option and validates its context
  # * Creates a matrix of mutally exclusive options.
  # * Each option that is passed in is evaluated in the context of the others.
  # * Valid options are stored in the attribute "@args" so that they are accessible to other methods and processes.
  # * If an option that is passed in is determined to be out of scope for any of the other options, an helpful exception is raised.
  def validate()
    @options.each do |k,v|
       # self.send(k, k)
       self.send(k)
    end
    @args[:projectdir] = File.expand_path("./") unless @args[:projectdir]
  end
    
  protected
  
  # The method_missing callback is leveraged to create a matrix of mutual exclusivity as it pertains to boilermaker options
  def method_missing(m)

    case m
    when :createproj
      @args[:projectdir] = @options[m]
      @args[m] = true
    
    when :quickpkg
      # raise BoilerMakerErr.new("Option -Q: This option is unimplemented.") 
      @args[m] = @options[:quickpkg]
      
    when :projectdir
      unless @options[:createproj] or @options[:tconvert] or @options[:fetch] or @options[:package] or @options[:boil] or @options[:rollup]
        raise BoilerMakerErr.new("Option --#{m}: This flag is only useful when combined with: -C, -t, -f or -p") 
      end
      @args[m] = File.expand_path(@options[m])
      unless @options[:createproj]
        raise BoilerMakerErr.new("No such file or dir: #{@args[m]}") unless File.exists?(@args[m])
      end
      
    when :ktcheck
      if @options[:createproj] or @options[:projectdir] or @options[:tconvert] or @options[:fetch]
        raise BoilerMakerErr.new("Option --#{m}: This flag is only useful when combined with: -c, -h or -w") 
      end
      raise BoilerMakerErr.new("Option --#{m}: Use the -h to specify a Radmind server host") unless @options[:radhost]
      @args[m] = @options[m]
      
    when :tconvert
      @args[m] = File.expand_path(@options[m])
      raise BoilerMakerErr.new("No such file or dir: #{@args[m]}") unless File.exists?(@args[m])
        
    when :fetch
      raise BoilerMakerErr.new("Option --#{m}: Use the -h to specify a Radmind server host") unless @options[:radhost]
      @args[m] = File.expand_path(@options[m])
      raise BoilerMakerErr.new("No such file or dir: #{@args[m]}") unless File.exists?(@args[m])
    
    when :radhost
      unless @options[:ktcheck] or @options[:fetch]
        raise BoilerMakerErr.new("Option --#{m}: This flag is only useful when combined with: -K or -f") 
      end
      @args[m] = @options[m]

    when :boil
      @args[m] = @options[m]
      
    when :package
      @args[m] = @options[m]

    when :rollup
      @args[m] = @options[m]
    
    when :secure
      unless @options[:ktcheck] or @options[:fetch]
        raise BoilerMakerErr.new("Option --#{m}: This flag is only useful when combined with: -K or -f")
      end
      @args[m] = @options[m]

    when :cksum
      unless @options[:ktcheck] or @options[:fetch]
        raise BoilerMakerErr.new("Option --#{m}: This flag is only useful when combined with: -K or -f")
      end
      @args[m] = @options[m]
    
    end
        
  end
    
end

