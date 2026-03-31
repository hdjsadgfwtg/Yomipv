--[[ Anki word database loader and color resolver ]]

local mp = require("mp")
local utils = require("mp.utils")
local msg = require("mp.msg")
local JSONFormat = require("lib.json_format")

local AnkiDB = {}

local _db = nil
local _loaded = false

local function lerp_hex(r1, g1, b1, r2, g2, b2, t)
	local r = math.floor(r1 + (r2 - r1) * t + 0.5)
	local g = math.floor(g1 + (g2 - g1) * t + 0.5)
	local b = math.floor(b1 + (b2 - b1) * t + 0.5)
	-- Return as ASS BGR hex
	return string.format("%02X%02X%02X", b, g, r)
end

-- New: Red
local NEW_COLOR = "2020FF"

-- Suspended: Dark Red
local SUSPENDED_COLOR = "00008B"

-- Learning: Orange (#FF8C00) -> Yellow (#FFE000), keyed by interval days
local LEARNING_MAX = 21
local LEARNING_R1, LEARNING_G1, LEARNING_B1 = 0xFF, 0x8C, 0x00
local LEARNING_R2, LEARNING_G2, LEARNING_B2 = 0xFF, 0xE0, 0x00

-- Review: Yellow-Green (#AAFF00) -> Cyan (#00FFCC), keyed by interval days
local REVIEW_MAX = 2000
local REVIEW_R1, REVIEW_G1, REVIEW_B1 = 0xAA, 0xFF, 0x00
local REVIEW_R2, REVIEW_G2, REVIEW_B2 = 0x00, 0xFF, 0xCC

local function load_db()
	if _loaded then
		return _db
	end
	_loaded = true

	local path = mp.find_config_file("script-opts/anki_words.json")
	if not path then
		msg.warn("anki_db: anki_words.json not found in script-opts/")
		return nil
	end

	local file = io.open(path, "r")
	if not file then
		msg.warn("anki_db: cannot open " .. path)
		return nil
	end

	local content = file:read("*a")
	file:close()

	local ok, parsed = pcall(utils.parse_json, content)
	if not ok or type(parsed) ~= "table" or type(parsed.words) ~= "table" then
		msg.warn("anki_db: failed to parse anki_words.json")
		return nil
	end

	_db = parsed.words
	local count = 0
	for _ in pairs(_db) do count = count + 1 end
	msg.info("anki_db: loaded " .. tostring(count) .. " words")
	return _db
end

local function word_color(entry)
	if not entry then return nil end
	local state = entry.state
	local interval = entry.interval or 0

	if state == "New" then
		return NEW_COLOR
	elseif state == "Suspended" then
		return SUSPENDED_COLOR
	elseif state == "Learning" then
		local t = math.min(interval / LEARNING_MAX, 1.0)
		return lerp_hex(LEARNING_R1, LEARNING_G1, LEARNING_B1, LEARNING_R2, LEARNING_G2, LEARNING_B2, t)
	elseif state == "Review" then
		local t = math.min(interval / REVIEW_MAX, 1.0)
		return lerp_hex(REVIEW_R1, REVIEW_G1, REVIEW_B1, REVIEW_R2, REVIEW_G2, REVIEW_B2, t)
	end
	return nil
end

local function resolve_term_color(db, hw)
	if type(hw) == "string" then
		if hw ~= "" then
			local entry = db[hw]
			if entry then return word_color(entry), hw end
		end
	elseif type(hw) == "table" then
		-- Check for term/expression in this table
		local term = hw.term or hw.expression
		if type(term) == "string" and term ~= "" then
			local entry = db[term]
			if entry then return word_color(entry), term end
		end

		-- Recurse into array elements if it's an array
		for _, v in ipairs(hw) do
			local color, found_term = resolve_term_color(db, v)
			if color then return color, found_term end
		end

		-- Fallback: check all string values in the table if no ipairs match
		for _, v in pairs(hw) do
			if type(v) == "string" and v ~= "" then
				local entry = db[v]
				if entry then return word_color(entry), v end
			end
		end
	end
	return nil
end

-- Returns ASS-formatted BGR color or nil for any headword match in the DB
function AnkiDB.get_word_color(headwords)
	local db = load_db()
	if not db or not headwords then return nil end

	local color, term = resolve_term_color(db, headwords)
	if color then
		msg.info("anki_db: found '" .. term .. "' -> color: " .. color)
		return color
	end
	return nil
end

-- Forces a reload on next access (call after anki_words.json is regenerated)
function AnkiDB.reload()
	_db = nil
	_loaded = false
end

-- Immediately add or update a word in the local cache without a full rebuild
function AnkiDB.add_word(word, state, interval)
	if not _loaded then
		load_db()
	end
	if _db and type(word) == "string" and word ~= "" then
		local new_state = state or "New"
		local new_interval = interval or 0
		_db[word] = { state = new_state, interval = new_interval }
		msg.info("anki_db: incrementally added word: " .. word)

		local path = mp.find_config_file("script-opts/anki_words.json")
		if path then
			local file = io.open(path, "r")
			if file then
				local content = file:read("*a")
				file:close()
				local ok, parsed = pcall(utils.parse_json, content)
				if ok and type(parsed) == "table" and type(parsed.words) == "table" then
					parsed.words[word] = { state = new_state, interval = new_interval }
					local new_json = JSONFormat.format(parsed)
					if new_json then
						local out_file = io.open(path, "w")
						if out_file then
							out_file:write(new_json)
							out_file:close()
						end
					end
				end
			end
		end
	end
end

return AnkiDB
