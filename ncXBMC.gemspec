Gem::Specification.new do |s|
  s.name = %q{ncXBMC}
  s.version = '0.2.1'
  s.date = %q{2009-05-16}
  s.authors = ["Cedric TESSIER"]
  s.email = "nezetic at gmail d o t com"
  s.summary = %q{ncXBMC is a remote XBMC client, with an ncurses interface}
  s.homepage = %q{http://github.com/nezetic/ncXBMC}
  s.description = %q{ncXBMC is a remote XBMC client, with an ncurses interface, which aims to provide a full control of the music player over a local network.
  
  It can be used to browse library, manage playlist, and control playback.}
  s.files = %W[README bin/ncxbmc.rb]
  s.has_rdoc = false 
  s.executables = ['ncxbmc.rb']
  s.default_executable = 'ncxbmc.rb'
  s.add_dependency('ncurses', '>= 0.9.1')
  s.add_dependency('ruby-xbmc', '>= 0.1')
end 
