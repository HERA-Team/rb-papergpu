require 'rubygems'
require 'rubygems/package_task'

# Get KATCP::VERSION
require './lib/papergpu/version.rb'

spec = Gem::Specification.new do |s|
  # Basics
  s.name = 'papergpu'
  s.version = PaperGPU::VERSION
  s.summary = 'Ruby classes for the PAPER GPU correlator.'
  s.description = <<-EOD
    Ruby classes for the PAPER GPU correlator.  Uses the katcp gem to talk to
    the ROACH-based F engines and the redis gem to talk to the X engines via a
    centralized Redis instance.
    EOD
  #s.platform = Gem::Platform::Ruby
  s.required_ruby_version = '>= 1.8.7'
  s.add_dependency('katcp', '~> 0.0.8.dev')
  s.add_dependency('redis', '~> 3.0.2')

  # About
  s.authors = 'David MacMahon'
  s.email = 'davidm@astro.berkeley.edu'
  s.homepage = 'http://astro.berkeley.edu/~davidm/rb-papergpu.git'
  #s.rubyforge_project = 'rb-papergpu' 

  # Files, Libraries, and Extensions
  s.files = %w[
    bin/pf_bframe.rb
    lib/papergpu.rb
    lib/papergpu/fengine.rb
    lib/papergpu/typemap.rb
    lib/papergpu/version.rb
  ]
  s.require_paths = ['lib']
  #s.autorequire = nil
  #s.bindir = 'bin'
  s.executables = %w[
    pf_bframe.rb
  ]
  #s.default_executable = nil

  # C compilation
  #s.extensions = %w[ ext/extconf.rb ]

  # Documentation
  s.rdoc_options = ['--title', "Ruby/PaperGPU #{s.version} Documentation"]
  #s.rdoc_options << '-m' << 'README'
  s.has_rdoc = true
  #s.extra_rdoc_files = %w[README]

  # Testing TODO
  #s.test_files = [test/test.rb]
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
