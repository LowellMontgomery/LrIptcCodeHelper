local Require = require 'Require'.path ("../../debugscript.lrdevplugin")
local Debug = require 'Debug'.init ()
require 'strict'

local LrApplication = import 'LrApplication'   -- Import LR namespace which provides access to active catalog
local LrDialogs = import 'LrDialogs'   -- Import LR namespace for user dialog functions
local LrLogger = import 'LrLogger'
local LrProgressScope = import 'LrProgressScope'
local LrTasks = import 'LrTasks'       -- Import functions for starting async tasks
local LUTILS = require 'LUTILS'
local KwUtils = require 'KwUtils'


-- Preferences:
local prefs = import 'LrPrefs'.prefsForPlugin(_PLUGIN.id)
local useSubjCodes = prefs.useSubjCodes
local protectSubjCodes = prefs.protectSubjCodes

local useSceneCodes = prefs.useSceneCodes
local protectSceneCodes = prefs.protectSceneCodes

local useIntelGenre = prefs.useIntelGenre
local useProductGenre = prefs.useProductGenre
local iptcIntelGenreParent = LUTILS.trim(prefs.iptcIntelGenreParent)
local iptcProductGenreParent = LUTILS.trim(prefs.iptcProductGenreParent)
local protectGenreCodes = prefs.protectGenreCodes

local iptcSubjectParentName = LUTILS.trim(prefs.IptcSubjectParent)
local iptcSceneParentName = LUTILS.trim(prefs.IptcSceneParent)

local allGenreCodes = {}
local topLevelKeywords = {}

local myLogger = LrLogger('IPTC-Keyword-Copy-Plugin-Logfile')
myLogger:enable("logfile")

-- Log details of Lightroom version in use:
local LrVers = LrApplication.versionTable()
local version =  tostring (LrVers['major'])
local minor =  tostring (LrVers['minor'])
local revision =  tostring (LrVers['revision'])
local build = tostring (LrVers['build'])
local version_string = version .. "." .. minor .. ", Rev: " .. revision .. "  Build: " .. build
local message = "Using Lightroom major/minor version: " .. version_string
myLogger:trace(message)

-- Connect with the ZBS debugger server.
LrTasks.startAsyncTask (Debug.showErrors(function()           -- Certain functions in LR which access the catalog need to be wrapped in an asyncTask.
    local catalog = LrApplication.activeCatalog()   -- Get the active LR catalog.

    local cat_photos = catalog.targetPhotos
    local topLevelKeywords = catalog:getKeywords()
	local allAddedKeywordNames = {}

    -- Collect Genre code terms if this functionality is active in prefs.
    if useIntelGenre ~= false or useProductGenre ~= false then
        if useIntelGenre ~= false then
            local iGParentKey = KwUtils.getKeywordByName(iptcIntelGenreParent, topLevelKeywords)
            if iGParentKey == nil then
                local errorText = 'Configured IPTC Intellectual Genre Parent term does not seem to exist: "' .. iptcIntelGenreParent .. '"'
                local message = LOC '$$$/IptcCodeHelper/iptcIntelGenreParent/nonExistentIGParentMessage=' .. errorText
                LrDialogs.message(string.format(message), 'ERROR');
                return
            else
                allGenreCodes = KwUtils.getKeywordChildNamesTable(iGParentKey)
            end

        end
        if useProductGenre ~= false then
            local pGParentKey = KwUtils.getKeywordByName(iptcProductGenreParent, topLevelKeywords)
            if pGParentKey == nil then
                local errorText = 'Configured IPTC Product Genre Parent term does not seem to exist: "' .. iptcProductGenreParent .. '"'
                local message = LOC '$$$/IptcCodeHelper/iptcProductGenreParent/nonExistentPGParentMessage=' .. errorText
                LrDialogs.message(string.format(message), 'ERROR');
                return
            else
                local pGenreCodes = KwUtils.getKeywordChildNamesTable(pGParentKey)
                allGenreCodes = LUTILS.tableMerge(pGenreCodes, allGenreCodes)
            end
        end
		-- We will ignore the case for genre codes
		for i,v in ipairs(allGenreCodes) do
			allGenreCodes[i] = string.lower(v)
		end
    end

    -- If configured to add new keywords (parent codes and/or inferable Subject and/or Scene Codes),
    -- iterate over all photos and perform this process. This is separate as it may be (or bigger sets of images)
    -- that this is more time-consuming and requires a prolonged write access. It must also happen before the copy
    -- process and requires several steps, so it breaks that up.
	
	local actionTitle = ""
	if (prefs.autoAddParents and prefs.autoAddCodes) then
		actionTitle = "Adding IPTC & parent keywords"
	elseif prefs.autoAddParents then
		actionTitle = "Adding parent keywords"
	elseif prefs.autoAddCodes then
		actionTitle = "Adding code keywords"
	elseif useSubjCodes or useSceneCodes or useProductGenre or useIntelGenre then
		actionTitle = "Copying codes to IPTC fields"
	end
	
    catalog:withWriteAccessDo(actionTitle, function(context)

		local metaEditProgress = LrProgressScope({ title=actionTitle, functionContext = context })
		metaEditProgress:setCancelable(true)

        for i, photo in ipairs(cat_photos) do
		    if metaEditProgress:isCanceled() then
		      break;
		    end
			metaEditProgress:setPortionComplete(i, #cat_photos)
            local fileName = photo:getFormattedMetadata('fileName')
			local photoProgress = LrProgressScope { parent = metaEditProgress, caption = "Processing " .. fileName}
			photoProgress:setCaption("Processing " .. fileName)
		    if prefs.autoAddParents == true or prefs.autoAddCodes == true then
                if prefs.autoAddParents then
					local currentTask = "Adding keywords for: " .. fileName
                    myLogger:trace(currentTask)
					photoProgress:setCaption(currentTask)
                    local newKeywords = KwUtils.addAllKeywordParentsForPhoto(photo)
                    if newKeywords ~= {} then
                        local newKeywordNames = KwUtils.getKeywordNames(newKeywords)
						allAddedKeywordNames[i] = newKeywordNames
                        local addedKeywordsString = table.concat(newKeywordNames, ", ")
                        myLogger:trace("Parent terms added for photo: " .. addedKeywordsString)
                    else
                        myLogger:trace("No new parent keywords added for photo")
                    end
                end
                -- Now we can check for codes to auto-add, if this is configured
                if prefs.autoAddCodes == true then
					local currentTask = "Adding code keywords for photo: " .. fileName
					photoProgress:setCaption(currentTask)

                    local keywordsForPhoto = photo:getRawMetadata('keywords')
                    local iptcSubjectParentKey = nil
                    local iptcSceneParentKey = nil
                    local inferableCodeKeywords = {}
                    local existingCodeKeywords = {}
                    if iptcSubjectParentName ~= '' then
                        iptcSubjectParentKey = KwUtils.getKeywordByName(iptcSubjectParentName, topLevelKeywords)
                    end
                    if iptcSceneParentName ~= '' then
                        iptcSceneParentKey = KwUtils.getKeywordByName(iptcSceneParentName, topLevelKeywords)
                    end
                    -- Iterate over existing keywords.
                    for _,kw in pairs(keywordsForPhoto) do
                        local keyName = kw:getName()
                        local keyType = keywordType(keyName)
                        -- Let's assume that if we have a code keyword already selected, then we also have its direct parent
                        -- so we can skip adding parents for the "code keyword".
                        if keyType ~= 'standard' then
                            existingCodeKeywords[#existingCodeKeywords + 1] = kw
                        else
                            local keyParents = KwUtils.getAllParentKeywords(kw)
                            local keyPlusParents = type(keyParents) == 'table' and LUTILS.tableMerge(keyParents, {kw}) or {kw}

                            if iptcSubjectParentKey ~= nil and LUTILS.inTable(iptcSubjectParentKey, keyParents) then
                                -- See if kw or parents has a child term which is a code and add to inferableCodeKeywords, if so:
                                for _,key in pairs(keyPlusParents) do
                                    local keyKids = key:getChildren()
                                    for _,kid in pairs(keyKids) do
                                        local kidName = kid:getName()
                                        local kidType = keywordType(kidName)
                                        if kidType ~= 'standard' and LUTILS.inTable(kid, keywordsForPhoto) == false and LUTILS.inTable(kid, inferableCodeKeywords) == false then
                                            inferableCodeKeywords[#inferableCodeKeywords+1] = kid
                                        end
                                    end
                                end
                            elseif iptcSceneParentKey ~= nil and LUTILS.inTable(iptcSceneParentKey, keyParents) then
                                for _,key in pairs(keyPlusParents) do
                                    local keyKids = key:getChildren()
                                    for _,kid in pairs(keyKids) do
                                        local kidName = kid:getName()
                                        local kidType = keywordType(kidName)
                                        if kidType ~= 'standard' and LUTILS.inTable(kid, keywordsForPhoto) == false and LUTILS.inTable(kid, inferableCodeKeywords) == false then
                                            inferableCodeKeywords[#inferableCodeKeywords + 1] = kid
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if inferableCodeKeywords ~= {} then
                        for _,kwToAdd in pairs(inferableCodeKeywords) do
                            photo:addKeyword(kwToAdd)
                        end
                        local inferableCodeKeywordNames = KwUtils.getKeywordNames(inferableCodeKeywords)
                        local inferableCodeKeywordsString = table.concat(inferableCodeKeywordNames, ", ")
                        myLogger:trace("Added code keywords: " .. inferableCodeKeywordsString)
						-- Newly added IPTC codes are not available until the catalog updates so we save them in
						-- our addedCodeKeywords[i] to allow access in the next loop.
						-- Some of these terms may be Genre terms (not numerical codes), so we should just add all new keyword names to this array
						local addedKeywords = allAddedKeywordNames[i] ~= nil and allAddedKeywordNames[i] or {}
						allAddedKeywordNames[i] = LUTILS.tableMerge(addedKeywords, inferableCodeKeywordNames)
					end
                end
        	end

			if useSubjCodes or useSceneCodes or useIntelGenre or useProductGenre then
				local currentTask = "Copying IPTC codes for: " .. fileName
				photoProgress:setCaption(currentTask)
                myLogger:trace(currentTask)
                local LMKeywords = photo:getFormattedMetadata('keywordTags')
			
				-- Add any newly added code keywords to these
				if allAddedKeywordNames[i] ~= nil then
					local LMKeyNames = LUTILS.split(LMKeywords, ", ")
					local mergedKeyNames = LUTILS.tableMerge(allAddedKeywordNames[i], LMKeyNames)
					LMKeywords = table.concat(mergedKeyNames, ", ")
				end
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
                    local PhotoKeywordTable = LUTILS.split(LMKeywords, ', ')
                    genreString = getGenreCodesFromKeywords(PhotoKeywordTable)
					-- Debug.lognpp("genreString", genreString)
                    myLogger:trace("Genre Code(s) to add: " .. genreString)
                end
                writeCodes(photo, subjString, sceneString, genreString)
            end
									
			-- Now process the IPTC codes, moving them to their respective fields.
        end
		
		metaEditProgress:done()
		local dialogMessage = metaEditProgress:isCanceled() and actionTitle .. " process canceled; no images changed." or actionTitle .. ": Done editing metadata for " .. #cat_photos .. " images."
	    LrDialogs.message(dialogMessage)
    end);

end))

function writeCodes(photo, subjString, sceneString, genreString)
    subjString = LUTILS.trim(subjString)
    sceneString = LUTILS.trim(sceneString)
    genreString = LUTILS.trim(genreString)
    if useSubjCodes then
        if (protectSubjCodes == false or #subjString >= 8) then
            photo:setRawMetadata("iptcSubjectCode", subjString)
        end
    end
    if useSceneCodes then
        if (protectSceneCodes == false or #sceneString >= 6) then
            photo:setRawMetadata("scene", sceneString)
        end
    end
    if useIntelGenre or useProductGenre then
        local currentGenreCodes = getCurrentIPTCFieldValue('intellectualGenre', photo)

        if (genreString ~= nil and #genreString >= 4) then
            photo:setRawMetadata("intellectualGenre", genreString)
            -- Allow emptying existing Genre Codes if not protected and no genre codes selected as keywords:
        elseif (#currentGenreCodes ~= 0 and protectGenreCodes == false and #genreString == 0) then
            photo:setRawMetadata("intellectualGenre", genreString)
        end
    end
end

-- Get current value from any of the supported IPTC fields
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
    local kwTable = LUTILS.split(kwString, ", ")
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

-- Requires global allGenreCodes array to be populated and identifies
-- terms from the formattted list of keywords used on a photo (if a keyword
-- matches an IPTC genre term by name, it will be copied to the IPTC genre field)
function getGenreCodesFromKeywords(KeywordTable)
    local genreTermsForPhoto = {}
    for _,word in ipairs(KeywordTable) do
        if LUTILS.inTable(string.lower(word), allGenreCodes) == true then
            genreTermsForPhoto[#genreTermsForPhoto + 1] = word
        end
    end
    return table.concat(genreTermsForPhoto, ", ")
end

function keywordType(keyName)
    local isNumber = tonumber(keyName)
    --tonumber will return nil if it does not parse a number
    if isNumber ~= nil and isNumber ~= false then
        --Subject codes are larger than a 7-digit number
        if #keyName == 8 then return 'subject'
        --Scene codes are larger than a 5-digit number
            elseif #keyName == 6 then return 'scene'
        end
    end
    -- Not a subject or scene code, but a normal keyword
    return 'standard'
end
