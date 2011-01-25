#!/usr/bin/ruby

# Opens the Boilermaker documentation
def opendocs
  begin
    cmd = ['/usr/bin/open', 'file:///Library/Ruby/Site/1.8/boilermaker/doc/index.html']
    system(cmd.join(" "))
  rescue => error
    puts error.message + "\n"
    exit $!
  end
end

opendocs()

exit 0
