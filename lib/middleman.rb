require "rbconfig"

# Setup our load paths
libdir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

# Top-level Middleman object
module Middleman
  WINDOWS = !!(RUBY_PLATFORM =~ /(mingw|bccwin|wince|mswin32)/i)
  JRUBY   = !!(RbConfig::CONFIG["RUBY_INSTALL_NAME"] =~ /^jruby/i)
  
  # Auto-load modules on-demand
  autoload :Base,           "middleman/base"
  autoload :Cache,          "middleman/cache"
  autoload :Templates,      "middleman/templates"
  autoload :Guard,          "middleman/guard"
  
  module Cli
    autoload :Base,         "middleman/cli"
    autoload :Build,        "middleman/cli/build"
    autoload :Init,         "middleman/cli/init"
    autoload :Server,       "middleman/cli/server"
  end
  
  # Custom Renderers
  module Renderers
    autoload :Haml,         "middleman/renderers/haml"
    autoload :Sass,         "middleman/renderers/sass"
    autoload :Markdown,     "middleman/renderers/markdown"
    autoload :ERb,          "middleman/renderers/erb"
    autoload :Liquid,       "middleman/renderers/liquid"
  end
  
  module Sitemap
    autoload :Store,        "middleman/sitemap/store"
    autoload :Page,         "middleman/sitemap/page"
    autoload :Template,     "middleman/sitemap/template"
  end
  
  module CoreExtensions
    # File Change Notifier
    autoload :FileWatcher,   "middleman/core_extensions/file_watcher"
    
    # In-memory Sitemap
    autoload :Sitemap,       "middleman/core_extensions/sitemap"
    
    # Add Builder callbacks
    autoload :Builder,       "middleman/core_extensions/builder"
    
    # Custom Feature API
    autoload :Extensions,    "middleman/core_extensions/extensions"
  
    # Asset Path Pipeline
    autoload :Assets,        "middleman/core_extensions/assets"
  
    # DefaultHelpers are the built-in dynamic template helpers.
    autoload :DefaultHelpers, "middleman/core_extensions/default_helpers"
  
    # Data looks at the data/ folder for YAML files and makes them available
    # to dynamic requests.
    autoload :Data,           "middleman/core_extensions/data"
    
    # Parse YAML from templates
    autoload :FrontMatter,    "middleman/core_extensions/front_matter"
    
    # Extended version of Padrino's rendering
    autoload :Rendering,      "middleman/core_extensions/rendering"
    
    # Compass framework for Sass
    autoload :Compass,        "middleman/core_extensions/compass"
    
    # Sprockets 2
    autoload :Sprockets,      "middleman/core_extensions/sprockets"
  
    # Pass custom options to views
    autoload :Routing,        "middleman/core_extensions/routing"
    
    # Catch and show exceptions at the Rack level
    autoload :ShowExceptions, "middleman/core_extensions/show_exceptions"
  end

  module Extensions
    # RelativeAssets allow any asset path in dynamic templates to be either
    # relative to the root of the project or use an absolute URL.
    autoload :RelativeAssets,      "middleman/extensions/relative_assets"

    # AssetHost allows you to setup multiple domains to host your static
    # assets. Calls to asset paths in dynamic templates will then rotate
    # through each of the asset servers to better spread the load.
    autoload :AssetHost,           "middleman/extensions/asset_host"

    # AssetHash appends a hash of the file contents to the assets filename
    # to avoid browser caches failing to update to your new content.
    autoload :AssetHash,           "middleman/extensions/asset_hash"

    # CacheBuster adds a query string to assets in dynamic templates to avoid
    # browser caches failing to update to your new content.
    autoload :CacheBuster,         "middleman/extensions/cache_buster"

    # AutomaticImageSizes inspects the images used in your dynamic templates
    # and automatically adds width and height attributes to their HTML
    # elements.
    autoload :AutomaticImageSizes, "middleman/extensions/automatic_image_sizes"

    # MinifyCss uses the YUI compressor to shrink CSS files
    autoload :MinifyCss,           "middleman/extensions/minify_css"

    # MinifyJavascript uses the YUI compressor to shrink JS files
    autoload :MinifyJavascript,    "middleman/extensions/minify_javascript"

    # Lorem provides a handful of helpful prototyping methods to generate
    # words, paragraphs, fake images, names and email addresses.
    autoload :Lorem,               "middleman/extensions/lorem"
    
    # Automatically convert filename.html files into filename/index.html
    autoload :DirectoryIndexes,    "middleman/extensions/directory_indexes"
    
    class << self
      def registered
        @_registered ||= {}
      end

      def register(name, namespace=nil, version=nil, &block)
        # If we've already got a matching extension that passed the 
        # version check, bail out.
        return if registered.has_key?(name.to_sym) && 
        !registered[name.to_sym].is_a?(String)

        if block_given?
          version = namespace
        end

        passed_version_check = true
        if !version.nil?
          requirement = ::Gem::Requirement.create(version)
          if !requirement.satisfied_by?(Middleman::GEM_VERSION)
            passed_version_check = false
          end
        end

        registered[name.to_sym] = if !passed_version_check
          "== #{name} failed version check. Requested #{version}, got #{Middleman::VERSION}"
        elsif block_given?
          block
        elsif namespace
          namespace
        end
      end

      def load(name)
        name = name.to_sym
        return nil unless registered.has_key?(name)

        extension = registered[name]
        if extension.is_a?(Proc)
          extension = extension.call() || nil
          registered[name] = extension
        end

        extension
      end
    end
  end
  
  # Where to look in gems for extensions to auto-register
  EXTENSION_FILE = File.join("lib", "middleman_extension.rb")
  
  class << self
    
    # Automatically load extensions from available RubyGems
    # which contain the EXTENSION_FILE
    #
    # @private
    def load_extensions_in_path
      extensions = rubygems_latest_specs.select do |spec|
        spec_has_file?(spec, EXTENSION_FILE)
      end
    
      extensions.each do |spec|
        require spec.name
      end
    end
  
    # Backwards compatible means of finding all the latest gemspecs
    # available on the system
    #
    # @private
    # @return [Array] Array of latest Gem::Specification
    def rubygems_latest_specs
      # If newer Rubygems
      if ::Gem::Specification.respond_to? :latest_specs
        ::Gem::Specification.latest_specs
      else
        ::Gem.source_index.latest_specs
      end
    end
  
    # Where a given Gem::Specification has a specific file. Used
    # to discover extensions and Sprockets-supporting gems.
    #
    # @private
    # @param [Gem::Specification]
    # @param [String] Path to look for
    # @return [Boolean] Whether the file exists
    def spec_has_file?(spec, path)
      full_path = File.join(spec.full_gem_path, path)
      File.exists?(full_path)
    end
  
    # Create a new Class which is based on Middleman::Base
    # Used to create a safe sandbox into which extensions and 
    # configuration can be included later without impacting
    # other classes and instances.
    #
    # @return [Class]
    def server(&block)
      Class.new(Middleman::Base)
    end
  
    # Creates a new Rack::Server
    #
    # @param [Hash] options to pass to Rack::Server.new
    # @return [Rack::Server]
    def start_server(options={})
      opts = {
        :Port      => options[:port] || 4567,
        :Host      => options[:host] || "0.0.0.0",
        :AccessLog => []
      }
    
      app_class = options[:app] ||= ::Middleman.server.inst
      opts[:app] = app_class
    
      require "thin"
      ::Thin::Logging.silent = !options[:logging]
      opts[:server] = 'thin'
      
      server = ::Rack::Server.new(opts)
      server.start
      server
    end
  end
end

# Make the VERSION string available
require "middleman/version"

# Automatically discover extensions in RubyGems
Middleman.load_extensions_in_path