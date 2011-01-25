
class PkgProjErr < RuntimeError
end

class PkgProj
  
  # The directory in which PkgProj should erect the PackageMaker project tree
  attr_reader :projectdir, :pkgroot, :builddir, :resources, :scripts, :pkgyaml, :version
  
  # Create a new PkgProj object with path arg
  def initialize (args)
    @projectdir = args[:projectdir]
    @pkgroot = @projectdir + '/pkgroot'
    @builddir = @projectdir + '/build'
    @resources = @projectdir + '/resources'
    @scripts = @projectdir + '/scripts'
    @pkgyaml = @projectdir + '/' + File.basename(@projectdir) + '.yaml'
    # pp @pkgyaml
    if File.exists?(@pkgyaml)
      # @pkginfo = YAML::load(File.open(@projectdir + '/' + File.basename(@projectdir) + '.yaml'))
      @pkginfo = YAML::load(File.open(@pkgyaml))
    else
      @pkginfo = YAML::load(File.open(TEMPLATES + '/config.yaml'))
    end
    @version = @pkginfo[:version]
  end
  
  # Apple Developer Tools installed?
  def self.devtools?
    return File.exists?(PKGMAKER)
  end
  
  # Apple's hdiutil command available?
  def self.hdiutil?
    return File.exists?(HDIUTIL)
  end
  
  # Write out values to our YAML file
  # * Creates default values or updates them
  # * Writes values back to the project's YAML file
  def updateyaml(pkginfo)
    if File.exists?(@pkgyaml)
      pkginfo2yaml = File.open(@pkgyaml, 'w')
    
      unless pkginfo.include?(:creator)
        pkginfo[:creator] = Etc.getlogin
      end
      unless pkginfo.include?(:created) 
        pkginfo[:created] = Time.now.xmlschema
      end

      pkginfo[:edited_by] = Etc.getlogin
      pkginfo[:lastedit] = Time.now.xmlschema
    
      # puts "\n**************************************************************************"
      puts "Changes written to YAML configuration..."
    
      pkginfo2yaml.puts pkginfo.to_yaml
      pkginfo2yaml.close
    end
  end
  
  # Create a empty skeleton project directory for PackageMaker projects
  # * Project Root: arg handed to the prep method
  # * Four subdirs: build, pkgroot, resources, scripts
  # * Takes one String argument: the project path/name to create
  # * If the directory already exists, the operation will raise an exception and exit.
  # * Copies the default YAML config file into place
  def prep (projectdir = @projectdir)
    
    @projectdir = Pathname.new(projectdir)

    unless @projectdir.exist?
      begin
        puts "Creating Project Directory: #{@projectdir}"
        @projectdir.mkpath
        @projectdir = @projectdir.realpath
        [@pkgroot, @resources, @scripts, @builddir].each do |x| 
          puts "Creating sub-dir: #{x}"
          Dir.mkdir(x)
        end

        puts "Copying resources: #{RESOURCES}"
        FileUtils.cp_r(RESOURCES, @projectdir)
        puts "Copying scripts: #{SCRIPTS}"
        FileUtils.cp_r(SCRIPTS, @projectdir)

        unless File.exists?(@pkgyaml)
          puts "Copying YAML: #{TEMPLATES}" + '/config.yaml'
          FileUtils.cp(TEMPLATES + '/config.yaml', @pkgyaml)
          # updateyaml(@pkginfo)
        end
        
      rescue StandardError
        $stderr.puts "#{self.class}: #{$!}"
        return $!
      end
    else
      raise PkgProjErr.new("Directory \"#{@projectdir}\" already exists")
      return $!
    end
    
  end
  
  
  # Create a disk image using the current package build as source
  # * Rollup looks for a pkg file inside the build dir, if it finds one, it will use that package as the source for a new disk image.
  # * Disk image names gsub any spaces from the source name, and replace them with "-".
  def rollup
    pkgroot = @projectdir + '/pkgroot'
    
    unless Dir.chdir(@projectdir)
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("Could not chdir to projectdir: #{@projectdir}")
      exit 1
    end
    unless File.exists?(@pkgyaml)
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("Project is missing a configuration file: #{File.basename(@pkgyaml)} not found")
      exit 1
    end
    unless File.exists?(@builddir)
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("Project directory is missing a build dir: #{@builddir}")
      exit 1
    end
    
    source = "#{@builddir + '/' + @pkginfo[:title] + '-' + @pkginfo[:version] + '.pkg'}"
    target = "#{@pkginfo[:title] + '_' + @pkginfo[:version] + '.dmg'}"
    target.gsub!(/\s/, "_")
    target = "#{@builddir + '/' + target}"
    

    cmd = [HDIUTIL,
      ' create ',
      # '-verbose ',
      '-srcfolder ' + "\"#{source}\"",
      ' ' + "\"#{target}\""
      ]
        
    if File.exists?(source)
      puts "Rolling up: #{source}"
      # puts "Command: #{cmd}"
      unless system(cmd.join(" "))
        raise PkgProjErr.new("There was a problem creating the disk image...")
        exit $?
      end
    else
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("There's nothing to package: #{source}")
      exit 1
    end
  
  end
  
  # Generates the boilerpate HTML files for the packages "Welcome", "ReadMe", and "License" files.
  # * Globs the TEMPLATES directory looking for HTML template files
  # * For each template file, generate a new boilerplate HTML file
  def boil
    pkgroot = @projectdir + '/pkgroot'
    
    unless Dir.chdir(@projectdir)
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("Could not chdir to projectdir: #{@projectdir}")
      exit 1
    end
    unless File.exists?(@pkgyaml)
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("Project is missing a configuration file: #{File.basename(@pkgyaml)} not found")
      exit 1
    end
    unless File.exists?(@resources)
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("Project directory is missing a resources dir: #{@resources}")
      exit 1
    end
    updateyaml(@pkginfo)
    resources = Dir.glob(TEMPLATES + '/' + "*.thtml")
    resources.each do |template|
      resource = ResourceWriter.new(@pkginfo, template)
      resource.write
    end
    
  end
  
  # Initialize the newly created project directory as a git repo
  # * Project Root: arg handed to the prep method
  # * unimplemented
  def git()
    if @projectdir.absolute?
      begin
        Dir.chdir(@projectdir)
        `git init`
      rescue Errno
        $stderr.puts "#{self.class}: #{$!}"
        return $!
      end
    else
      raise
    end
  end
  
  # Generate a new package using the project dir's "pkgroot" as its source
  # * Receives its args from the options array
  # * Names the resulting package file according to values stored in the YAML
  # * Adds additional information to the package's Info.plist if such options are set
  def package(args)
    @ok = false
    pkgroot = @projectdir + '/pkgroot'
    
    unless Dir.chdir(@projectdir)
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("Could not chdir to projectdir: #{@projectdir}")
      exit 1
    end
    unless File.exists?(@pkgyaml)
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("Project is missing a configuration file: #{File.basename(@pkgyaml)} not found")
      exit 1
    end
    unless File.exists?(pkgroot)
      puts "Project Directory: #{@projectdir}"
      raise PkgProjErr.new("Project directory is missing a pkgroot: #{pkgroot}")
      exit 1
    end
    
    printf "\nOK to start packaging?  Press y to confirm, or another key to exit: "
    answer = gets.chomp
    unless answer == "y"
      raise PkgProjErr.new("Exiting at user request...")
      exit 1
    else    
      # Define output target and delete if already present
      target = '"' + @builddir + '/' + @pkginfo[:title] + '-' + @pkginfo[:version] + '.pkg' + '"'
      if File.exists?(target.gsub(/"/,''))
        puts "Removing previous target: #{target}"
        FileUtils.rm_rf(target.gsub(/"/,''))
      end
      # Construct the PackageMaker args      
      cmd = [PKGMAKER,
        '-r ' + "\"#{@pkgroot}\"",
        '-t ' + "\"#{@pkginfo[:title]}\"",
        '-i ' + "#{@pkginfo[:id]}",
        '-n ' + "#{@pkginfo[:version]}",
        '-e ' + "\"#{@resources}\"",
        '-s ' + "\"#{@scripts}\"",
        '-g ' + "\"#{@pkginfo[:min_target_os_version]}\"",
        '-o ' + target
        ]
      
      cmd << '-m ' if @pkginfo[:suggested_perms] == 'false'
      cmd << '-v ' unless @pkginfo[:verbose] == 'false'
      cmd << @pkginfo[:filter].collect { |exp| '-x ' +  "\'#{exp}\'" }
      
      # puts cmd.join(" ")
      # exit 0      
      unless system(cmd.join(" "))
        raise PkgProjErr.new("There was a problem building the package...")
        exit $?
      end
      # Finish up with some package Info.plist munging
      target.gsub!(/"/,"")
      setpkgoptions(target, @pkginfo)
    end
    
  end
  
  private
  
  # Sets extra package options
  # * These options are determined by YAML file configurations
  # * Accepts two params: a path to the Info.plist & a hash containing options
  def setpkgoptions(target, pkginfo)
    setnorelocate(target) if pkginfo[:relocate] == "false"
    setrestartaction(target, pkginfo[:restart])
  end
  
  # Removes the package's ability to be automatically relocated by Installer
  # * This package flag is turned on by default.
  # * Method:
  #   * Deletes the package's Info.plist IFPkgPathMappings key
  #   * Deletes the package's TokenDefinitions.plist file
  def setnorelocate(target)
    tokendefs = target + TOKENDEFS
    info = target + INFO
    vars = Plist.load_(info)
    unless vars.nil?
      if vars["IFPkgPathMappings"]
        vars.delete("IFPkgPathMappings")
      else
        return
      end
      puts "Removing the package's relocation flag..."
      unless vars.store_(info, false)
        puts "FAILED!"
      end
    end
    puts "Removing TokenDefinitions..."
    unless FileUtils.rm(tokendefs)
      puts "FAILED!"
    end 
  end
  
  # Set the reboot flag according to YAML config
  # * Valid options: none, logout, restart, & shtudown
  def setrestartaction(target, action)
    info = target + INFO
    vars = Plist.load_(info)    
    case action
      when /none/i
        action = "None"
      when /logout/i
        action = 'RequiredLogout'
      when /restart/i
        action = 'RequiredRestart'
      when /shutdown/i
        action = "ShutDown"
      else
        action = "None"
    end
    vars["IFPkgFlagRestartAction"] = action
    vars.store_(info, false)
  end
  
  # Used in the interactive configuration loop to grab input from the user
  def getinput(tag)
    printf "\tPackage #{tag.to_s.capitalize} (#{@pkginfo[tag]}): "
    input = gets.chomp
    unless input == ""
      @pkginfo[tag] = input
    end
  end
  
  
end

class ResourceWriter
  
  attr_reader :filein, :text, :result
  
  # Opens a template file, passes in YAML variables, and binds them to "@result"
  def initialize(vars, filein)
    @pkginfo = vars
    @filein = filein
    if File.exists?(@filein)
      @text = File.read(@filein)
      template = ERB.new(@text, 0, "%<>")
      @result = template.result(binding)
    end
    # puts @result
  end
  
  # Generates a new file from the contents of the "@result" variable
  def write
    base = File.basename(@filein)
    prefix = "./resources/"
    fileout = "#{prefix + base.gsub(/thtml/, "html")}"
    # puts "Fileout: #{fileout}"
    puts "Generating: #{File.expand_path(fileout)}"
    target = File.open(fileout, 'w')
    target.puts @result
    target.close
  end
  
end






