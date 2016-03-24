
# Do not use cpu-0
CPU_COUNT = 8 - 1

APP_DIR = "/var/www/live/current"


# rainbows config
Rainbows! do
  use :ThreadPool
  worker_connections 32
  client_max_body_size 5*1024*1024 # 5 megabytes
  client_header_buffer_size 2 * 1024 # 2 kilobytes
end


# Use at least one worker per core if you're on a dedicated server,
# more will usually help for _short_ waits on databases/caches.
worker_processes 8

# If running the master process as root and the workers as an unprivileged
# user, do this to switch euid/egid in the workers (also chowns logs):
# user "unprivileged_user", "unprivileged_group"

# tell it where to be
working_directory APP_DIR

# listen on both a Unix domain socket and a TCP port,
# we use a shorter backlog for quicker failover when busy

# listen 8080, :tcp_nopush => true
listen "unix:#{APP_DIR}/tmp/sockets/rainbows.sock", :backlog => 2048


# nuke workers after 30 seconds instead of 60 seconds (the default)
timeout 30

# feel free to point this anywhere accessible on the filesystem
pid  "#{APP_DIR}/tmp/pids/rainbows.pid"


# By default, the Unicorn logger will write to stderr.
# Additionally, ome applications/frameworks log to stderr or stdout,
# so prevent them from going to /dev/null when daemonized here: 

stderr_path "#{APP_DIR}/log/unicorn.stderr.log"
stdout_path "#{APP_DIR}/log/unicorn.stdout.log"

preload_app false


before_fork do |server, worker|
  puts "process #{Process.pid} executing before_fork"
  # # This allows a new master process to incrementally
  # # phase out the old master process with SIGTTOU to avoid a
  # # thundering herd (especially in the "preload_app false" case)
  # # when doing a transparent upgrade.  The last worker spawned
  # # will then kill off the old master process with a SIGQUIT.
  old_pid = "#{server.config[:pid]}.oldbin"

  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
  
  #
  # Throttle the master from forking too quickly by sleeping.  Due
  # to the implementation of standard Unix signal handlers, this
  # helps (but does not completely) prevent identical, repeated signals
  # from being lost when the receiving process is busy.
  # sleep 1
end


after_fork do |server, worker|
  puts "process #{Process.pid} executing after_fork"
  worker_num = worker.nr + 1
  affinity_cpu = worker_num % CPU_COUNT
  affinity_cpu = CPU_COUNT if affinity_cpu == 0
  print "Worker##{worker_num} pid##{Process.pid} affinity to CPU##{affinity_cpu} [ Done. ]\n"
  
  `taskset -pc #{affinity_cpu} #{Process.pid}`
  
  worker.user('www', 'www') if Process.euid == 0
end

