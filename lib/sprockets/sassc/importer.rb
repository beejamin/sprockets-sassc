require 'tilt'
require 'pathname'

module Sprockets
	module Sassc
		class Importer < ::SassC::Importer
			class Extension
				attr_reader :postfix

				def initialize(postfix=nil)
					@postfix = postfix
				end

				def import_for(full_path, parent_dir, options)
					eval_content = evaluate(options[:sprockets][:context], full_path)
					
					# sassc doesn't support sass syntax, convert sass to scss
					# before returning result.
					if Pathname.new(full_path).basename.to_s.include?('.sass')
						eval_content = SassC::Sass2Scss.convert(eval_content)
					end
					
					SassC::Importer::Import.new(full_path, source: eval_content)
				end
				
				# Returns the string to be passed to the Sass engine. We use
				# Sprockets to process the file, but we remove any Sass processors
				# because we need to let the Sass::Engine handle that.
				def evaluate(context, path)
					attributes = context.environment.attributes_for(path)
					processors = context.environment.preprocessors(attributes.content_type) + attributes.engines.reverse
					processors.delete_if { |processor| processor < Tilt::SassTemplate }
					
					context.evaluate(path, :processors => processors)
				end
			end
			
			class CSSExtension < Extension
				def postfix
					".css"
				end
				
				# def import_for(full_path, parent_dir, options)
				# 	import_path = full_path.gsub(/\.css$/,"")
				# 	SassC::Importer::Import.new(import_path)
				# end
			end
			
			class CssScssExtension < Extension
				def postfix
					".css.scss"
				end
			end
			
			class CssSassExtension < Extension
				def postfix
					".css.sass"
				end
				
				def import_for(full_path, parent_dir, options)
					sass = evaluate(options[:sprockets][:context], full_path)
					parsed_scss = SassC::Sass2Scss.convert(sass)
					SassC::Importer::Import.new(full_path, source: parsed_scss)
				end
			end
			
			class SassERBExtension < Extension
				def postfix
					".sass.erb"
				end
			end
			
			class ERBExtension < Extension
				
			end
			
			
			EXTENSIONS = [
				CssScssExtension.new,
				CssSassExtension.new,
				Extension.new(".scss"),
				Extension.new(".sass"),
				CSSExtension.new,
				ERBExtension.new(".scss.erb"),
				ERBExtension.new(".css.erb"),
				SassERBExtension.new
			]

			PREFIXS = [ "", "_" ]
			GLOB = /(\A|\/)(\*|\*\*\/\*)\z/
			
			# We only have one type of extension now, so only initialise it once.
			EXTENSION = Extension.new()
			

			def imports(path, parent_path)
				
				puts "\nimporter: \npath='#{path}'\nparent_path='#{parent_path}'\n"
				
				# Resolve a glob
				if m = path.match(GLOB)
					
					abs_parent = Pathname.new(parent_path)
					if (abs_parent.relative?)
						# Resolve relative `parent_path` to absolute with sprockets.
						abs_parent = collect_and_resolve(options[:sprockets][:context], parent_path, nil)
					end
					
					path = path.sub(m[0], "")
					base = File.join(abs_parent.dirname, path)
					# base = File.expand_path(path, File.dirname(parent_path))
					return glob_imports(base, m[2], abs_parent)
				end
				
				# Resolve a single file
				return import_file_original(path, parent_path)
			end
			
			
			# Resolve single file (split out from original `#imports` method)
			def import_file_original(path, parent_path)
				parent_dir, _ = File.split(parent_path)
				
				ctx = options[:sprockets][:context]
				paths = collect_paths(ctx, path, parent_path)
				
				found_path = resolve_to_path(ctx, paths)
				
				puts "found_path=#{found_path}"
				
				record_import_as_dependency found_path
				
				## TODO: Change this so we're not creating a new importer 
				## every time?
				return EXTENSION.import_for(found_path.to_s, parent_dir, options)

				# SassC::Importer::Import.new(path)
			end
			
			
			# Helper method - resolve a relative file in sprockets.
			def collect_and_resolve(context, path, parent_path = nil)
				paths = collect_paths(context, path, parent_path)
				found_path = resolve_to_path(context, paths)
				return found_path
			end
			
			
			def collect_paths(context, path, parent_path)
				specified_dir, specified_file = File.split(path)
				specified_dir = Pathname.new(specified_dir)
				
				search_paths = [specified_dir.to_s]
				
				
				if !parent_path.nil?
					# In sassc `parent_path` may be relative but we need it to be absolute.
					# (In regular sass `parent_path` is always passed as absolute value)
					parent_path = to_absolute(parent_path)
					parent_dir = parent_path.dirname
					
					# Find parent_dir's root
					env_root_paths = env_paths.map {|p| Pathname.new(p) }
					root_path = env_root_paths.detect do |env_root_path|
						# Return the root path that contains `parent_dir`
						parent_dir.to_s.start_with?(env_root_path.to_s)
					end
					root_path ||= Pathname.new(context.root_path)
					
					
					if specified_dir.relative? && parent_dir != root_path
						# Get any remaining path relative to root
						relative_path = Pathname.new(parent_dir).relative_path_from(root_path)
						search_paths.unshift(relative_path.join(specified_dir).to_s)
					end
				end
				
				
				paths = search_paths.map { |search_path|
					PREFIXS.map { |prefix|
						file_name = prefix + specified_file
						
						# Joining on '.' can reslove to the wrong file.
						if search_path == '.'
							file_name
						else
							# Only join if search_path is not '.'
							File.join(search_path, file_name)
						end
					}
				}.flatten
				
				puts "paths=#{paths}"
				
				paths
			end
			
			
			# Finds an asset from the given path. This is where
			# we make Sprockets behave like Sass, and import partial
			# style paths.
			def resolve_to_path(context, paths)
				paths.each { |file|
					context.resolve(file) { |try_path|
						# Early exit if we find a requirable file.
						return try_path if context.asset_requirable?(try_path)
					}
				}
				
				nil
			end
			

			# def imports(path, parent_path)
			# 	parent_dir, _ = File.split(parent_path)
			# 	specified_dir, specified_file = File.split(path)
			#
			# 	if m = path.match(GLOB)
			# 		path = path.sub(m[0], "")
			# 		base = File.expand_path(path, File.dirname(parent_path))
			# 		return glob_imports(base, m[2], parent_path)
			# 	end
			#
			# 	search_paths = ([parent_dir] + load_paths).uniq
			#
			# 	if specified_dir != "."
			# 		search_paths.map! do |path|
			# 			File.join(path, specified_dir)
			# 		end
			# 	end
			#
			# 	search_paths.each do |search_path|
			# 		PREFIXS.each do |prefix|
			# 			file_name = prefix + specified_file
			#
			# 			EXTENSIONS.each do |extension|
			# 				try_path = File.join(search_path, file_name + extension.postfix)
			# 				if File.exists?(try_path)
			# 					record_import_as_dependency try_path
			# 					return extension.import_for(try_path, parent_dir, options)
			# 				end
			# 			end
			# 		end
			# 	end
			#
			# 	SassC::Importer::Import.new(path)
			# end

			private

			def extension_for_file(file)
				EXTENSIONS.detect do |extension|
					file.include? extension.postfix
				end
			end

			def record_import_as_dependency(path)
				context.depend_on path
			end

			def context
				options[:sprockets][:context]
			end

			def load_paths
				options[:load_paths]
			end
			
			# Machined/Sprockets paths...
			def env_paths
				context.environment.paths
			end

			
			
			# Make `base` relative to `current_file`
			# 
			# raw glob is equivalent to `base + glob`
			# 
			# `base` absolute path to the left-hand side of the glob (absolute path is from `current_file`)
			# `glob` right-hand side of glob (e.g. *)
			# `current_file` is the absolute path to the currently running file
			def glob_imports(base, glob, current_file)
				# TODO: Make sure `current_file` is absolute
				files = globbed_files(base, glob)
				files = files.reject { |f| f == current_file }
				
				files.map do |filename|
					record_import_as_dependency(filename)
					EXTENSION.import_for(filename.to_s, base, options)
				end
			end
			
			# Resolve glob to a list of files
			def globbed_files(base, glob)
				# TODO: Raise an error from SassC here
				raise ArgumentError unless glob == "*" || glob == "**/*"
				
				# Make sure `base` is absolute.
				base_path = to_absolute(base)
				path_with_glob = base_path.join(glob).to_s
				
				# Glob and resolve to files.
				files = Pathname.glob(path_with_glob).sort.select do |path|
					path != context.pathname && context.asset_requirable?(path)
				end
				
				# extensions = EXTENSIONS.map(&:postfix)
				# exts = extensions.map { |ext| Regexp.escape("#{ext}") }.join("|")
				# sass_re = Regexp.compile("(#{exts})$")
				# 
				# record_import_as_dependency(base)
				# 
				# files = Dir["#{base}/#{glob}"].sort.map do |path|
				# 	if File.directory?(path)
				# 		record_import_as_dependency(path)
				# 		nil
				# 	elsif sass_re =~ path
				# 		path
				# 	end
				# end
				
				files.compact
			end
			
			
			# Returns an absolute Pathname instance
			def to_absolute(path)
				abs_path = Pathname.new(path)
				if abs_path.relative?
					# prepend the Sprockets root_path.
					abs_path = Pathname.new(context.root_path).join(path)
				end
			
				return abs_path
			end
			
			# # Resolve glob to a list of files
			# def globbed_files(base, glob)
			# 	# TODO: Raise an error from SassC here
			# 	raise ArgumentError unless glob == "*" || glob == "**/*"
			# 
			# 	extensions = EXTENSIONS.map(&:postfix)
			# 	exts = extensions.map { |ext| Regexp.escape("#{ext}") }.join("|")
			# 	sass_re = Regexp.compile("(#{exts})$")
			# 
			# 	record_import_as_dependency(base)
			# 
			# 	files = Dir["#{base}/#{glob}"].sort.map do |path|
			# 		if File.directory?(path)
			# 			record_import_as_dependency(path)
			# 			nil
			# 		elsif sass_re =~ path
			# 			path
			# 		end
			# 	end
			# 
			# 	files.compact
			# end

		end
	end
end
