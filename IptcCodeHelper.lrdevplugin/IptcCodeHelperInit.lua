-- Provide initial default values for plugin preferences.

local LrPrefs = import 'LrPrefs'

local defaultPrefValues = {
    useSubjCodes = true,
    useSceneCodes = true,
    protectSubjCodes = true,
    protectSceneCodes = true,
    autoAddParents = false,
    autoAddCodes = false,
    IptcSubjectParent = '_IPTC-MEDIA-SUBJECT',
    IptcSceneParent = '_IPTC-SCENE',
    useIntelGenre = false,
    useProductGenre = false,
    iptcIntelGenreParent = '_IPTC-GENRE',
    iptcProductGenreParent = '_IPTC-PRODUCT-GENRE',
    protectGenreCodes = true,
}

local prefs = LrPrefs.prefsForPlugin(_PLUGIN.id)
for k,v in pairs(defaultPrefValues) do
  if prefs[k] == nil then prefs[k] = v end
end
