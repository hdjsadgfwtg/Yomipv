--[[ Media encoding engine (FFmpeg)                                 ]]
--[[ Generates command-line arguments for FFmpeg encoding pipeline. ]]

local mp = require("mp")
local MediaUtils = require("media.helpers")

local FFmpegEncoder = {}

FFmpegEncoder.exec = MediaUtils.resolve_binary("ffmpeg")

function FFmpegEncoder.generate_picture_args(config, source, output, time, duration)
	local args = {
		FFmpegEncoder.exec,
		"-hide_banner",
		"-loglevel",
		"error",
		"-y",
	}

	local lead_in = 10
	local jump = math.max(0, time - lead_in)
	local sweep = time - jump

	table.insert(args, "-ss")
	table.insert(args, MediaUtils.to_timestamp_str(jump))
	table.insert(args, "-i")
	table.insert(args, source)
	table.insert(args, "-ss")
	table.insert(args, tostring(sweep))

	local format, quality, width, fps
	if config.picture_animated then
		format = config.animation_format or "webp"
		quality = config.animation_quality or 50
		width = config.animation_width or 720
		fps = config.animation_fps or 8

		table.insert(args, "-t")
		table.insert(args, tostring(duration or 2.0))
	else
		format = config.picture_static_format or "jpg"
		quality = config.picture_static_quality or 85
		width = config.picture_static_width or 0

		table.insert(args, "-frames:v")
		table.insert(args, "1")
	end

	local filters = {}
	if width > 0 then
		table.insert(filters, string.format("scale=%d:-1", width))
	end

	if config.picture_animated and fps and fps > 0 then
		table.insert(filters, string.format("fps=%d", fps))
	end

	if #filters > 0 then
		table.insert(args, "-vf")
		table.insert(args, table.concat(filters, ","))
	end

	if format == "avif" then
		table.insert(args, "-c:v")
		table.insert(args, "libaom-av1")
		table.insert(args, "-crf")
		table.insert(args, tostring(MediaUtils.map_avif_crf(quality)))
		table.insert(args, "-cpu-used")
		table.insert(args, tostring(config.picture_avif_cpu_used or 4))
		if not config.picture_animated then
			table.insert(args, "-still-picture")
			table.insert(args, "1")
		end
	elseif format == "webp" then
		table.insert(args, "-c:v")
		table.insert(args, "libwebp")
		table.insert(args, "-quality")
		table.insert(args, tostring(quality))
		table.insert(args, "-compression_level")
		table.insert(args, tostring(config.picture_webp_compression or 6))
		table.insert(args, "-lossless")
		table.insert(args, config.picture_webp_lossless and "1" or "0")
		if config.picture_animated then
			table.insert(args, "-loop")
			table.insert(args, "0")
		end
	else
		-- Default to JPG
		table.insert(args, "-c:v")
		table.insert(args, "mjpeg")
		table.insert(args, "-q:v")
		-- Map quality to q:v range 1-31
		table.insert(args, tostring(math.floor(31 - (quality / 100) * 30 + 1)))
	end

	table.insert(args, "-an")
	table.insert(args, output)

	return args
end

function FFmpegEncoder.generate_audio_args(config, source, output, start_time, end_time, volume)
	local args = {
		FFmpegEncoder.exec,
		"-hide_banner",
		"-loglevel",
		"error",
		"-y",
	}

	start_time = start_time or 0
	local lead_in = 10
	local jump = math.max(0, start_time - lead_in)
	local sweep = start_time - jump

	table.insert(args, "-ss")
	table.insert(args, MediaUtils.to_timestamp_str(jump))
	table.insert(args, "-i")
	table.insert(args, source)
	table.insert(args, "-ss")
	table.insert(args, tostring(sweep))

	if end_time and start_time then
		table.insert(args, "-t")
		table.insert(args, tostring(end_time - start_time))
	end

	-- Retrieve track information for specific audio mapping
	local track_list = mp.get_property_native("track-list")
	local audio_track_index = 0
	local selected_track_index = 0

	if track_list then
		for _, track in ipairs(track_list) do
			if track.type == "audio" then
				if track.selected then
					selected_track_index = audio_track_index
					break
				end
				audio_track_index = audio_track_index + 1
			end
		end
	end

	table.insert(args, "-map")
	table.insert(args, "0:a:" .. tostring(selected_track_index))

	if volume and volume ~= 100 then
		table.insert(args, "-af")
		table.insert(args, string.format("volume=%.4f", volume / 100.0))
	end

	if config.audio_format == "opus" then
		table.insert(args, "-c:a")
		table.insert(args, "libopus")
		table.insert(args, "-b:a")
		table.insert(args, config.audio_bitrate or "64k")
		table.insert(args, "-application")
		table.insert(args, "voip")
	else
		table.insert(args, "-c:a")
		table.insert(args, "libmp3lame")
		table.insert(args, "-b:a")
		table.insert(args, config.audio_bitrate or "128k")
		table.insert(args, "-compression_level")
		table.insert(args, "0")
	end

	table.insert(args, "-ac")
	table.insert(args, "1")
	table.insert(args, "-vn")
	table.insert(args, output)

	return args
end

return FFmpegEncoder
