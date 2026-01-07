# frozen_string_literal: true

module Api
  # API controller for server-side filesystem browsing.
  # Allows frontend to browse directories the server has access to.
  # Used for directory picker functionality where browser security prevents direct access.
  class FilesystemController < ApplicationController
    # GET /api/filesystem/browse
    # Browse directories from a given starting path
    #
    # Parameters:
    #   path: (optional) Starting path, defaults to parent of Rails.root
    #
    # Response:
    #   {
    #     current_path: "/home/user/projects",
    #     parent_path: "/home/user",
    #     directories: [
    #       { name: "project1", path: "/home/user/projects/project1" },
    #       { name: "project2", path: "/home/user/projects/project2" }
    #     ]
    #   }
    def browse
      requested_path = params[:path]
      
      # Default to parent of Rails.root (common case: browse siblings)
      start_path = if requested_path.present?
        File.expand_path(requested_path)
      else
        File.expand_path('..', Rails.root)
      end

      # Security: Ensure path exists and is readable
      unless File.exist?(start_path) && File.readable?(start_path)
        return render json: {
          error: "Path does not exist or is not readable",
          current_path: start_path
        }, status: :bad_request
      end

      # Security: Ensure it's a directory
      unless File.directory?(start_path)
        return render json: {
          error: "Path is not a directory",
          current_path: start_path
        }, status: :bad_request
      end

      # Get parent path (nil if at root)
      parent_path = if start_path == '/'
        nil
      else
        File.expand_path('..', start_path)
      end

      # List directories only (not files)
      directories = Dir.children(start_path)
        .map { |name| File.join(start_path, name) }
        .select { |path| File.directory?(path) && File.readable?(path) }
        .map { |path| { name: File.basename(path), path: path } }
        .sort_by { |dir| dir[:name].downcase }

      render json: {
        current_path: start_path,
        parent_path: parent_path,
        directories: directories
      }
    rescue StandardError => e
      Rails.logger.error("Filesystem browse error: #{e.message}\n#{e.backtrace.join("\n")}")
      render json: {
        error: "Failed to browse directory: #{e.message}"
      }, status: :internal_server_error
    end

    # GET /api/filesystem/home
    # Get suggested starting directories
    #
    # Response:
    #   {
    #     suggestions: [
    #       { name: "Rails Root", path: "/path/to/rails/root" },
    #       { name: "Parent Directory", path: "/path/to/parent" },
    #       { name: "Home Directory", path: "/home/user" }
    #     ]
    #   }
    def home
      suggestions = []

      # Rails root
      suggestions << {
        name: "Rails Root",
        path: Rails.root.to_s,
        icon: "🚂"
      }

      # Parent of Rails root (common for sibling projects)
      parent_path = File.expand_path('..', Rails.root)
      if File.exist?(parent_path) && File.readable?(parent_path)
        suggestions << {
          name: "Parent Directory",
          path: parent_path,
          icon: "📁"
        }
      end

      # User's home directory
      home_path = File.expand_path('~')
      if File.exist?(home_path) && File.readable?(home_path) && home_path != parent_path
        suggestions << {
          name: "Home Directory",
          path: home_path,
          icon: "🏠"
        }
      end

      render json: { suggestions: suggestions }
    rescue StandardError => e
      Rails.logger.error("Filesystem home error: #{e.message}")
      render json: {
        error: "Failed to get home suggestions: #{e.message}"
      }, status: :internal_server_error
    end
  end
end

