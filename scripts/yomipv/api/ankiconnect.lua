--[[ AnkiConnect API client             ]]
--[[ Note creation and media management ]]

local utils = require("mp.utils")
local msg = require("mp.msg")

local AnkiConnect = {}

local DEFAULT_VERSION = 6

function AnkiConnect.new(config, curl)
	local obj = {
		config = config,
		curl = curl,
		url = "http://" .. config.ankiconnect_url,
		media_dir_path = nil,
		_pending_media_path_callbacks = nil,
	}
	setmetatable(obj, AnkiConnect)
	AnkiConnect.__index = AnkiConnect
	return obj
end

function AnkiConnect:request(action, params, callback)
	if not self.url then
		return callback(nil, "AnkiConnect URL not configured")
	end

	local request_body = {
		action = action,
		version = DEFAULT_VERSION,
		params = params or {},
	}

	if self.config.ankiconnect_api_key and self.config.ankiconnect_api_key ~= "" then
		request_body.key = self.config.ankiconnect_api_key
	end

	local json_body = utils.format_json(request_body):gsub('"params":%s*%[%s*%]', '"params":{}')
	msg.info(string.format("AnkiConnect request: %s", action))
	msg.info("AnkiConnect body: " .. json_body:sub(1, 200) .. (#json_body > 200 and "…" or ""))

	self.curl.request(self.url, json_body, function(_, curl_output, _error_str)
		if type(callback) ~= "function" then
			return
		end

		if not curl_output then
			return callback(nil, "No response from AnkiConnect")
		end

		if curl_output.status ~= 0 then
			return callback(nil, "HTTP request failed: " .. tostring(curl_output.status))
		end

		local response = utils.parse_json(curl_output.stdout)
		if not response then
			return callback(nil, "Failed to parse AnkiConnect response")
		end

		if response.error then
			return callback(nil, response.error)
		end

		callback(response.result, nil)
	end)
end

function AnkiConnect:add_note(deck, note_type, fields, tags, callback)
	local tag_array = tags
	if type(tags) == "string" then
		tag_array = {}
		for tag in tags:gmatch("%S+") do
			table.insert(tag_array, tag)
		end
	end

	local params = {
		note = {
			deckName = deck,
			modelName = note_type,
			fields = fields,
			tags = tag_array or {},
			options = {
				allowDuplicate = false,
			},
		},
	}

	self:request("addNote", params, callback)
end

function AnkiConnect:update_note_fields(note_id, fields, callback)
	local params = {
		note = {
			id = note_id,
			fields = fields,
		},
	}

	self:request("updateNoteFields", params, function(_result, error)
		if error then
			return callback(false, error)
		end
		callback(true, nil)
	end)
end

function AnkiConnect:store_media_file(filename, data, callback)
	local params = {
		filename = filename,
		data = data,
	}

	self:request("storeMediaFile", params, function(_result, error)
		if error then
			return callback(false, error)
		end
		callback(true, nil)
	end)
end

function AnkiConnect:ingest_media(filename, content, callback)
	self:store_media_file(filename, content, function(_success, error)
		if error then
			msg.warn("Failed to store media file " .. filename .. ": " .. error)
		else
			msg.info("Stored media file: " .. filename)
		end
		if callback then
			callback()
		end
	end)
end

function AnkiConnect:get_media_dir_path(callback)
	if self.media_dir_path then
		return callback(self.media_dir_path, nil)
	end

	if self._pending_media_path_callbacks then
		table.insert(self._pending_media_path_callbacks, callback)
		return
	end

	self._pending_media_path_callbacks = { callback }

	self:request("getMediaDirPath", {}, function(result, error)
		if not error and result then
			self.media_dir_path = result
		end

		local callbacks = self._pending_media_path_callbacks
		self._pending_media_path_callbacks = nil

		for _, cb in ipairs(callbacks) do
			cb(result, error)
		end
	end)
end

function AnkiConnect:get_media_path(callback)
	return self:get_media_dir_path(callback)
end

function AnkiConnect:gui_browse(query, callback)
	local params = {
		query = query or "",
	}

	self:request("guiBrowse", params, callback)
end

function AnkiConnect:gui_select_note(note_id, callback)
	local params = {
		note = note_id,
	}

	self:request("guiSelectNote", params, function(result, error)
		if error then
			return callback(false, error)
		end
		callback(result, nil)
	end)
end

function AnkiConnect:find_notes(query, callback)
	local params = {
		query = query,
	}

	self:request("findNotes", params, callback)
end

function AnkiConnect:notes_info(note_ids, callback)
	local params = {
		notes = note_ids,
	}

	self:request("notesInfo", params, callback)
end

function AnkiConnect:get_note_fields(note_id, callback)
	self:notes_info({ note_id }, function(notes, error)
		if error then
			return callback(nil, error)
		end
		if notes and #notes > 0 then
			local raw_fields = notes[1].fields
			if not raw_fields then
				return callback(nil, "Note fields not found")
			end

			local clean_fields = {}
			for k, v in pairs(raw_fields) do
				clean_fields[k] = v.value
			end
			return callback(clean_fields, nil)
		end
		callback(nil, "Note not found")
	end)
end

function AnkiConnect:sync_media_fields(note_id, fields, _tags, callback)
	self:update_note_fields(note_id, fields, function(_success, error)
		if error then
			msg.error("Failed to update note " .. note_id .. ": " .. error)
		else
			msg.info("Updated note " .. note_id)
		end
		if callback then
			callback()
		end
	end)
end

return AnkiConnect
