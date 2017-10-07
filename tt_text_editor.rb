#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

#-------------------------------------------------------------------------------

module TT
 module Plugins
  module Editor3dText
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  file = __FILE__.dup
  file.force_encoding('UTF-8') if file.respond_to?(:force_encoding)

  # Plugin information
  PLUGIN_ID       = 'TT_TextEditor'.freeze
  PLUGIN_NAME     = '3D Text Editor'.freeze
  PLUGIN_VERSION  = '1.2.0'.freeze

  # Resource paths
  FILENAMESPACE = File.basename(file, '.*')
  PATH_ROOT     = File.dirname(file).freeze
  PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze
  
  
  ### EXTENSION ### ------------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    loader = File.join(PATH, 'core')
    ex = SketchupExtension.new(PLUGIN_NAME, loader)
    ex.description = "Editable 3D text with live preview."
    ex.version     = PLUGIN_VERSION
    ex.copyright   = 'Thomas Thomassen © 2012–2017'
    ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension(ex, true)
  end 

  end # module Editor3dText
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------
