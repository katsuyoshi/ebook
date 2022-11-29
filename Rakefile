require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*test.rb']
  t.verbose = true
end

task :default => :test

desc 'Launch the ngrok proxy'
task :proxy do |t|
  system "ngrok http 4567"
end