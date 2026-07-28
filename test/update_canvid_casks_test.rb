require "digest"
require "minitest/autorun"
require "socket"
require "stringio"
require "tmpdir"

require_relative "../scripts/update-canvid-casks"

class UpdateCanvidCasksTest < Minitest::Test
  Channel = UpdateCanvidCasks::Channel

  class DownloadClient
    attr_reader :artifact_requests

    def initialize(feeds:, artifacts: {}, failure_url: nil)
      @feeds = feeds
      @artifacts = artifacts
      @failure_url = failure_url
      @artifact_requests = []
    end

    def stream(url)
      raise UpdateCanvidCasks::UpdateError, "download failed" if url == @failure_url

      content = @feeds.fetch(url) do
        @artifact_requests << url
        @artifacts.fetch(url)
      end
      StringIO.open(content) do |io|
        yield Enumerator.new { |chunks| chunks << io.read(4) until io.eof? }
      end
    end
  end

  def setup
    @temporary_directory = Dir.mktmpdir
    @stable_path = File.join(@temporary_directory, "canvid.rb")
    @beta_path = File.join(@temporary_directory, "canvid@beta.rb")
    File.write(@stable_path, cask("1.2.3", "a" * 64))
    File.write(@beta_path, cask("1.3.0-beta.1", "b" * 64))

    @stable = Channel.new(
      name: "stable",
      feed_url: "https://feeds.example/stable.yml",
      artifact_url: ->(version) { "https://artifacts.example/Canvid-v#{version}-mac.dmg" },
      version_pattern: /\A\d+\.\d+\.\d+\z/,
      cask_path: @stable_path
    )
    @beta = Channel.new(
      name: "beta",
      feed_url: "https://feeds.example/beta.yml",
      artifact_url: ->(version) { "https://artifacts.example/Canvid%20Beta-v#{version}-mac.dmg" },
      version_pattern: /\A\d+\.\d+\.\d+-beta\.\d+\z/,
      cask_path: @beta_path
    )
  end

  def teardown
    FileUtils.remove_entry(@temporary_directory)
  end

  def test_unchanged_channels_skip_artifact_downloads
    client = DownloadClient.new(
      feeds: {
        @stable.feed_url => "version: 1.2.3\n",
        @beta.feed_url => "version: 1.3.0-beta.1\n"
      }
    )

    changed = UpdateCanvidCasks.run([@stable, @beta], client: client)

    refute changed
    assert_empty client.artifact_requests
  end

  def test_new_release_updates_only_version_and_sha256
    artifact = "new stable dmg"
    client = DownloadClient.new(
      feeds: {
        @stable.feed_url => "version: 2.0.0\n",
        @beta.feed_url => "version: 1.3.0-beta.1\n"
      },
      artifacts: { @stable.artifact_url.call("2.0.0") => artifact }
    )

    UpdateCanvidCasks.run([@stable, @beta], client: client)

    assert_equal cask("2.0.0", Digest::SHA256.hexdigest(artifact)), File.read(@stable_path)
    assert_equal cask("1.3.0-beta.1", "b" * 64), File.read(@beta_path)
  end

  def test_rejects_remote_content_after_top_level_version
    client = DownloadClient.new(
      feeds: {
        @stable.feed_url => "files:\n  version: 2.0.0\n",
        @beta.feed_url => "version: 1.3.0-beta.1\n"
      }
    )

    error = assert_raises(UpdateCanvidCasks::UpdateError) do
      UpdateCanvidCasks.run([@stable, @beta], client: client)
    end

    assert_match "top-level version", error.message
  end

  def test_rejects_versions_from_the_wrong_channel
    client = DownloadClient.new(
      feeds: {
        @stable.feed_url => "version: 2.0.0-beta.1\n",
        @beta.feed_url => "version: 1.3.0-beta.1\n"
      }
    )

    error = assert_raises(UpdateCanvidCasks::UpdateError) do
      UpdateCanvidCasks.run([@stable, @beta], client: client)
    end

    assert_match "invalid stable version", error.message
    assert_empty client.artifact_requests
  end

  def test_http_client_retries_server_errors_and_follows_redirects
    server, thread, url = serve_http(
      [
        "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n",
        "HTTP/1.1 302 Found\r\nLocation: /artifact\r\nContent-Length: 0\r\n\r\n",
        "HTTP/1.1 200 OK\r\nContent-Length: 7\r\n\r\npayload"
      ]
    )
    received = nil

    UpdateCanvidCasks::HttpClient.new.stream(url) do |chunks|
      received = +""
      chunks.each { |chunk| received << chunk }
    end

    assert_equal "payload", received
  ensure
    server.close if server
    thread.join if thread
  end

  def test_http_client_fails_without_retrying_client_errors
    server, thread, url = serve_http(
      ["HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"]
    )

    error = assert_raises(UpdateCanvidCasks::UpdateError) do
      UpdateCanvidCasks::HttpClient.new.stream(url) { |_chunk| flunk "unexpected body" }
    end

    assert_match "HTTP 404", error.message
  ensure
    server.close if server
    thread.join if thread
  end

  def test_http_client_restarts_the_stream_after_a_partial_response
    server, thread, url = serve_http(
      [
        "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\npartial",
        "HTTP/1.1 200 OK\r\nContent-Length: 8\r\n\r\ncomplete"
      ]
    )
    received = nil

    UpdateCanvidCasks::HttpClient.new.stream(url) do |chunks|
      received = +""
      chunks.each { |chunk| received << chunk }
    end

    assert_equal "complete", received
  ensure
    server.close if server
    thread.join if thread
  end

  def test_failure_does_not_modify_either_cask
    stable_before = File.read(@stable_path)
    beta_before = File.read(@beta_path)
    client = DownloadClient.new(
      feeds: {
        @stable.feed_url => "version: 2.0.0\n",
        @beta.feed_url => "version: 2.1.0-beta.2\n"
      },
      artifacts: { @stable.artifact_url.call("2.0.0") => "stable" },
      failure_url: @beta.artifact_url.call("2.1.0-beta.2")
    )

    assert_raises(UpdateCanvidCasks::UpdateError) do
      UpdateCanvidCasks.run([@stable, @beta], client: client)
    end

    assert_equal stable_before, File.read(@stable_path)
    assert_equal beta_before, File.read(@beta_path)
  end

  private

  def serve_http(responses)
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      responses.each do |response|
        socket = server.accept
        loop do
          line = socket.gets
          break if line.nil? || line == "\r\n"
        end
        socket.write(response)
        socket.close
      end
    end
    [server, thread, "http://127.0.0.1:#{server.addr[1]}/release"]
  end

  def cask(version, sha256)
    <<~RUBY
      cask "fixture" do
        version "#{version}"
        sha256 "#{sha256}"

        url "https://example.invalid/\#{version}.dmg"
      end
    RUBY
  end
end
