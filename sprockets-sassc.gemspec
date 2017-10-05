# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'sprockets/sassc/version'

Gem::Specification.new do |s|
  s.name        = 'sprockets-sassc'
  s.version     = Sprockets::Sassc::VERSION
  s.authors     = ['Widget Works']
  s.email       = ['info@widgetworks.com.au']
  s.homepage    = 'http://github.com/widgetworks/sprockets-sassc'
  s.summary     = %q{Integrate Sassc with Sprockets environment}
  s.description = %q{Implementation of (sprockets-sass)[https://github.com/petebrowne/sprockets-sass] that uses the faster [Sassc](https://github.com/sass/sassc-ruby) implementation.}

  s.rubyforge_project = 'sprockets-sassc'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split('\n').map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency             'sprockets',         '~> 3.5'
  s.add_dependency             'tilt',              '~> 2.0'
  s.add_development_dependency 'appraisal',         '~> 0.5'
  s.add_development_dependency 'rspec',             '~> 2.13'
  s.add_development_dependency 'test_construct',    '~> 2.0'
  s.add_development_dependency 'sprockets-helpers', '~> 1.0'
  s.add_development_dependency 'sassc',             '~> 1.10'
  s.add_development_dependency 'compass',           '~> 1.0.0.alpha.19'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'pry'
end
