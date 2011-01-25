
class QuickPkgErr < RuntimeError
end

class QuickPkg < PkgProj
  
  attr_reader :source, :vars, :pkginfo
  
  # Create a new QuickPkg object
  # * Processes some initial values needed to identify the project
  def initialize(source)
    @stamp = rand(100000)
    # Get rid of trailing "/" characters in the source path
    if source[:quickpkg] =~ /\/$/
      @source = source[:quickpkg].chop
    else
      @source = source[:quickpkg]
    end
    @pkginfo = {}
    @args = {}
    getvars(@source)
    procvars
  end
  
  # Prepare the new quick package project
  # * Prompts user whether or not to continue
  def prep(args = @args)
    unless not ready?
      project = PkgProj.new(@args)
      project.prep
      stagepayload(project.pkgroot)
      crunch(@pkginfo, project.pkgyaml)
    end
  end
  
  # Build the package
  # * Boil, package, and rollup
  def build(args = @args)
    project = PkgProj.new(@args)
    project.boil
    project.package(@args)
    project.rollup
    finish(project.projectdir)
  end
  
  # Finish up the process
  # * Copy the completed dmg file to the user's Desktop
  # * Optionally delete the temp project directory
  def finish(projectdir)
    source =  projectdir + '/build/' + File.basename(projectdir) + '_' + @pkginfo[:version] + '.dmg'
    puts "Copying finished dmg file to your Desktop..."
    FileUtils.cp_r(source, File.expand_path("~/Desktop"))
    printf "\n\t--- Would you like to delete the quick project directory? Press y to confirm, or any another key to exit: "
    answer = gets.chomp
    case answer 
    when "y"
      FileUtils.rm_rf(projectdir)
    else
      raise QuickPkgErr.new("Exiting at user request...")
      exit 1
    end    
  end
  
  protected
  
  # Load the specified Application Bundle's Info.plist file
  # * Loads the keys/values and returns a Ruby hash
  # * If the method's arg is not an app bundle, the method will attempt to find one inside the given dir.
  # * If the method's arg is neither app bundle or directory, we raise an error.
  def getvars(app)
    if app =~ /.*\.app/
      @vars = Plist.load(app + INFO).to_ruby
    elsif File.directory?(app)
      apps = Dir.glob("#{app}/*.app")
      if apps.size == 1
        app = apps.shift
        @vars = Plist.load(app + INFO).to_ruby
      else
        raise QuickPkgErr.new("Specified directory must contain exactly one application bundle.")
      end
    else
      raise QuickPkgErr.new("#{app} is not a valid source. Specify a directory or application bundle.")
    end
  end
  
  # Conform a fetched version string
  # * This method will attempt to conform the version string to a known format
  # * At least three point releases, and no garbage ie. 1.0.0
  # * If it cannot format the version string, it raises an error and exits
  def procversion(arg)
    # Make sure the version string is formatted properly
    if arg =~ /^(\d+\.)+\d+/
      match = $&
      postfix = $'
      # Get a version string with a minimum of 3 release points
      match += ".0" unless match =~ /^(\d+\.){2}/
      # If the version string is conformed, there won't be a postfix
      if postfix.empty?
        return match
      else
      # If there's a postfix, try and make sense of it by tacking it on to the version string sanely
        postfix.gsub!(/ |-|_/,".")                    
        postfix.delete!("()|,/[]{}&$!_=<>~`\'\"")     # delete garbage
        return match + postfix
      end
    else
      raise QuickPkgErr.new("Cannot find a sane version string for the specified application bundle: #{arg}")
    end
  end
  
  # Fetches a version string
  # * Different developers have different ideas about what constitutes a version string
  # * Prefers CFBundleShortVersionString over CFBundleVersion
  # * If neither exist, raise an error and exit.
  def getversion
    if not @vars["CFBundleShortVersionString"].nil?
      version = procversion(@vars["CFBundleShortVersionString"])
      return version
    elsif not @vars["CFBundleVersion"].nil?
      version = procversion(@vars["CFBundleVersion"])
      return version
    else
      raise QuickPkgErr.new("Cannot find a sane version string for the specified application bundle.")
    end
  end
  
  # Process the variables parsed from the Info.plist
  # * Vars read in from the plist are stored in a Ruby hash: @pkginfo
  def procvars
    @pkginfo[:title] = @vars["CFBundleName"]
    @pkginfo[:id] = "ca.sfu.its." + @vars["CFBundleName"].downcase + ".pkg"
    @pkginfo[:version] = getversion
    @pkginfo[:blurb] = pkginfo[:title]
    @pkginfo[:overview] = "#{pkginfo[:title]} was packaged using Boilermaker's Quick Package feature"
    @pkginfo[:details] = "Package will be installed into the Mac OS X /Applications directory."
    @args[:projectdir] = TMP + "/bm-" + @stamp.to_s + "/" + @pkginfo[:title]
  end
  
  # Confirm that the user is ready to package the specified materials
  # * Returns true or false based on the answer given
  def ready?
    puts "\nQuick packaging: #{@source}"
    puts "\n\tPackage Title: #{@pkginfo[:title]}"
    puts "\tPackage ID: #{@pkginfo[:id]}"
    puts "\tPackage Version: #{@pkginfo[:version]}"
    puts "\n\tWhen complete Boilermaker will place the completed dmg file on your Desktop."
    printf "\n\t--- Is this information correct? Press y to confirm, or any another key to exit: "
    answer = gets.chomp
    case answer 
    when "y"
      @ok = true
    else
      @ok = false
      raise QuickPkgErr.new("Exiting at user request...")
    end    
    return @ok
  end
  
  # Copy the source material into place and prep it for packaging
  # * Copies the payload into the staging pkgroot/Applications dir
  # * Corrects ownership
  # * Corrects permissions
  def stagepayload(pkgroot)
    
    begin
      puts "Creating an applications dir in pkgroot: #{pkgroot + APPS}"
      Dir.mkdir("#{pkgroot + APPS}")
      puts "Copying payload to pkgroot: #{@source} --> #{pkgroot + APPS}"
      # FILEUTILS WILL NOT COPY MAC EXT. ATTRIBS!!!
      # FileUtils.cp_r(@source, pkgroot + APPS)
      cmd = ['/bin/cp',
        ' -R ',
        "\"#{@source}\"",
        ' ' + "\"#{pkgroot + APPS}\""
        ]
      unless system(cmd.join(" "))
         raise QuickPkgErr.new("There was a problem copying the source tree...")
      end
      
      # Change the file ownership to root:admin
      puts "Setting file and folder ownership to root:admin..."
      cmd = ['/usr/sbin/chown ',
        '-R ',
        'root:admin ',
        "\"#{pkgroot + APPS}\"",
        ' >&/dev/null'
        ]
      unless system(cmd.join(" "))
         raise QuickPkgErr.new("There was a problem setting ownership on the source tree...")
      end
            
      # Ensure no writable bits are set inside the pkgroot
      puts "Correcting permissions on pkgroot..."
      cmd = ['/bin/chmod ',
        '-R ',
        'o-w ',
        "\"#{pkgroot + APPS}\"",
        ' >&/dev/null'
        ]
      unless system(cmd.join(" "))
         raise QuickPkgErr.new("There was a problem setting permissions on the source tree...")
      end
      
    rescue #StandardError
      puts "ERROR"
      $stderr.puts "#{self.class}: #{$!}"
      exit $?
    end
    
    
  end
  
  # Prepares values in the YAML config file
  # * Loads the default values from the template YAML config file
  # * Merges @pkginfo with the default values
  # * Writes them back to the project's YAML config file
  def crunch(pkginfo, pkgyaml)
    if File.exists?(pkgyaml)
      store = YAML::load(File.open(pkgyaml))
      store.merge!(pkginfo)
      
      pkginfo2yaml = File.open(pkgyaml, 'w')
    
      unless pkginfo.include?(:creator)
        pkginfo[:creator] = Etc.getlogin
      end
      unless pkginfo.include?(:created) 
        pkginfo[:created] = Time.now.xmlschema
      end

      pkginfo[:edited_by] = Etc.getlogin
      pkginfo[:lastedit] = Time.now.xmlschema
    
      pkginfo2yaml.puts store.to_yaml
      pkginfo2yaml.close
      
      return store
    end
  end
  
end