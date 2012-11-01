#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  timer = UI.start_timer( 0, false ) {
    UI.stop_timer( timer )
    filename = File.basename( __FILE__ )
    message = "#{filename} require TT_Lib² to be installed.\n"
    message << "\n"
    message << "Would you like to open a webpage where you can download TT_Lib²?"
    result = UI.messagebox( message, MB_YESNO )
    if result == 6 # YES
      UI.openURL( 'http://www.thomthom.net/software/tt_lib2/' )
    end
  }
end


#-------------------------------------------------------------------------------

if defined?( TT::Lib ) && TT::Lib.compatible?( '2.7.0', '3D Text Editor' )

module TT::Plugins::Editor3dText

  ### CONSTANTS ### ------------------------------------------------------------
  
  # Plugin information
  PLUGIN_ID       = 'TT_Editor3dText'.freeze
  PLUGIN_NAME     = '3D Text Editor'.freeze
  PLUGIN_VERSION  = TT::Version.new(1,0,0).freeze
  
  # Version information
  RELEASE_DATE    = '29 Oct 12'.freeze
  
  # Resource paths
  PATH_ROOT   = File.dirname( __FILE__ ).freeze
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    # Menus
    m = UI.menu( 'Draw' )
    m.add_item( 'Editable 3d Text' ) { self.writer_tool }
    
    # Context menu
    UI.add_context_menu_handler { |context_menu|
      instance = Sketchup.active_model.selection.find { |entity|
        next unless TT::Instance.is?( entity )
        definition = TT::Instance.definition( entity )
        definition.attribute_dictionary( PLUGIN_ID, false )
      }
      context_menu.add_item( 'Edit Text' ) {
        Sketchup.active_model.select_tool( TextEditorTool.new( instance ) )
      } if instance
    }
  end 
  
  
  ### LIB FREDO UPDATER ### ----------------------------------------------------
  
  def self.register_plugin_for_LibFredo6
    {   
      :name => PLUGIN_NAME,
      :author => 'thomthom',
      :version => PLUGIN_VERSION.to_s,
      :date => RELEASE_DATE,   
      :description => 'Editable 3D text with live preview.',
      :link_info => 'http://forums.sketchucation.com/viewtopic.php?f=0&t=0'
    }
  end
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------

  # @since 1.0.0
  def self.writer_tool
    Sketchup.active_model.select_tool( TextEditorTool.new )
  end

  
  # @since 1.0.0
  class TextEditorTool

    # @since 1.0.0
    def initialize( instance = nil )
      @origin = nil
      @instance = nil
      @ip = Sketchup::InputPoint.new

      @text      = "Hello World\nFoo\nBasecamp"
      @font      = 'Arial'
      @style     = 'Normal'
      @size      = 1.m
      @filled    = true
      @extruded  = true
      @extrusion = 0.m
      @align     = 'Left'

      if instance
        @instance = instance
        @origin = instance.transformation.origin
        definition = TT::Instance.definition( @instance )
        read_properties( definition )
        instance.model.start_operation( 'Edit 3D Text' )
        open_ui()
      end
    end

    # @param [Sketchup::View] view
    # 
    # @since 1.0.0
    def resume( view )
      view.invalidate
    end

    # @param [Sketchup::View] view
    # 
    # @since 1.0.0
    def deactivate( view )
      view.invalidate
    end

    # @param [Integer] flags
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    # 
    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      @ip.pick( view, x, y )
      if @origin.nil?
        @origin = @ip.position
        view.model.start_operation( 'Create 3D Text' )
        @instance = view.model.active_entities.add_group
        tr = Geom::Transformation.new( @origin )
        @instance.transform!( tr )

        open_ui()
      end
      view.invalidate
    end

    # @param [Integer] flags
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    # 
    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      view.invalidate
    end

    # @param [Sketchup::View] view
    # 
    # @since 1.0.0
    def draw( view )
      if @origin
        view.draw_points( [@origin], 10, 4, 'red' )
      end
    end

    private

    # @return [TT::GUI::Window]
    # @since 1.0.0
    def open_ui
      props = {
        :dialog_title => '3D Text Editor',
        :width => 316,
        :height => 280,
        :resizable => false
      }
      w = TT::GUI::ToolWindow.new( props )
      w.theme = TT::GUI::Window::THEME_GRAPHITE

      # Text input
      eInputChange = TT::DeferredEvent.new { |value| input_changed( value ) }
      txtInput = TT::GUI::Textbox.new( @text )
      txtInput.name = :txt_input
      txtInput.multiline = true
      txtInput.top = 5
      txtInput.left = 5
      txtInput.width = 300
      txtInput.height = 140
      txtInput.add_event_handler( :textchange ) { |control|
        eInputChange.call( control.value )
      }
      w.add_control( txtInput )
      
      # Container for font properties
      container = TT::GUI::Container.new
      container.move( 5, 150 )
      container.width  = 300
      container.height = 75
      w.add_control( container )
      
      # Font List
      lstFont = TT::GUI::Listbox.new()
      lstFont.name = :lst_font
      #lstFont.value = @font
      lstFont.add_event_handler( :change ) { |control, value|
        # (!) Control.value isn't updated - this must change.
        @font = value
        input_changed( nil )
      }
      lstFont.move( 35, 0 )
      lstFont.width = 180
      container.add_control( lstFont )
      
      lblFont = TT::GUI::Label.new( 'Font:', lstFont )
      lblFont.top = 0
      lblFont.right = 270
      container.add_control( lblFont )
      
      # Font Style
      lstStyle = TT::GUI::Listbox.new( [
        'Normal',
        'Bold',
        'Italic',
        'Bold Italic'
      ] )
      lstStyle.name = :lst_style
      lstStyle.value = @style
      lstStyle.add_event_handler( :change ) { |control, value|
        @style = value
        input_changed( nil )
      }
      lstStyle.top = 0
      lstStyle.right = 0
      lstStyle.width = 80
      container.add_control( lstStyle )
      
      # Text Alignment
      lstAlign = TT::GUI::Listbox.new( [
        'Left',
        'Center',
        'Right'
      ] )
      lstAlign.name = :lst_align
      lstAlign.value = @align
      lstAlign.add_event_handler( :change ) { |control, value|
        #puts control.value
        #puts value
        @align = value
        input_changed( nil )
      }
      lstAlign.move( 35, 25 )
      lstAlign.width = 80
      container.add_control( lstAlign )
      
      lblFont = TT::GUI::Label.new( 'Align:', lstAlign )
      lblFont.top = 25
      lblFont.right = 270
      container.add_control( lblFont )

      # Text size
      eSizeChange = TT::DeferredEvent.new { |value| input_changed( nil ) }
      txtSize = TT::GUI::Textbox.new( @size.to_s )
      txtSize.name = :txt_size
      txtSize.top = 25
      txtSize.right = 0
      txtSize.width = 80
      txtSize.add_event_handler( :textchange ) { |control|
        eSizeChange.call( control.value )
      }
      container.add_control( txtSize )

      lblSize = TT::GUI::Label.new( 'Height:', txtSize )
      lblSize.top = 25
      lblSize.right = 85
      container.add_control( lblSize )

      # Extrude Height
      eExtrudeChange = TT::DeferredEvent.new { |value| input_changed( nil ) }
      txtExtrude = TT::GUI::Textbox.new( @extrusion.to_s )
      txtExtrude.name = :txt_extrusion
      txtExtrude.enabled = @filled # Disable when text is not filled.
      txtExtrude.top = 50
      txtExtrude.right = 0
      txtExtrude.width = 80
      txtExtrude.add_event_handler( :textchange ) { |control|
        eExtrudeChange.call( control.value )
      }
      container.add_control( txtExtrude )
      
      # Form
      lblForm = TT::GUI::Label.new( 'Form:' )
      lblForm.top = 50
      lblForm.right = 270
      container.add_control( lblForm )
      
      # Extrude
      chkExtrude = TT::GUI::Checkbox.new( 'Extrude:' )
      chkExtrude.name = :chk_extrude
      chkExtrude.enabled = @filled # Disable when text is not filled.
      chkExtrude.top = 50
      chkExtrude.right = 85
      chkExtrude.checked = @extruded
      chkExtrude.add_event_handler( :change ) { |control|
        input_changed( nil )
      }
      container.add_control( chkExtrude )
      
      # Filled
      chkFilled = TT::GUI::Checkbox.new( 'Filled' )
      chkFilled.name = :chk_filled
      chkFilled.top = 50
      chkFilled.left = 35
      chkFilled.checked = @filled
      chkFilled.add_event_handler( :change ) { |control|
        input_changed( nil )
        txtExtrude.enabled = control.checked
        chkExtrude.enabled = control.checked
      }
      container.add_control( chkFilled )

      # Close Button
      btnClose = TT::GUI::Button.new( 'Close' ) { |control|
        control.window.close
      }
      btnClose.size( 75, 25 )
      btnClose.right = 5
      btnClose.bottom = 5
      w.add_control( btnClose )
      
      # Hook up events.
      w.on_ready { |window|
        # Populate Font list.
        font_names = list_system_fonts( window )
        font_list = w[:lst_font]
        font_list.add_item( font_names )
        # Set font
        if font_list.items.include?( @font )
          font = @font
        else
          font = default_font( font_names )
        end
        font_list.value = font
        input_changed( @text )
      }
      w.set_on_close {
        on_window_close()
      }

      w.show_window

      @window = w
    end

    # @since 1.0.0
    def on_window_close
      model = Sketchup.active_model
      model.commit_operation
      model.select_tool( nil )
    end

    # @since 1.0.0
    def input_changed( value )
      #puts 'input_changed'

      @text = value if value

      definition = TT::Instance.definition( @instance )
      definition.entities.clear!
      
      w = @window
      @font      = w[:lst_font].value
      @style     = w[:lst_style].value
      bold       = @style.include?( 'Bold' )
      italic     = @style.include?( 'Italic' )
      @size      = w[:txt_size].value.to_l
      @filled    = w[:chk_filled].checked
      @extruded  = w[:chk_extrude].checked
      @extrusion = w[:txt_extrusion].value.to_l
      extrusion  = ( @extruded ) ? @extrusion : 0.0
      tolerance = 0
      z = 0

      align = case @align
        when 'Left':    TextAlignLeft
        when 'Center':  TextAlignCenter
        when 'Right':   TextAlignRight
      end # (?) Map to Hash?

      definition.entities.add_3d_text(
        @text,
        align, @font, bold, italic, @size,
        tolerance, z, @filled, extrusion
      )
      write_properties( definition )
    end
    
    # @since 1.0.0
    def write_properties( entity )
      entity.set_attribute( PLUGIN_ID, 'Text',      @text )
      entity.set_attribute( PLUGIN_ID, 'Font',      @font )
      entity.set_attribute( PLUGIN_ID, 'Style',     @style )
      entity.set_attribute( PLUGIN_ID, 'Size',      @size )
      entity.set_attribute( PLUGIN_ID, 'Filled',    @filled )
      entity.set_attribute( PLUGIN_ID, 'Extruded',  @extruded )
      entity.set_attribute( PLUGIN_ID, 'Extrusion', @extrusion )
      entity.set_attribute( PLUGIN_ID, 'Align',     @align )
    end

    # @since 1.0.0
    def read_properties( entity )
      @text      = entity.get_attribute( PLUGIN_ID, 'Text',      'Hello World' )
      @font      = entity.get_attribute( PLUGIN_ID, 'Font',      'Arial' )
      @style     = entity.get_attribute( PLUGIN_ID, 'Style',     'Normal' )
      @size      = entity.get_attribute( PLUGIN_ID, 'Size', 	   1.m ).to_l
      @filled    = entity.get_attribute( PLUGIN_ID, 'Filled',    true )
      @extruded  = entity.get_attribute( PLUGIN_ID, 'Extruded',  true )
      @extrusion = entity.get_attribute( PLUGIN_ID, 'Extrusion', 0.m ).to_l
      @align     = entity.get_attribute( PLUGIN_ID, 'Align',     'Left' )
    end
    
    # @since 1.0.0
    def default_font( availible_fonts )
      fallbacks = [
        'Arial',
        'Helvetica',
        'Tahoma',
        'Trebuchet MS',
        'Verdana'
      ]
      matches = availible_fonts & fallbacks
      # (!) Validate
      matches.first
    end
    
    # @since 1.0.0
    def list_system_fonts( window )
      # Try to get list of system fonts.
      font_names = window.call_script('System.font_names')
      return font_names unless font_names.empty?
      # Fall back to providing some select default fonts.
      # SketchUp will default to some existing font if you provide a font not
      # in the system.
      if TT::System::PLATFORM_IS_WINDOWS
        # http://www.ampsoft.net/webdesign-l/windows-fonts-by-version.html
        [
          'Aharoni Bold',
          'Andalus',
          'Angsana New/AngsanaUPC',
          'Arabic Typesetting',
          'Arial',
          'Arial Black',
          'Batang/BatangChe',
          'Browallia New/BrowalliaUPC',
          'Calibri',
          'Cambria',
          'Candara',
          'Consolas',
          'Constantias',
          'Corbel',
          'Cordia New/CordiaUPC',
          'Courier New',
          'DaunPenh',
          'David',
          'DFKai-SB',
          'DilleniaUPC',
          'DokChampa',
          'Dotum/DotumChe',
          'Estrangelo Edessa',
          'EucrosiUPC',
          'Euphemia',
          'Fangsong',
          'Franklin Gothic Medium',
          'FrankRuehl',
          'FreesiaUPC',
          'Gautami',
          'Georgia',
          'Gisha',
          'Gulim/GulimChe',
          'Gungsuh/GungsuhChe',
          'Impact',
          'IrisUPC',
          'Iskoola Pota',
          'JasmineUPC',
          'KaiTi',
          'Kalinga',
          'Kartika',
          'KodchiangUPC',
          'Latha',
          'Leelawadee',
          'Levenim',
          'LilyUPC',
          'Lucida Console',
          'Lucida Sans Console',
          'Malgun Gothic',
          'Mangal',
          'Marlett',
          'Meiryo',
          'Microsoft Himalaya',
          'Microsoft JhengHei',
          'Microsoft Sans Serif',
          'Microsoft Uighur',
          'Microsoft YaHei',
          'Microsoft Yi Baiti',
          'MingLiU-ExtB/PMingLiU-ExtB',
          'MingLiU_HKSCS/MingLiU_HKSCS-ExtB',
          'Miriam',
          'Mongolian Baiti',
          'MS Gothic/MS PGothic/MS UI Gothic',
          'MS Mincho/MS PMincho',
          'MV Boli',
          'Narkisim',
          'Nyala',
          'Palatino Linotype',
          'Plantagenet Cherokee',
          'Raavi',
          'Rod',
          'Segoe Print',
          'Segoe Script',
          'Segoe UI',
          'Shruti',
          'SimHei',
          'Simplified Arabic',
          'SimSun-ExtB',
          'Simsun/NSimsun',
          'Sylfaen',
          'Symbol',
          'Tahoma',
          'Times New Roman',
          'Traditional Arabic',
          'Trebuchet MS',
          'Tunga',
          'Verdana',
          'Vrinda',
          'Webdings',
          'Wingdings'
        ]
      elsif TT::System::PLATFORM_IS_OSX
        [
          'Al Bayan',
          'American Typewriter',
          'Andale Mono',
          'Apple Casual',
          'Apple Chancery',
          'Apple Garamond',
          'Apple Gothic',
          'Apple LiGothic',
          'Apple LiSung',
          'Apple Myungjo',
          'Apple Symbols',
          '.AquaKana',
          'Arial',
          'Arial Hebrew',
          'Ayuthaya',
          'Baghdad',
          'Baskerville',
          'Beijing',
          'BiauKai',
          'Big Caslon',
          'Brush Script',
          'Chalkboard',
          'Charcoal',
          'Charcoal CY',
          'Chicago',
          'Cochin',
          'Comic Sans',
          'Cooper',
          'Copperplate',
          'Corsiva Hebrew',
          'Courier',
          'Courier New',
          'DecoType Naskh',
          'Devanagari',
          'Didot',
          'Eupheima UCAS',
          'Fang Song',
          'Futura',
          'Gadget',
          'Geeza Pro',
          'Geezah',
          'Geneva',
          'Geneva CY',
          'Georgia',
          'Gill Sans',
          'Gujarati',
          'Gung Seoche',
          'Gurmukhi',
          'Hangangche',
          'HeadlineA',
          'Hei',
          'Helvetica',
          'Helvetica CY',
          'Helvetica Neue',
          'Herculanum',
          'Hiragino Kaku Gothic Pro',
          'Hiragino Kaku Gothic ProN',
          'Hiragino Kaku Gothic Std',
          'Hiragino Kaku Gothic StdN',
          'Hiragino Maru Gothic Pro',
          'Hiragino Maru Gothic ProN',
          'Hiragino Mincho Pro',
          'Hiragino Mincho ProN',
          'Hoefler Text',
          'Inai Mathi',
          'Impact',
          'Jung Gothic',
          'Kai',
          'Keyboard',
          'Krungthep',
          'KufiStandard GK',
          'LastResort',
          'LiHei Pro',
          'LiSong Pro',
          'Lucida Grande',
          'Marker Felt',
          'Menlo',
          'Monaco',
          'Monaco CY',
          'Mshtakan',
          'Nadeem',
          'New Peninim',
          'New York',
          'NISC GB18030',
          'Optima',
          'Osaka',
          'Palatino',
          'Papyrus',
          'PC Myungjo',
          'Pilgiche',
          'Plantagenet Cherokee',
          'Raanana',
          'Sand',
          'Sathu',
          'Segoe UI',
          'Seoul',
          'Shin Myungjo Neue',
          'Silom',
          'Skia',
          'Song',
          'ST FangSong',
          'ST Heiti',
          'ST Kaiti',
          'ST Song',
          'Symbol',
          'Tae Graphic',
          'Tahoma',
          'Taipei',
          'Techno',
          'Textile',
          'Thonburi',
          'Times',
          'Times CY',
          'Times New Roman',
          'Trebuchet MS',
          'Verdana',
          'Zapf Chancery',
          'Zapf Dingbats',
          'Zapfino'
        ]
      else
        raise 'Unsupported platform.'
      end
    end

  end # class
  
  
  ### DEBUG ### ----------------------------------------------------------------
  
  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::Editor3dText.reload
  #
  # @param [Boolean] tt_lib
  #
  # @return [Integer]
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    #x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
    #  load file
    #}
    #x.length
  ensure
    $VERBOSE = original_verbose
  end

end # module

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------