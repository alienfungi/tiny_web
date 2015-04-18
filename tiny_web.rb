require 'pry'
require 'socket'
require 'uri'

class TinyWeb
  DEFAULT_PORT = 8008
  WEB_ROOT = './public'
  CONTENT_TYPE_MAPPING = {
    'css'  => 'text/css',
    'html' => 'text/html',
    'js'   => 'text/javascript',
    'txt'  => 'text/plain',
    'png'  => 'image/png',
    'jpg'  => 'image/jpeg'
  }.freeze
  DEFAULT_CONTENT_TYPE = 'application/octet-stream'

  def initialize(port = DEFAULT_PORT)
    @server = TCPServer.new('localhost', port)
  end

  def start
    loop do
      socket = nil
      begin
        socket = server.accept
        request_line = socket.gets
        path = requested_file(request_line)
        path = File.join(path, 'index.html') if File.directory?(path)
        if File.exist?(path) && !File.directory?(path)
          send_file(path, socket)
        else
          send_message('File not found\n', socket)
        end
      ensure
        socket.close unless socket.nil? || socket.closed?
      end
    end
  rescue Interrupt => e
    puts "\nGoodbye"
  ensure
  end

  private

  def content_type(path)
    ext = File.extname(path).split('.').last
    CONTENT_TYPE_MAPPING.fetch(ext, DEFAULT_CONTENT_TYPE)
  end

  def header(type, length)
    "HTTP/1.1 200 OK\r\n" +
    "Content-Type: #{ type }\r\n" +
    "Content-Length: #{ length }\r\n" +
    "Connection: close\r\n"
  end

  def requested_file(request_line)
    request_uri = request_line.split(' ')[1]
    path = URI.unescape(URI(request_uri).path)
    clean = []
    parts = path.split('/')

    parts.each do |part|
      next if part.empty? || part == '.'
      part == '..' ? clean.pop : clean << part
    end

    File.join(WEB_ROOT, *clean)
  end

  def send_file(path, socket)
    File.open(path, 'rb') do |file|
      socket.print header(content_type(file), file.size)
      socket.print "\r\n"
      IO.copy_stream(file, socket)
    end
  end

  def send_message(message, socket)
    socket.print header('text/plain', message.size)
    socket.print "\r\n"
    socket.print message
  end

  def server; @server; end
end

tiny_web = TinyWeb.new
tiny_web.start
