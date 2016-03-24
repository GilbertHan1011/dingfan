# unicorn -c /var/www/jjweb-boom/current/config/unicorn.conf.rb -E production -D

# do not use cpu-0
CPU_COUNT = 8 - 1

APP_DIR = "/var/www/live/current"

worker_processes 16


# Help ensure your application will always spawn in the symlinked
# "current" directory that Capistrano sets up.
working_directory APP_DIR

# Restart any workers that haven't responded in 30 seconds
timeout 30

# Listen on a Unix data socket
#listen  APP_DIR + '/tmp/sockets/unicorn.sock', :backlog => 2564
listen 8080, :tcp_nopush => true

pid	 APP_DIR + "/tmp/pids/unicorn.pid"


# log
stderr_path "#{APP_DIR}/log/unicorn.stderr.log"
stdout_path "#{APP_DIR}/log/unicorn.stdout.log"


# Load rails into the master before forking workers
# for super-fast worker spawn times
preload_app true

##
# REE
# http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow

# if GC.respond_to?(:copy_on_write_friendly=)
#   GC.copy_on_write_friendly = true
# end


before_fork do |server, worker|
  ##
  # the following is highly recomended for Rails + "preload_app true"
  # as there's no need for the master process to hold a connection
  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!
  
  ##
  # kill old when restart
  old_pid = "#{server.config[:pid]}.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
  
end


after_fork do |server, worker|
  ##
  # Unicorn master loads the app then forks off workers - because of the way
  # Unix forking works, we need to make sure we aren't using any of the parent's
  # sockets, e.g. db connection
  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
  
  
  worker_num = worker.nr + 1
  affinity_cpu = worker_num % CPU_COUNT
  affinity_cpu = CPU_COUNT if affinity_cpu == 0
  print "Worker##{worker_num} pid##{Process.pid} affinity to CPU##{affinity_cpu} [ Done. ]\n"
  
  `taskset -pc #{affinity_cpu} #{Process.pid}`

  ##
  # drop permissions to "www:www" in the worker
  # generally there's no reason to start Unicorn as a priviledged user
  # as it is not recommended to expose Unicorn to public clients.
  worker.user('www', 'www') if Process.euid == 0
  
  # Reconnect memcached
  # Rails.cache.reset
end
