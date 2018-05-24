#!/usr/bin/env ruby
require 'fileutils'
require 'ipaddr'
require 'json'

CHECKS="api/checks/index.get.json"
CLIENT="api/clients"
CLIENTS="api/clients/index.get.json"
CLIENTS_METRIC="api/metrics/clients/index.get.json"
EVENTS="api/events/index.get.json"
EVENTS_METRIC="api/metrics/events/index.get.json"
KEEPALIVES_METRIC="api/metrics/keepalives_avg_60/index.get.json"
REQUESTS_METRIC="api/metrics/check_requests/index.get.json"
RESULTS_METRIC="api/metrics/results/index.get.json"

WHAT=ARGV[0]
COUNT=ARGV[1].to_i

def client
  # Load a random client
  file = File.read(CLIENTS)
  clients = JSON.parse(file)
  client = clients.sample
  client["subscribers"] = get_subscriptions
  client["cpu"] = "https://www.hostedgraphite.com/d70c9eeb/graphite/render/?from=09%3A00_20170410&until=12%3A00_20170410&width=400&height=250&target=com.sensuapp.demo.cpu.user&target=com.sensuapp.demo.cpu.steal&target=com.sensuapp.demo.cpu.system&_uniq=0.736130523628497&bgcolor=white&fgcolor=black&force_image=.jpg"
  # Create the directory structure
  client_path = "#{CLIENT}/#{client["name"]}"
  FileUtils.mkdir_p "#{client_path}/history"

  # Create the response to /clients/:client
  File.open("#{client_path}/index.get.json", "w") do |f|
    f.write(JSON.pretty_generate(client))
  end

  # Retrieve all checks for this client
  file = File.read(CHECKS)
  checks = JSON.parse(file)

  # Transform these checks to history
  prng = Random.new
  for check in checks
    check["check"] = check["name"]
    check["last_execution"] = Time.now.to_i
    check["last_status"] = prng.rand(0..3)
    check["last_result"] = {
      :name => check["name"]
    }
    check["last_result"]["output"] = check["output"] if check["last_status"] != 0

    if check["name"] == "sensu_website"
      check["last_status"] = 2
      check["history"] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2]
      check["last_result"]["command"] = check["command"]
      check["last_result"]["duration"] = 0.647
      check["last_result"]["executed"] = Time.now.to_i
      check["last_result"]["interval"] = 60
      check["last_result"]["issued"] = Time.now.to_i
      check["last_result"]["standalone"] = true
      check["last_result"]["status"] = 2
      check["last_result"]["type"] = "standard"
    end
  end

  # Create the response to /clients/:client/history
  File.open("#{client_path}/history/index.get.json", "w") do |f|
    f.write(JSON.pretty_generate(checks))
  end

  puts "Generated the client #{client["name"]}"
end

def clients
  clients = []
  subscriptions = get_subscriptions

  i = 0
  while i < COUNT
    # We want to include a random number of subscriptions to every client
    prng = Random.new
    count_subscriptions = prng.rand(1..3)

    client = {
      :name => "i-#{8.times.map { [*'0'..'9', *'a'..'z'].sample }.join}",
      :address => IPAddr.new(10*2**24 + rand(2**24),Socket::AF_INET).to_string,
      :subscribers => subscriptions.sample(count_subscriptions),
      :timestamp => Time.now.to_i,
      :version => "0.28.5"
    }
    clients.push(client)

    i += 1
  end

  File.open(CLIENTS, "w") do |f|
    f.write(JSON.pretty_generate(clients))
  end
end

def events
  events = []

  # Load the checks
  file = File.read(CHECKS)
  checks = JSON.parse(file)

  # Load the specified number of clients
  file = File.read(CLIENTS)
  clients = JSON.parse(file)
  clients = clients.sample(COUNT)

  prng = Random.new

  for client in clients
    check = get_checks(client["subscribers"].sample).sample

    event = {
      :check => {
        :command => check["command"],
        :name => check["name"],
        :issued => Time.now.to_i,
        :output => check["output"],
        :status => prng.rand(1..3)
      },
      :client => {
        :name => client["name"],
        :address => client["address"],
        :subscriptions => client["subscribers"]
      },
      :last_ok => Time.now.to_i,
    }

    events.push(event)
  end

  File.open(EVENTS, "w") do |f|
    f.write(JSON.pretty_generate(events))
  end
end


def midpoint_displace(start_point, end_point, max, falloff, points, count, i=0)
  i += 1
  return if i >= count

  distance = end_point - start_point
  mid_point = start_point + distance / 2
  d = max * (rand() * 2 - 1)

  new_point = mid_point + d

  midpoint_displace(new_point, end_point, max*falloff, falloff, points, count, i)
  points.push(new_point.to_i)
  midpoint_displace(new_point, end_point, max*falloff, falloff, points, count, i)

  points
end

def clients_metric
  y_points = midpoint_displace(2170, 2173, 100, 0.7, [2170], 8)

  metrics = {
    :metrics => "clients",
    :points => []
  }

  i = 0
  timestamp = 1491509380
  while i < 128
    point = []
    point.push(timestamp)
    point.push(y_points[i])
    metrics[:points].push(point)

    i += 1
    timestamp += 10
  end

  File.open(CLIENTS_METRIC, "w") do |f|
    f.write(JSON.pretty_generate(metrics))
  end
end

def events_metric
  y_points = midpoint_displace(40, 26, 30.0, 0.7, [40], 8)

  metrics = {
    :metrics => "events",
    :points => []
  }

  i = 0
  timestamp = 1491509380
  while i < 128
    point = []
    point.push(timestamp)
    point.push(y_points[i])
    metrics[:points].push(point)

    i += 1
    timestamp += 10
  end

  File.open(EVENTS_METRIC, "w") do |f|
    f.write(JSON.pretty_generate(metrics))
  end
end

def keepalives_metric
  y_points = midpoint_displace(2170, 2173, 100, 0.7, [2170], 8)

  metrics = {
    :metrics => "keepalives",
    :points => []
  }

  i = 0
  timestamp = 1491509380
  while i < 128
    point = []
    point.push(timestamp)
    point.push(y_points[i])
    metrics[:points].push(point)

    i += 1
    timestamp += 10
  end

  File.open(KEEPALIVES_METRIC, "w") do |f|
    f.write(JSON.pretty_generate(metrics))
  end
end

def requests_metric
  y_points = midpoint_displace(100, 100, 50, 0.7, [100], 8)

  metrics = {
    :metrics => "requests",
    :points => []
  }

  i = 0
  timestamp = 1491509380
  while i < 128
    point = []
    point.push(timestamp)
    point.push(y_points[i])
    metrics[:points].push(point)

    i += 1
    timestamp += 10
  end

  File.open(REQUESTS_METRIC, "w") do |f|
    f.write(JSON.pretty_generate(metrics))
  end
end

def results_metric
  y_points = midpoint_displace(1000, 1000, 500, 0.7, [1000], 8)

  metrics = {
    :metrics => "results",
    :points => []
  }

  i = 0
  timestamp = 1491509380
  while i < 128
    point = []
    point.push(timestamp)
    point.push(y_points[i])
    metrics[:points].push(point)

    i += 1
    timestamp += 10
  end

  File.open(RESULTS_METRIC, "w") do |f|
    f.write(JSON.pretty_generate(metrics))
  end
end

# Get all checks with the specified subscription
def get_checks(subscription)
  c = []

  # Load the checks
  file = File.read(CHECKS)
  checks = JSON.parse(file)

  for check in checks
    if check["subscribers"].include? subscription
      c.push(check)
    end
  end

  return c
end

# Retrieve all subscriptions from the checks
def get_subscriptions
  subscriptions = []

  # Load the checks
  file = File.read(CHECKS)
  checks = JSON.parse(file)

  for check in checks
    subscriptions |= check["subscribers"]
  end

  return subscriptions
end

case WHAT
when "client"
  client
when "clients"
  clients
when "events"
  events
when "metrics"
  clients_metric
  events_metric
  keepalives_metric
  requests_metric
  results_metric
else
  puts "Unrecognized element"
  exit
end
