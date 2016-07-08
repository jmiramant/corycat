require 'net/http'
require 'net/ftp'
require 'uri'
require 'date'

START_YEAR = 1987
BASE_URL = 'http://tsdata.bts.gov/PREZIP/On_Time_On_Time_Performance_'
BASE_FILE_NAME = 'On_Time_On_Time_Performance_'

def create_directory(dirname)
  unless Dir.exists?(dirname)
    Dir.mkdir(dirname)
  else
    puts "Skipping creating directory " + dirname + ". It already exists."
  end
end

def read_uris_from_file(file)
  uris = Array.new
  File.open(file).each do |line|
    line = line.strip
    next if line == nil || line.length == 0
    parts = line.split(' ')
    pair = Hash[ [:resource, :filename].zip(parts) ]
    uris.push(pair)
  end
  uris
end

def download_resource(resource, filename)
  uri = URI.parse(resource)
  case uri.scheme.downcase
  when /http|https/
    http_download_uri(uri, filename)
  when /ftp/
    ftp_download_uri(uri, filename)
  else
    puts "Unsupported URI scheme for resource " + resource + "."
  end
end

def http_download_uri(uri, filename)
  puts "Starting HTTP download for: " + uri.to_s
  http_object = Net::HTTP.new(uri.host, uri.port)
  http_object.use_ssl = true if uri.scheme == 'https'
  begin
    http_object.start do |http|
      request = Net::HTTP::Get.new uri.request_uri
      http.read_timeout = 500
      http.request request do |response|
        open filename, 'w' do |io|
          response.read_body do |chunk|
            io.write chunk
          end
        end
      end
    end
  rescue Exception => e
    puts "=> Exception: '#{e}'. Skipping download."
    return
  end
  puts "Stored download as " + filename + "."
end

def ftp_download_uri(uri, filename)
  puts "Starting FTP download for: " + uri.to_s + "."
  dirname = File.dirname(uri.path)
  basename = File.basename(uri.path)
  begin
    Net::FTP.open(uri.host) do |ftp|
      ftp.login
      ftp.chdir(dirname)
      ftp.getbinaryfile(basename)
    end
  rescue Exception => e
    puts "=> Exception: '#{e}'. Skipping download."
    return
  end
  puts "Stored download as " + filename + "."
end

def download_resources(pairs)
  pairs.each do |pair|
    filename = pair[:filename].to_s
    resource = pair[:resource].to_s
    unless File.exists?(filename)
      download_resource(resource, filename)
    else
      puts "Skipping download for " + filename + ". It already exists."
    end
  end
end

def set_range
	start_year = START_YEAR
	Date.today.year - (start_year - 1)
end

def set_filename
	year_delta = set_range
	start_year = START_YEAR
	uris = Array.new

	year_delta.times do |year|
		12.times do |month|
			target = "#{START_YEAR + year}_#{month + 1}.zip"
			uris.push({resource: BASE_URL + target, filename: BASE_FILE_NAME + target})
		end
	end
	uris
end

def run
	uris = set_filename
	target_dir_name = 'transtats'
  create_directory(target_dir_name)
  Dir.chdir(target_dir_name)
  puts "Changed directory: " + Dir.pwd

  download_resources(uris)
end

run