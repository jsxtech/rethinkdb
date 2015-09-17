require 'pp'
require 'eventmachine'
# require_relative './importRethinkDB.rb'


$port ||= (ARGV[0] || ENV['RDB_DRIVER_PORT'] || raise('driver port not supplied')).to_i
ARGV.clear
$c = r.connect(port: $port).repl

r.table_create('test').run rescue nil
indexes = ['a', 'truncated', 'collision', 'collision_truncated']
r.table('test').index_create(*indexes).run rescue nil

[{max_batch_rows: 10}, {}].each {|runopts|
  puts "----- Testing with runopts #{runopts} -----";

  puts "-- Setting up simple table..."
  r.table('test').delete.run(runopts)
  res = r.table('test').insert((0...1000).map{|i| {id: i, a: i}}).run(runopts)
  raise "Insert failed." if res['inserted'] != 1000

  puts "Testing ordering..."
  res = r.table('test').run(runopts).to_a
  raise "Retrieve failed." if res.count != 1000
  res = r.table('test').order_by(index: 'id').run(runopts)
  raise "Ordered retrieve failed." if res.count != 1000
  res = r.table('test').order_by(index: r.desc('id')).run(runopts)
  raise "Descending retrieve failed." if res.count != 1000
  res = r.table('test').order_by(index: 'a').run(runopts)
  raise "Sindex retrieve failed." if res.count != 1000
  res = r.table('test').order_by(index: r.desc('a')).run(runopts)
  raise "Descending sindex retrieve failed." if res.count != 1000

  puts "Testing between..."
  res = r.table('test').between(200, 500).run(runopts).to_a
  raise "Retrieve failed." if res.count != 300
  res = r.table('test').order_by(index: 'id').between(200, 500).run(runopts)
  raise "Ordered retrieve failed." if res.count != 300
  res = r.table('test').order_by(index: r.desc('id')).between(200, 500).run(runopts)
  raise "Descending retrieve failed." if res.count != 300
  res = r.table('test').order_by(index: 'a').between(200, 500, index: 'a').run(runopts)
  raise "Sindex retrieve failed." if res.count != 300
  res = r.table('test').order_by(index: r.desc('a')).
          between(200, 500, index: 'a').run(runopts)
  raise "Descending sindex retrieve failed." if res.count != 300

  puts "Testing get_all..."
  res = r.table('test').get_all(10, 20, -1, 3, 4).run(runopts)
  raise "Get all failed." if res.to_a.count != 4
  res = r.table('test').get_all(10, 20, -1, 3, 4, index: 'a').run(runopts)
  raise "Get all failed." if res.to_a.count != 4
  keys = (0...100).map{|i| (i - 10)*2}
  res = r.table('test').get_all(*keys).run(runopts)
  raise "Get all failed." if res.to_a.count != 90
  res = r.table('test').get_all(*keys, index: 'a').run(runopts)
  raise "Get all failed." if res.to_a.count != 90

  ####

  puts "-- Setting up hard table..."
  r.table('test').delete.run(runopts)
  # RSI: multi
  input = (0...1000).map {|i|
    {
      id: i,
      truncated: 'a'*300 + sprintf("%05d", i),
      collision: i % 10,
      truncated_collision: 'a'*300 + sprintf("%05d", i % 10)
    }
  }
  r.table('test').insert(input).run(runopts)

  puts "Testing ordering..."
  res = r.table('test').run(runopts).to_a
  raise "Retrieve failed." if res.count != 1000
  res = r.table('test').order_by(index: 'id').run(runopts)
  raise "Ordered retrieve failed." if res.count != 1000
  res = r.table('test').order_by(index: r.desc('id')).run(runopts)
  raise "Descending retrieve failed." if res.count != 1000
}
puts "Done!"