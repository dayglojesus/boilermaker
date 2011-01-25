require 'pathname'
require 'fileutils'

class RadmindErr < RuntimeError
end

class Radmind
  
  # Ensure the Radmind tools are installed
  def self.tools? ()
    tests = RADMINDTOOLS.map { |tool| File.executable?(RADMINDTOOLSPATH + tool) }
    return (not tests.include?(false))
  end
  
  # Implements a Radmind ktcheck
  def self.updateK (args)
    puts "Beginning Radmind update..."
    cmd = [RADMINDTOOLSPATH + 'ktcheck', '-h' + args[:radhost]]
    cmd << '-c' + args[:cksum] if args[:cksum]
    cmd << '-w' + args[:secure] if args[:secure]
    # pp cmd    
    unless system(cmd.join(" "))
      raise RadmindErr.new("There was a problem executing the specified cmd: #{$?}") if $?.to_i > 256
      return $?
    end
  end
  
  # Parse the command.K and K-in-K files
  # * Returns an array containing a list of available transcripts
  # * Unimplemented
  def self.readK (path = RADMINDPATH)
    
    transcripts = []
    kfilepath = path + 'command.K'
    
    if File.exists?(kfilepath)
      kfile = File.open(File.expand_path(kfilepath))
      kfile.map do |transcript| 
        type, path = transcript.split
        transcripts << path
      end
      kfile.close
      return transcripts
    else
      raise RadmindErr.new("#{kfilepath} missing: #{$!}")
      return $!
    end
  end
  
  # Implements transcript conversion
  # * In order to retreive the transcript's payload (loadset), the transcript must be converted from a creatable transcript to an appliable one.
  # * The newly converted transcript is stored in the root of the pkgproject
  def self.convert(args)
    # pp args
    puts "Beginning transcript conversion..."
    header = args[:tconvert].sub(RADMINDPATH,'') + ':'
    prefix = '+'
    outfile = args[:projectdir] + "/#{File.basename(args[:tconvert])}"
    converted = File.new(File.expand_path(outfile), 'w') 
    converted.puts header   
    infile = File.open(args[:tconvert]).each do |x|
      linein = x.split
      linein[1] = '.' + linein[1] unless linein[1] =~ /^\.\//
      linein = linein.join(' ')
      if linein[/^- /]
        converted.puts "# #{linein}"
      elsif linein[/^d |^l |^h |^\#/]
        converted.puts "#{linein}"
      else
        converted.puts "#{prefix} #{linein}"
      end
    end
    infile.close
    converted.close
    # return converted.path
    puts "Converted file: #{outfile}"
    
  end
  
  # Implements a Radmind lapply using the pkgroot as it's target
  # * Uses the converted transcript to populate the pkgroot with the transcript's payload
  def self.fetch (args)
    pkgroot = args[:projectdir] + '/pkgroot'
    unless Dir.chdir(pkgroot)
      raise RadmindErr.new("Could not chdir to pkgroot: #{pkgroot}")
      exit 1
    end
    puts "Current directory: #{Dir.pwd}"
    
    # Radmind.prefetch(pkgroot, args[:fetch])

    puts "Fetching transcript..."
    
    cmd = [RADMINDTOOLSPATH + 'lapply', '-%', '-C', '-h' + args[:radhost]]
    cmd << '-c' + args[:cksum] if args[:cksum]
    cmd << '-w' + args[:secure] if args[:secure]
    cmd << args[:fetch]

    unless system(cmd.join(" "))
      raise RadmindErr.new("There was a problem executing the specified cmd: #{$?}") if $?.to_i > 256
      return $?
    end
    
  end
  
end
