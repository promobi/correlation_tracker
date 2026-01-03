# lib/generators/correlation_tracker/install_generator.rb
require 'rails/generators/base'

module CorrelationTracker
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Creates a CorrelationTracker initializer'

      def copy_initializer
        template 'correlation_tracker.rb', 'config/initializers/correlation_tracker.rb'
      end

      def show_readme
        readme 'README' if behavior == :invoke
      end

      private

      def readme(path)
        say
        say File.read(File.expand_path("../templates/#{path}", __FILE__))
      end
    end
  end
end