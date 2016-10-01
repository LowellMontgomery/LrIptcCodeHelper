local LrView = import 'LrView'
local subject_scene_notice = 'Save tons of time and hassle entering IPTC subject and scene codes via a controlled\nkeyword vocabulary like www.lowemo.photo/lightroom/keyword-vocabulary\n\nIMPORTANT: If you have not added IPTC keywords to a selected photo, running without the\n“protect” setting for any IPTC terms will clear the corresponding IPTC code field.'

local genre_notice = 'IPTC Genre codes, by default, *are* set to export with the normal keywords, as they are\nhuman-readable (English) terms which should describe the media. For now, rather than\nadding a new custom field for “Product Genre”, these terms are combined and added to\nthe IPTC “Intellectual” Genre field.'

local PluginLicense = 'Copyright © 2016 Lowell Montgomery / www.lowemo.photo\n\nUse of this plugin is at your\nown risk. No warranty is provided against loss of data or any other loss. (That said, if\nyou have any problems, please do let me know by creating an issue on Github)'

local IptcCodeHelperInfoProvider = {}

function IptcCodeHelperInfoProvider.sectionsForTopOfDialog(viewFactory, propertyTable)
    local prefs = import 'LrPrefs'.prefsForPlugin(_PLUGIN.id)
    local bind = LrView.bind

    return {
      {
         title = LOC '$$$/IptcCodeHelper/Settings/IptcSubjectSceneCodes=Settings for IPTC subject/scene codes',
         viewFactory:static_text {
            width_in_chars = 90,
            height_in_lines = 5,
            title = subject_scene_notice
         },
         viewFactory:row {
            spacing = viewFactory:control_spacing(),

         -- Scan for IPTC Subject Codes
            viewFactory:checkbox {
               title = LOC '$$$/IptcCodeHelper/Settings/useSubjCodes=Scan keywords for Subject codes',
               tooltip = 'Check this box to copy IPTC subject codes keywords (any 8-character numeric term will be copied to the IPTC subject codes field as a comma-separated list).',
               value = bind { key = 'useSubjCodes', object = prefs },
            },
         },
         

         viewFactory:row {
            spacing = viewFactory:control_spacing(),

         -- Protect IPTC Subject Code field from being cleared (if no subject code keywords are selected, but a previous value is in the field)
            viewFactory:checkbox {
               title = LOC '$$$/IptcCodeHelper/Settings/protectSubjCodes=Protect Subject codes from being cleared',
               tooltip = 'Check this box to avoid emptying existing IPTC subject codes if there are no subject keywords selected. \n\n(WARNING: POTENTIAL LOSS OF METADATA IF LEFT UNCHECKED AND YOU HAVE ENTERED SUBJECT CODES MANUALLY!)',
               value = bind { key = 'protectSubjCodes', object = prefs },
            },
         },
         viewFactory:separator { fill_horizontal = 1 },
         viewFactory:row {
            spacing = viewFactory:control_spacing(),

         -- Scan IPTC Scene Codes
            viewFactory:checkbox {
               title = LOC '$$$/IptcCodeHelper/Settings/useSceneCodes=Scan keywords for Scene codes',
               tooltip = 'Check this box to copy IPTC scene codes keywords (any 6-character numeric term will be copied to the IPTC scene codes field as a comma-separated list).',
               value = bind { key = 'useSceneCodes', object = prefs },
            },
         },


         viewFactory:row {
            spacing = viewFactory:control_spacing(),

         -- Protect IPTC Scene Code field from being cleared (if no scene code keywords are selected, but a previous value is in the field)
            viewFactory:checkbox {
               title = LOC '$$$/IptcCodeHelper/Settings/protectSceneCodes=Protect Scene codes from being cleared',
               tooltip = 'Check this box to avoid emptying existing IPTC scene codes if there are no scene keywords selected. \n\n(WARNING: POTENTIAL LOSS OF METADATA IF LEFT UNCHECKED AND YOU HAVE ENTERED SCENE CODES MANUALLY!)',
               value = bind { key = 'protectSceneCodes', object = prefs },
            },
         },

      },
      
      {
         title = LOC '$$$/IptcCodeHelper/Settings/IntelGenreKeywords=Settings for IPTC Genre codes',
         viewFactory:static_text {
            width_in_chars = 90,
            height_in_lines = 4,
            title = genre_notice
         },
         viewFactory:row {
            spacing = viewFactory:control_spacing(),

         -- Scan IPTC Intellectual Genre Codes
            viewFactory:checkbox {
               title = LOC '$$$/IptcCodeHelper/Settings/useIntelGenre=Scan keywords for Intellectual Genre terms',
               value = bind { key = 'useIntelGenre', object = prefs },
               tooltip = 'Check this box if you want to parse keywords for IPTC Intellectual Genre terms.'
            },
         },

         viewFactory:row {
            spacing = viewFactory:label_spacing(),

            viewFactory:static_text {
               title = LOC '$$$/IptcCodeHelper/Settings/IptcIntelGenreParent=Parent Keyword for Intellectual Genre:',
               tooltip = 'Parent keyword (without hierarchy) for IPTC Intellectual Genre keywords. MUST have a unique name (i.e. the same name cannot appear elsewhere in your keyword hierarchy).',
               alignment = 'right',
            },

         -- IPTC Intellectual Genre parent keyword
            viewFactory:edit_field {
               tooltip = 'Parent keyword (without hierarchy) for IPTC Intellectual Genre keywords. MUST have a unique name (i.e. the same name cannot appear elsewhere in your keyword hierarchy).',
               fill_horizonal = 1,
               width_in_chars = 35,
               value = bind { key = 'IptcIntelGenreParent', object = prefs },
            },
         },
         
         viewFactory:separator { fill_horizontal = 1 },
         
-- Product Genre. Terms in the IPTC Product Genre controlled vocabulary maybe make more sense for describing stock photographs
-- than do the "Intellectual Genre" keywords, which is the "Genre" field currently included in Lightroom. Current behavior will
-- be to collect these into that same field, but a custom field may be used in future.
         viewFactory:row {
            spacing = viewFactory:control_spacing(),

         -- Scan IPTC Product Genre Codes
            viewFactory:checkbox {
               title = LOC '$$$/IptcCodeHelper/Settings/useProductGenre=Scan keywords for Product Genre terms',
               value = bind { key = 'useProductGenre', object = prefs },
               tooltip = 'Check this box if you want to parse keywords for IPTC Product Genre terms and add those to the IPTC Genre field as a comma-separated list',
            },
         },

         viewFactory:row {
            spacing = viewFactory:label_spacing(),

         -- IPTC Product Genre parent keyword
            viewFactory:static_text {
               title = LOC '$$$/IptcCodeHelper/Settings/IptcProductGenreParent=Parent Keyword for Product Genre:',
               tooltip = 'Parent keyword (without hierarchy) for IPTC Product Genre keywords. MUST have a unique name (i.e. the same name cannot appear elsewhere in your keyword hierarchy).',
               alignment = 'right',
            },

            viewFactory:edit_field {
               fill_horizonal = 1,
               width_in_chars = 35,
               value = bind { key = 'IptcProductGenreParent', object = prefs },
            },
         },

         viewFactory:separator { fill_horizontal = 1 },

     -- Protect IPTC Scene Code field from being cleared (if no genre code keywords are selected, but a previous value is in the genre field)
         viewFactory:row {
            spacing = viewFactory:control_spacing(),
            viewFactory:checkbox {
               title = LOC '$$$/IptcCodeHelper/Settings/protectGenreCodes=Protect Genre codes from being cleared',
               tooltip = 'Check this box to avoid emptying existing IPTC genre codes if there are no genre keywords selected. \n\n(WARNING: POTENTIAL LOSS OF METADATA IF LEFT UNCHECKED AND YOU HAVE ENTERED GENRE CODES MANUALLY!)',
               value = bind { key = 'protectGenreCodes', object = prefs },
            },
         },
         
      },
   }
end

function IptcCodeHelperInfoProvider.sectionsForBottomOfDialog(viewFactory, propertyTable)   
   return {
      {
         title = LOC '$$$/IptcCodeHelper/Settings/License=Copyright and License',
         viewFactory:static_text {
            width_in_chars = 80,
            height_in_lines = 13,
            title = PluginLicense
         }
      }
   }
end

return IptcCodeHelperInfoProvider

