module Callstacking
  module Rails
    class Logger
      def self.log(message)
        puts message
        
        if ENV['GITHUB_OUTPUT'].present?
          File.open(ENV['GITHUB_OUTPUT'], 'a') do |file|
            # Write your progress output to the file
            # This could be inside a loop or condition, depending on your needs
            file.puts "::set-output name=progress_output::#{message}"
          end
        end
      end
    end
  end
end

