local menuItems = {               -- Items that you add in LrExportMenuItems appear in the Plug-in Extras submenu of the File menu 
    title = "Run IPTC Code Helper", -- The display text for the menu item.
    file = "IptcCodeHelper.lua", -- The script that runs when the item is selected
    enabledWhen = "photosSelected"  -- This plugin is only selectable if at least one photo is currently selected by the user.
}

return {
    LrSdkVersion = 5.0,
    LrSdkMinimumVersion = 5.0, -- minimum SDK version required by this plug-in
    LrToolkitIdentifier = 'photo.lowemo.lightroom.IptcCodeHelper',
    LrPluginInfoUrl = "https://LoweMo.photo/lightroom-IptcCodeHelper",
    LrPluginName = 'IPTC Code Helper',
    LrExportMenuItems = menuItems,
    LrLibraryMenuItems = menuItems,
    LrPluginInfoProvider = 'IptcCodeHelperInfoProvider.lua',
    LrInitPlugin = 'IptcCodeHelperInit.lua',
    VERSION = {display='1.0.0', major=1, minor=0, revision=0, build=1}
}
