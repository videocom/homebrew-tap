#!/usr/bin/env ruby

allowed_files = ["Casks/canvid.rb", "Casks/canvid@beta.rb"]
diff = IO.popen(["git", "diff", "--unified=0", "--", *allowed_files], &:read)
changed_files = IO.popen(["git", "diff", "--name-only"], &:read).lines.map(&:chomp)

unexpected_files = changed_files - allowed_files
unless unexpected_files.empty?
  warn "Updater changed unexpected files: #{unexpected_files.join(", ")}"
  exit 1
end

invalid_lines = diff.lines.select do |line|
  next false unless line.start_with?("+", "-")
  next false if line.start_with?("+++", "---")

  !line.match?(/\A[+-]\s*(version|sha256) "/)
end

unless invalid_lines.empty?
  warn "Updater changed fields other than version and sha256:"
  warn invalid_lines.join
  exit 1
end
