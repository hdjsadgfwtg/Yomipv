--[[ Subtitle capture and history monitor     ]]
--[[ Tracks subtitle history and append state ]]

local mp = require("mp")
local msg = require("mp.msg")

local Monitor = {
	history = {},
	recorded = {},
	appending = false,
	max_history = 200,
	history_smart_merge = true,
}

-- Initialize monitor
function Monitor.init(config)
	if config then
		if config.history_max_entries then
			Monitor.max_history = config.history_max_entries
		end
	end
end

-- Check append status
function Monitor.is_appending()
	return Monitor.appending
end

-- Get recorded subtitles
function Monitor.recorded_subs()
	return Monitor.recorded
end

-- Get history entries
function Monitor.get_history(count)
	if count and count > 0 then
		local start_idx = math.max(1, #Monitor.history - count + 1)
		local result = {}
		for i = start_idx, #Monitor.history do
			table.insert(result, Monitor.history[i])
		end
		return result
	end
	return Monitor.history
end

-- Normalize text for comparison
local function normalize(s)
	if not s or s == "" then
		return ""
	end
	local StringOps = require("lib.string_ops")
	local cleaned = s:gsub("{[^}]-}", ""):gsub("\\N", " "):gsub("\\n", " "):gsub("\\h", " ")
	cleaned = StringOps.clean_text(cleaned, false)
	return cleaned:lower():gsub("%s+", " ")
end

-- Get synchronized history
function Monitor.get_synchronized_history(count)
	return Monitor.get_history(count)
end

-- Add entry to history
function Monitor.add_to_history(subtitle)
	if not subtitle or not subtitle.primary_sid or subtitle.primary_sid == "" then
		return
	end

	local StringOps = require("lib.string_ops")
	local primary = subtitle.primary_sid
	local secondary = subtitle.secondary_sid or ""

	local primary_has_jp = StringOps.has_japanese(primary)
	local secondary_has_jp = StringOps.has_japanese(secondary)

	-- Validate primary subtitle
	if not primary_has_jp then
		if secondary_has_jp then
			-- Swap if secondary has Japanese
			primary, secondary = secondary, primary
		else
			-- Discard if usage missing
			return
		end
	end

	-- Validate secondary subtitle alignment
	if secondary ~= "" and subtitle.secondary_end and subtitle.secondary_start then
		local p_start = subtitle.start or 0
		local p_end = subtitle["end"] or 0
		local s_start = subtitle.secondary_start
		local s_end = subtitle.secondary_end

		local overlap_start = math.max(p_start, s_start)
		local overlap_end = math.min(p_end, s_end)
		local overlap_duration = overlap_end - overlap_start

		if overlap_duration < 0.3 then
			msg.info(
				"Discarding misaligned secondary subtitle (overlap: " .. string.format("%.3f", overlap_duration) .. "s)"
			)
			secondary = ""
		end
	end

	-- Find chronological context
	local previous_entry = nil
	local overlap_entry = nil

	for i, entry in ipairs(Monitor.history) do
		-- Match last entry
		local is_exact = math.abs(entry.start - subtitle.start) < 0.1
		local is_contained = false
		if subtitle.start >= entry.start - 0.1 and subtitle["end"] <= (entry["end"] or 0) + 0.1 then
			if normalize(entry.primary_sid):find(normalize(subtitle.primary_sid), 1, true) then
				is_contained = true
			end
		end

		if is_exact or is_contained then
			if i == #Monitor.history then
				overlap_entry = entry
			else
				-- Prevent seek corruption
				return
			end
		end

		-- Find the entry immediately preceding this one
		if entry.start < (subtitle.start - 0.1) then
			if not previous_entry or entry.start > previous_entry.start then
				-- Merge only with last entry
				if i == #Monitor.history then
					previous_entry = entry
				end
			end
		end
	end

	-- Enforce chronological order
	if #Monitor.history > 0 then
		local last = Monitor.history[#Monitor.history]
		if subtitle.start < (last.start - 0.1) then
			-- Discard past entries
			return
		end
	end

	-- Update existing secondary text
	if overlap_entry then
		local norm_overlap = normalize(overlap_entry.primary_sid)
		local norm_new = normalize(primary)
		if norm_overlap == norm_new or norm_overlap:find(norm_new, 1, true) then
			if secondary ~= "" then
				local norm_existing_sec = normalize(overlap_entry.secondary_sid)
				local norm_new_sec = normalize(secondary)

				-- Append unique segments
				if norm_existing_sec == "" then
					overlap_entry.secondary_sid = secondary
				elseif not norm_existing_sec:find(norm_new_sec, 1, true) then
					local to_append = ""
					for sub_line in secondary:gmatch("[^\r\n]+") do
						if not norm_existing_sec:find(normalize(sub_line), 1, true) then
							to_append = to_append .. "\n" .. sub_line
						end
					end
					overlap_entry.secondary_sid = overlap_entry.secondary_sid .. to_append
					-- Extend duration
					overlap_entry.secondary_end =
						math.max(overlap_entry.secondary_end or 0, subtitle.secondary_end or 0)
				end
			end
			return
		end
	end

	-- Handle predecessor
	if previous_entry then
		-- Normalize for comparison
		local norm_prev = normalize(previous_entry.secondary_sid)
		local norm_curr = normalize(secondary)
		local has_secondary = (secondary ~= "")

		-- Check for reappearing event
		local prev_sec_start = previous_entry.secondary_start or -1
		local curr_sec_start = subtitle.secondary_start or -1
		local is_same_event = false
		if math.abs(curr_sec_start - prev_sec_start) < 0.1 then
			is_same_event = true
		else
			for sub_line in secondary:gmatch("[^\r\n]+") do
				local n = normalize(sub_line)
				if n ~= "" and norm_prev:find(n, 1, true) then
					is_same_event = true
					break
				end
			end
		end

		if is_same_event and has_secondary then
			-- Calculate overlap duration
			local sec_end = subtitle.secondary_end or 0
			local prim_start = subtitle.start or 0
			local prim_end = subtitle["end"] or 0

			local overlap_duration = sec_end - prim_start
			local prim_duration = prim_end - prim_start

			-- Avoid division by zero
			if prim_duration <= 0 then
				prim_duration = 2.0
			end

			local overlap_ratio = overlap_duration / prim_duration

			-- Merge if secondary persists significantly
			if overlap_ratio > 0.3 or overlap_duration > 0.3 then
				if Monitor.history_smart_merge then
					local norm_existing = normalize(previous_entry.primary_sid)
					local norm_new = normalize(primary)
					if not norm_existing:find(norm_new, 1, true) then
						previous_entry.primary_sid = previous_entry.primary_sid .. "\n" .. primary
					end
					
					local to_append = ""
					local norm_existing_sec = normalize(previous_entry.secondary_sid)
					for sub_line in secondary:gmatch("[^\r\n]+") do
						if not norm_existing_sec:find(normalize(sub_line), 1, true) then
							to_append = to_append .. "\n" .. sub_line
						end
					end
					previous_entry.secondary_sid = previous_entry.secondary_sid .. to_append
					previous_entry.secondary_end = math.max(previous_entry.secondary_end or 0, subtitle.secondary_end or 0)
					
					previous_entry["end"] = subtitle["end"] or previous_entry["end"]
					return
				end
			else
				-- Clear short lingering subs
				secondary = ""
				subtitle.secondary_sid = ""
			end
		end
	end

	-- Block backward seek entries
	if #Monitor.history > 0 then
		local last = Monitor.history[#Monitor.history]
		if subtitle.start < (last.start - 0.1) then
			return
		end
	end

	-- Insert new entry
	table.insert(Monitor.history, {
		primary_sid = primary,
		secondary_sid = secondary,
		start = subtitle.start or 0,
		["end"] = subtitle["end"] or 0,
		secondary_start = subtitle.secondary_start or 0,
		secondary_end = subtitle.secondary_end or 0,
		timestamp = mp.get_time(),
	})

	-- Sort chronologically
	table.sort(Monitor.history, function(a, b)
		if math.abs(a.start - b.start) < 0.05 then
			return a.timestamp < b.timestamp
		end
		return a.start < b.start
	end)

	if Monitor.max_history > 0 and #Monitor.history > Monitor.max_history then
		table.remove(Monitor.history, 1)
	end
end

-- Start append range
function Monitor.set_to_current_sub()
	local sub_text = mp.get_property("sub-text", "")
	local sub_start = mp.get_property_number("sub-start", 0)
	local sub_end = mp.get_property_number("sub-end", 0)

	if sub_text and sub_text ~= "" then
		Monitor.recorded = {
			{
				primary_sid = sub_text,
				secondary_sid = mp.get_property("secondary-sub-text", ""),
				start = sub_start,
				["end"] = sub_end,
			},
		}
		Monitor.appending = true
		msg.info("Started append mode")
		local Player = require("lib.player")
		Player.notify("Append mode started", "info", 1)
	end
end

-- Reset append mode
function Monitor.clear()
	Monitor.recorded = {}
	Monitor.appending = false
end

-- Clear history entries
function Monitor.clear_history()
	Monitor.history = {}
	msg.info("History cleared")
end

-- Append to recording
function Monitor.append_recorded(subtitle)
	if not Monitor.appending or not subtitle.primary_sid or subtitle.primary_sid == "" then
		return
	end

	-- Skip duplicate append
	if #Monitor.recorded > 0 then
		local last = Monitor.recorded[#Monitor.recorded]
		if math.abs(last.start - subtitle.start) < 0.1 then
			return
		end
	end

	table.insert(Monitor.recorded, {
		primary_sid = subtitle.primary_sid,
		secondary_sid = subtitle.secondary_sid or "",
		start = subtitle.start,
		["end"] = subtitle["end"],
	})
	msg.info("Appended subtitle to range: " .. subtitle.primary_sid)
end

-- Reset and notify
function Monitor.clear_and_notify()
	Monitor.clear()
	local Player = require("lib.player")
	Player.notify("Append mode cleared", "info", 1)
end

-- Export session data
function Monitor.export_current_session()
	if Monitor.appending and #Monitor.recorded > 0 then
		local combined_text = ""
		local first_start = Monitor.recorded[1].start
		local last_end = Monitor.recorded[#Monitor.recorded]["end"]

		for i, sub in ipairs(Monitor.recorded) do
			if i > 1 then
				combined_text = combined_text .. "\n"
			end
			combined_text = combined_text .. sub.primary_sid
		end

		return {
			primary_sid = combined_text,
			start = first_start,
			["end"] = last_end,
		}
	end

	local sub_text = mp.get_property("sub-text", "")
	local sub_start = mp.get_property_number("sub-start", 0)
	local sub_end = mp.get_property_number("sub-end", 0)

	if sub_text and sub_text ~= "" then
		-- Use history for merged lines
		local history = Monitor.get_history()
		local sub_norm = normalize(sub_text)
		for i = #history, 1, -1 do
			local entry = history[i]
			local entry_norm = normalize(entry.primary_sid)
			-- Match if time overlaps OR text is a substring (for mid-merge selection)
			local time_match = math.abs(entry.start - sub_start) < 0.2
			local time_overlap = (sub_start >= entry.start - 0.1) and (sub_start <= entry["end"] + 0.1)
			local text_match = (entry_norm == sub_norm) or (entry_norm:find(sub_norm, 1, true))

			if (time_match or time_overlap) and text_match then
				return {
					primary_sid = entry.primary_sid,
					secondary_sid = entry.secondary_sid,
					start = entry.start,
					["end"] = entry["end"],
				}
			end
		end

		return {
			primary_sid = sub_text,
			secondary_sid = mp.get_property("secondary-sub-text", ""),
			start = sub_start,
			["end"] = sub_end,
		}
	end

	return nil
end

-- Get adjacent entry
function Monitor.get_adjacent_sub(target, direction)
	if not target or not target.start then
		return nil
	end

	local history = Monitor.get_history()
	local target_idx = nil

	local target_norm = normalize(target.primary_sid)

	-- Prefer timestamp to avoid short-text substring false-matches
	for i, sub in ipairs(history) do
		if math.abs(sub.start - target.start) < 0.1 then
			target_idx = i
			break
		end
	end

	-- Exact text fallback for when timestamps differ after a seek
	if not target_idx then
		for i, sub in ipairs(history) do
			local sub_norm = normalize(sub.primary_sid)
			if sub_norm == target_norm then
				target_idx = i
				break
			end
		end
	end

	if not target_idx then
		return nil
	end

	local adjacent_idx = target_idx + direction
	if adjacent_idx >= 1 and adjacent_idx <= #history then
		local Collections = require("lib.collections")
		return Collections.duplicate(history[adjacent_idx])
	end

	return nil
end

-- Async adjacent lookup
function Monitor.get_adjacent_sub_async(target, direction, callback)
	local from_history = Monitor.get_adjacent_sub(target, direction)
	return callback(from_history)
end

return Monitor
