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
  
  # Plugin information
  PLUGIN_ID       = 'TT_TextEditor'.freeze
  PLUGIN_NAME     = '3D Text Editor'.freeze
  PLUGIN_VERSION  = '1.1.1'.freeze

  # Resource paths
  FILENAMESPACE = File.basename( __FILE__, '.rb' )
  PATH_ROOT     = File.dirname( __FILE__ ).freeze
  PATH          = File.join( PATH_ROOT, FILENAMESPACE ).freeze
  
  
  ### EXTENSION ### ------------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    file = File.join( PATH, 'core.rb' )
    ex = SketchupExtension.new( PLUGIN_NAME, file )
    ex.description = "Editable 3D text with live preview."
    ex.version     = PLUGIN_VERSION
    ex.copyright   = 'Thomas Thomassen © 2012–2013'
    ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension( ex, true )
  end 

  end # module Editor3dText
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------