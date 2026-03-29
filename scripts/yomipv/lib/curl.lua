--[[ HTTP client using curl subprocess         ]]
--[[ Base functionality for API POST requests. ]]

local mp = require("mp")
local msg = require("mp.msg")
local Platform = require("lib.platform")

local Curl = {}

-- Execute GET request
function Curl.get(url, callback, options)
	options = options or {}
	options.method = "GET"
	return Curl.request(url, nil, function(success, output, err)
		callback(success, output, err)
	end, options)
end

-- Execute POST request (compatibility alias)
function Curl.post(url, json_body, callback)
	return Curl.request(url, json_body, function(_, output, _)
		callback(output)
	end)
end

-- Execute request with detailed callback
function Curl.request(url, json_body, callback, options_or_retry)
	local options = {}
	if type(options_or_retry) == "table" then
		options = options_or_retry
	else
		options.retry_count = options_or_retry or 0
	end

	local retry_count = options.retry_count or 0
	local max_retries = options.max_retries or 2
	local method = options.method or (json_body and "POST" or "GET")
	local headers = options.headers or { ["Content-Type"] = "application/json" }
	local user_agent = options.user_agent or "Yomipv"

	local temp_file = nil
	if json_body then
		local temp_dir = Platform.get_temp_dir()
		local sep = Platform.get_path_separator()
		temp_file = string.format("%s%syomipv_req_%d_%d.json", temp_dir, sep, os.time(), math.random(10000, 99999))

		local f = io.open(temp_file, "wb")
		if not f then
			msg.error("Failed to write to temp file: " .. temp_file)
			return callback(false, { status = -1 }, "IO Error")
		end
		f:write(json_body)
		f:close()
	end

	local args = {
		"curl",
		"-s",
		"-X",
		method,
		"-A",
		user_agent,
		"--connect-timeout",
		"5",
		"--max-time",
		"20",
	}

	for k, v in pairs(headers) do
		table.insert(args, "-H")
		table.insert(args, k .. ": " .. v)
	end

	if temp_file then
		table.insert(args, "--data-binary")
		table.insert(args, "@" .. temp_file)
	end

	table.insert(args, url)

	if retry_count > 0 then
		msg.info(string.format("Retrying curl request to %s (attempt %d/%d)", url, retry_count, max_retries))
	else
		msg.info("Executing curl request to: " .. url)
	end

	mp.command_native_async({
		name = "subprocess",
		playback_only = false,
		capture_stdout = true,
		capture_stderr = true,
		args = args,
	}, function(success, result, error)
		if temp_file then
			os.remove(temp_file)
		end

		local status = result and result.status or -1
		local stdout = result and result.stdout or ""
		local stderr = result and result.stderr or error or ""

		msg.info(
			string.format(
				"Curl finished: success=%s, status=%s, stdout_len=%d, stderr_len=%d",
				tostring(success),
				tostring(status),
				stdout:len(),
				stderr:len()
			)
		)

		if status == 28 and retry_count < max_retries then
			msg.warn(string.format("Curl request timed out. Retrying... (%d/%d)", retry_count + 1, max_retries))
			options.retry_count = retry_count + 1
			return Curl.request(url, json_body, callback, options)
		end

		if stdout ~= "" then
			msg.info("Curl stdout preview: " .. stdout:sub(1, 100))
		end

		local output = {
			status = status,
			stdout = stdout,
			stderr = stderr,
		}

		local is_success = success and output.status == 0
		callback(is_success, output, output.stderr)
	end)
end

return Curl
