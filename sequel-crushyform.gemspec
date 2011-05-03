Gem::Specification.new do |s| 
  s.name = 'sequel-crushyform'
  s.version = "0.0.1"
  s.platform = Gem::Platform::RUBY
  s.summary = "A Sequel plugin that helps building forms"
  s.description = "A Sequel plugin that helps building forms. It basically does them for you so that you can forget about the boring part."
  s.files = `git ls-files`.split("\n").sort
  s.require_path = './lib'
  s.author = "Mickael Riga"
  s.email = "mig@mypeplum.com"
  s.homepage = "http://github.com/mig-hub/sequel-crushyform"
end