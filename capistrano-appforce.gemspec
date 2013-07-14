# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capistrano-appforce/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "capistrano-appforce`"
  gem.version       = CapistranocwAppforceCloudDeploy::VERSION
  gem.authors         = ["Jack Bishop"]
  gem.email           = ["jack.bishop@synctree.com"]
  gem.homepage        = "http://github.com/synctree/capistrano-appforce"
  gem.summary         = "Cloud server provisioning using Capistrano, Fog and Chef"
  gem.description = "Deploy any type of server to one of many cloud providers via capistrano tasks using this gem"

  gem.add_dependency(%q<capistrano>)
  gem.add_dependency(%q<fog>)
  gem.add_dependency(%q<chef>)

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
