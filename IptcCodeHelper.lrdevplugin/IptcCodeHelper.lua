local LrApplication = import 'LrApplication'   -- Import LR namespace which provides access to active catalog
local LrDialogs = import 'LrDialogs'   -- Import LR namespace for user dialog functions
local LrLogger = import 'LrLogger'
local LrTasks = import 'LrTasks'       -- Import functions for starting async tasks

-- Preferences:
local prefs = import 'LrPrefs'.prefsForPlugin(_PLUGIN.id)
local useSubjCodes = prefs.useSubjCodes
local protectSubjCodes = prefs.protectSubjCodes

local useSceneCodes = prefs.useSceneCodes
local protectSceneCodes = prefs.protectSceneCodes

local useIntelGenre = prefs.useIntelGenre
local useProductGenre = prefs.useProductGenre
local IptcIntelGenreParent = prefs.IptcIntelGenreParent
local IptcProductGenreParent = prefs.IptcProductGenreParent
local protectGenreCodes = prefs.protectGenreCodes

-- local useSubjCodes = true
-- local useSceneCodes = true
-- local protectSubjCodes = true
-- local protectSceneCodes = true
--
-- local useIntelGenre = true
-- local useProductGenre = true
-- local IptcIntelGenreParent = 'IPTC-GENRE'
-- local IptcProductGenreParent = 'IPTC-PRODUCT-GENRE'
-- local protectGenreCodes = true

local AllGenreCodes = {}
local topLevelKeywords = {}

local myLogger = LrLogger('IPTC-Keyword-Copy-Plugin-Logfile')
myLogger:enable("logfile")

-- function MyHWLibraryItem.outputToLog(message)
--     myLogger:trace(message)
-- end

-- Log details of Lightroom version in use:
local LrVers = LrApplication.versionTable()
local version =  tostring (LrVers['major'])
local minor =  tostring (LrVers['minor'])
local revision =  tostring (LrVers['revision'])
local build = tostring (LrVers['build'])
local version_string = version .. "." .. minor .. ", Rev: " .. revision .. "\nBuild: " .. build
local message = "Using Lightroom major/minor version: " .. version_string
myLogger:trace(message)


-- local LrMobdebug = import 'LrMobdebug' -- Import LR/ZeroBrane debug module

-- Connect with the ZBS debugger server.
LrTasks.startAsyncTask (function()          -- Certain functions in LR which access the catalog need to be wrapped in an asyncTask.
    -- LrMobdebug.on()                           -- Make this coroutine known to ZBS
    catalog = LrApplication.activeCatalog()   -- Get the active LR catalog. 
    
    local cat_photos = catalog.targetPhotos
    topLevelKeywords = catalog:getKeywords()
    myLogger:trace("Keywords at top level: " .. table.concat(getKeywordNames(topLevelKeywords), ", "))
    
    -- Collect Genre code terms if this functionality is active in prefs.
    if useIntelGenre ~= false or useProductGenre ~= false then
        if useIntelGenre ~= false then
            local iGParentKey = getKeywordByName(IptcIntelGenreParent, topLevelKeywords)
            AllGenreCodes = getKeywordChildNamesTable(iGParentKey)
        end
        
        if useProductGenre ~= false then
            local pGParentKey = getKeywordByName(IptcProductGenreParent, topLevelKeywords)
            local pGenreCodes = getKeywordChildNamesTable(pGParentKey)
            AllGenreCodes = tableMerge(pGenreCodes, AllGenreCodes)
        end
    end
    
    catalog:withWriteAccessDo("0",
        function(context)
            for i, photo in ipairs(cat_photos) do
                filename = photo:getFormattedMetadata('fileName')
                myLogger:trace("Processing photo: " .. filename)
                LMKeywords = photo:getFormattedMetadata('keywordTags')
                myLogger:trace("Photo keywords: " .. LMKeywords)
                local genreString = ''
                local sceneString = ''
                local subjString = ''
                
                -- Deal with prefs for the next part:
                if useSubjCodes or useSceneCodes then
                    subjString, sceneString = getSubjectAndSceneCodesFromKeywords(LMKeywords)
                    myLogger:trace("Subject Codes to add: " .. subjString)
                    myLogger:trace("Scene Codes to add: " .. sceneString)
                end
                
                if useIntelGenre or useProductGenre then
                    local PhotoKeywordTable = explode(LMKeywords, ', ')
                    genreString = getGenreCodesFromKeywords(PhotoKeywordTable)
                    myLogger:trace("Genre Code(s) to add: " .. genreString)
                end
                writeCodes(photo, subjString, sceneString, genreString)
            end
        end
    )
        LrDialogs.message("Done copying IPTC codes.")
    end)

function writeCodes(photo, subjString, sceneString, genreString)
    subjString = trim(subjString)
    sceneString = trim(sceneString)
    genreString = trim(genreString)
    if useSubjCodes then
        if (protectSubjCodes == false or #subjString >= 8) then
            setCodes(photo, "iptcSubjectCode", subjString)
        end
    end
    if useSceneCodes then
        if (protectSceneCodes == false or #sceneString >= 6) then
            setCodes(photo, "scene", sceneString)
        end
    end
    if useIntelGenre or useProductGenre then
        currentGenreCodes = getCurrentIPTCFieldValue('intellectualGenre', photo)
        
        if (genreString ~= nil and #genreString >= 4) then
            setCodes(photo, "intellectualGenre", genreString)
            -- Allow emptying existing Genre Codes if not protected and no genre codes selected as keywords:
        elseif (#currentGenreCodes ~= 0 and protectGenreCodes == false and #genreString == 0) then
            setCodes(photo, "intellectualGenre", genreString)
        end
    end
end

function setCodes(photo, field, codeString)
    photo:setRawMetadata(field, codeString)
end

function getCurrentIPTCFieldValue(field, photo)
    if field == "subject" or field == "iptcSubjectCode"
        then return photo:getFormattedMetadata("iptcSubjectCode")
        elseif field == "scene"
        then return photo:getFormattedMetadata("scene")
        elseif field == "genre" or field == "intellectualGenre"
        then return photo:getFormattedMetadata("intellectualGenre")
        else return "NO_SUCH_FIELD_FAILURE"
    end
end
    

-- Take comma-separated string of all keywords used for a photo and find 6 and 8 -digit numbers
-- which we return as IPTC scene codes and subject codes, respectively:
function getSubjectAndSceneCodesFromKeywords(kwString)
    local subjectCodes = {}
    local sceneCodes = {}
    local kwTable = explode(kwString, ", ")
    for i, word in pairs(kwTable) do
        local isNumber = tonumber(word)
        --tonumber will return nil if it does not parse a number
        if isNumber ~= nil and isNumber ~= false then
            -- myLogger:trace("Number found: " .. word)
            --Subject codes are larger than a 7-digit number
            if #word == 8 then subjectCodes[#subjectCodes+1] = word
            --Scene codes are larger than a 5-digit number
            elseif #word == 6 then sceneCodes[#sceneCodes+1] = word
            end
        end
    end
    local subjectString = table.concat(subjectCodes, ", ")
    local sceneString = table.concat(sceneCodes, ", ")
    
    return subjectString, sceneString
end

-- Requires global AllGenreCodes array to be populated and identifies
-- terms from the formattted list of keywords used on a photo (if a keyword
-- matches an IPTC genre term by name, it will be copied to the IPTC genre field)
function getGenreCodesFromKeywords(KeywordTable)
    local genreTermsForPhoto = {}
    for i, word in pairs(KeywordTable) do
        if (AllGenreCodes[word] ~= nil) then
            genreTermsForPhoto[#genreTermsForPhoto + 1] = word
        end
    end
    return table.concat(genreTermsForPhoto, ", ")
end

--General Lightroom API helper functions for keywords
function getKeywordByName(lookfor, keywordSet)
    for i, kw in pairs(keywordSet) do
        -- If we have found the keyword we want, return it:
        if kw:getName() == lookfor then
            return kw
        -- Otherwise, use recursion to check next level if kw has child keywords:
        else
            local kchildren = kw:getChildren()
            if kchildren and #kchildren > 0 then
                nextkw = getKeywordByName(lookfor, kchildren)
                if nextkw ~= nil then
                    return nextkw
                end
            end
        end
    end
    -- If we have not returned the sought keyword, it's not there:
    return nil
end

--General Lightroom API helper functions for keywords
function getKeywordChildNamesTable(parentKey)
    local kchildren = parentKey:getChildren()
    local childNames = {}
    if kchildren and #kchildren > 0 then
        for i, kw in ipairs(kchildren) do
            -- Add all child names to return table
            local name = kw:getName()
            childNames[name] = name
        end
    end
    -- Return the table of child terms (empty if no child terms for passed keyword)
    return childNames
end


local function getOrDefault(value, default)
   if value == nil then return default end
   return value
end

-- Common Lua helper functions: -------------------------------
-- Merge two tables (like PHP array_merge())
function tableMerge(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            tableMerge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end

function explode(str, div) -- credit: http://richard.warburton.it
    if (div == '') then return false end
    local pos = 0
    local t = {}
    -- for each divider found
    for st, sp in function() return string.find(str, div, pos, true) end do
        table.insert(t, string.sub(str, pos, st-1)) -- Attach chars left of current divider
        pos = sp + 1 -- Jump past current divider
    end
    table.insert(t, string.sub(str, pos)) -- Attach chars right of last divider
    return t
end

-- Check simple table for a given value's presence
function inTable (val, t)
    if type(t) ~= "table" then
        return false
    else
        for i, tval in pairs(t) do
            if val == tval then return true end
        end
    end
    return false
end

-- Get names of all Keyword objects in a table
function getKeywordNames(keywords)  
    local names = {}
    for i, kw in pairs(keywords) do
       names[#names +1] = kw:getName() 
    end
    return names
end

function trim(s)
   if s == nil then return nil end
   return string.gsub(s, '^%s*(.-)%s*$', '%1')
end
