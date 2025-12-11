ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Centralized requires for stdlib/gem conveniences used across the app.
require "json"
require "yaml"
require "logger"
require "fileutils"
require "time"
require "tmpdir"
require "open3"
require "securerandom"
require "net/http"
require "uri"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
