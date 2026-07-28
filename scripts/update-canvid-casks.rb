#!/usr/bin/env ruby

require "digest"
require "net/http"
require "tempfile"
require "uri"

module UpdateCanvidCasks
  class UpdateError < StandardError; end
  class RetryableHttpError < UpdateError; end

  Channel = Struct.new(
    :name,
    :feed_url,
    :artifact_url,
    :version_pattern,
    :cask_path,
    keyword_init: true
  )

  class HttpClient
    MAX_REDIRECTS = 5
    MAX_ATTEMPTS = 3

    def stream(url)
      attempts = 0

      begin
        attempts += 1
        request(URI(url), MAX_REDIRECTS) do |response|
          chunks = Enumerator.new do |stream|
            received_bytes = 0
            response.read_body do |chunk|
              received_bytes += chunk.bytesize
              stream << chunk
            end
            expected_bytes = response["content-length"]&.to_i
            if expected_bytes && received_bytes != expected_bytes
              raise EOFError, "expected #{expected_bytes} bytes, received #{received_bytes}"
            end
          end
          yield chunks
        end
      rescue Net::OpenTimeout, Net::ReadTimeout, EOFError, Errno::ECONNRESET,
             Errno::ECONNREFUSED, SocketError, RetryableHttpError => error
        retry if attempts < MAX_ATTEMPTS

        raise UpdateError, "request failed for #{url}: #{error.message}"
      end
    end

    private

    def request(uri, redirects_remaining, &block)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 30,
        read_timeout: 60
      ) do |http|
        http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
          case response
          when Net::HTTPSuccess
            block.call(response)
          when Net::HTTPRedirection
            raise UpdateError, "too many redirects for #{uri}" if redirects_remaining.zero?

            location = response["location"]
            raise UpdateError, "redirect without Location for #{uri}" unless location

            request(uri + location, redirects_remaining - 1, &block)
          else
            error_class = response.code.to_i == 408 ||
                          response.code.to_i == 429 ||
                          response.code.to_i >= 500 ? RetryableHttpError : UpdateError
            raise error_class, "HTTP #{response.code} for #{uri}"
          end
        end
      end
    end
  end

  module_function

  def run(channels, client: HttpClient.new)
    prepared_updates = []
    channels.each do |channel|
      feed = nil
      client.stream(channel.feed_url) do |chunks|
        feed = +""
        chunks.each { |chunk| feed << chunk }
      end
      remote_version = extract_version(feed, channel)
      current_contents = File.read(channel.cask_path)
      current_version = current_contents[/^\s*version "([^"]+)"$/, 1]
      raise UpdateError, "missing version in #{channel.cask_path}" unless current_version

      next if current_version == remote_version

      digest = nil
      client.stream(channel.artifact_url.call(remote_version)) do |chunks|
        digest = Digest::SHA256.new
        chunks.each { |chunk| digest.update(chunk) }
      end

      updated_contents = replace_field(current_contents, "version", remote_version, channel)
      updated_contents = replace_field(updated_contents, "sha256", digest.hexdigest, channel)
      prepared_updates << [channel.cask_path, updated_contents]
    end

    prepared_updates.each { |path, contents| atomic_write(path, contents) }
    !prepared_updates.empty?
  rescue UpdateError
    raise
  rescue StandardError => error
    raise UpdateError, error.message
  end

  def extract_version(feed, channel)
    versions = feed.lines.map do |line|
      match = line.match(/\Aversion:\s*['"]?([^'"\s]+)['"]?\s*\z/)
      match[1] if match
    end.compact
    raise UpdateError, "#{channel.name} feed must contain one top-level version" unless versions.length == 1

    version = versions.first
    unless channel.version_pattern.match?(version)
      raise UpdateError, "invalid #{channel.name} version: #{version.inspect}"
    end

    version
  end

  def replace_field(contents, field, value, channel)
    pattern = /^(\s*#{field} ")[^"]+(")$/
    raise UpdateError, "missing #{field} in #{channel.cask_path}" unless contents.scan(pattern).length == 1

    contents.sub(pattern, "\\1#{value}\\2")
  end

  def atomic_write(path, contents)
    Tempfile.create([".update-canvid-cask", ".rb"], File.dirname(path)) do |file|
      file.write(contents)
      file.flush
      file.fsync
      file.chmod(File.stat(path).mode)
      File.rename(file.path, path)
    end
  end

  def production_channels(repository_root)
    [
      Channel.new(
        name: "stable",
        feed_url: "https://installers.canvid.com/latest-mac.yml",
        artifact_url: lambda { |version|
          "https://installers.canvid.com/Canvid-v#{version}-mac.dmg"
        },
        version_pattern: /\A\d+\.\d+\.\d+\z/,
        cask_path: File.join(repository_root, "Casks", "canvid.rb")
      ),
      Channel.new(
        name: "beta",
        feed_url: "https://installers.canvid.com/beta-mac.yml",
        artifact_url: lambda { |version|
          "https://installers.canvid.com/Canvid%20Beta-v#{version}-mac.dmg"
        },
        version_pattern: /\A\d+\.\d+\.\d+-beta\.\d+\z/,
        cask_path: File.join(repository_root, "Casks", "canvid@beta.rb")
      )
    ]
  end
end

if $PROGRAM_NAME == __FILE__
  root = File.expand_path("..", __dir__)
  changed = UpdateCanvidCasks.run(UpdateCanvidCasks.production_channels(root))
  puts(changed ? "Updated Canvid casks." : "Canvid casks are already current.")
end
