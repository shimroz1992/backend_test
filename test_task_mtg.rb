require 'net/http'
require 'json'
require 'terminal-table'
require 'thread'  # for Mutex
require 'colorize'



class TestTask
	THREAD_COUNT = 20  # tweak this number for maximum performance.

	def initialize
		url = URI('https://api.magicthegathering.io/v1/cards')
		@card = Net::HTTP.get(url)
		pick_card = JSON.load(@card)
		@cards = pick_card["cards"] 
		@results1 = []
		@results2 = []
		@results3 = []
	end

	def get_set_cards
		@cards.each do |hash_row|
			unless (@results1.find { |h| h[:set] == hash_row["set"] })
				@results1 << {set: hash_row["set"], data: [hash_row]}
			else
				@results1.find { |h| break h[:data]  if h[:set] == hash_row["set"] } << hash_row
			end
		end
		print_table(@results1)
	end

	def get_rarity_cards
		@cards.each do |hash_row|
			unless (@results2.find { |h| h[:set] == hash_row["set"] && h[:rarity] == hash_row["rarity"]})
				@results2 << {set: hash_row["set"], rarity: hash_row["rarity"], data: [hash_row]}
			else
				@results2.find { |h| break h[:data]  if h[:set] == hash_row["set"] && h[:rarity] == hash_row["rarity"] } << hash_row
			end
		end
		print_table(@results2)
	end

	def get_cards_by_colours
		sample_url = "https://api.magicthegathering.io/v1/cards?page="
		threads = []
		tags = []
		tags_mutex = Mutex.new
		urls = []
		# no of page we can limit here
		(1..5).each do |no| urls << (sample_url+"#{no}") end
			urls.each do |url|
				threads << Thread.new(url, tags) do |url, tags|
					tag = fetch_tag(url)
					tags_mutex.synchronize { tags << tag }
				end
			end
			threads.each(&:join)
			tags = []
			mutex = Mutex.new
			THREAD_COUNT.times.map {
				Thread.new(urls, tags) do |urls, tags|
					while url = mutex.synchronize { urls.pop }
						tag = fetch_tag(url)
						mutex.synchronize { tags << tag }
					end
				end
			}.each(&:join)
		end

		def fetch_tag(url)
			@results = []
			url = URI(url)
			@card = Net::HTTP.get(url)
			data = JSON.load(@card)
			puts url
			@cards.each do |data|
				set_name = "Tenth Edition"
			## "Khans of Tarkir"
			if data["setName"] == set_name && (data["colors"] == ["Red"] || data["colors"] == ["Blue"])
				unless (@results3.find { |h| h[:set] == data["set"] && h[:colors] == data["colors"]})
					@results << {set: data["set"], colors: data["colors"], data: [data]}
				else
					@results.find { |h| break h[:data]  if h[:set] == data["set"] && h[:colors] == data["colors"] } << data
				end
			end
		end
		print_table(@results)
	end

	def print_table(data)
		table = Terminal::Table.new do |t|
			t << ["Set", "Rarity","Name", "Colors", "setName"]
			data.each do |data|
				t << :separator
				data[:data].each do |item|
					t << [data[:set], "#{item["rarity"]}","#{item["set"]}", "#{item["colors"]}", "#{item["setName"]}"]
				end
				t << :separator 
			end
		end
		puts table
	end
end

puts "Group by Set".red
TestTask.new.get_set_cards

puts "Group by Set and rarity".red
TestTask.new.get_rarity_cards

puts "For specific setName and colors".red
TestTask.new.get_cards_by_colours
