ENV['GEM_HOME'] = '/home/danilat/.gems'
ENV['GEM_PATH'] = '$GEM_HOME:/usr/lib/ruby/gems/1.8'
Gem.clear_paths
require 'rubygems'

app_file = File.join(File.dirname(__FILE__), 'public/index')

require app_file

set :run, false
set :environment, :development
set :views, 'public/views'
set :public, 'public/public'
set :app_file, app_file
disable :run

run Sinatra::Application