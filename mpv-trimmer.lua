local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local start_time = nil
local end_time = nil

local is_windows = package.config:sub(1,1) == '\\'
local home_dir = os.getenv("HOME") or (is_windows and os.getenv("USERPROFILE") or "/home/user")
local OUTPUT_DIR = utils.join_path(home_dir, "Desktop/mpvstreamcut")
local TEMP_VIDEO = utils.join_path(os.getenv("TEMP") or "/tmp", "mpv_temp_video.mp4")

function show_error(message)
    mp.osd_message("❗ " .. message, 6)
    msg.error(message)
end

function set_start_time()
    start_time = nil
    end_time = nil
    start_time = mp.get_property_number("time-pos")
    if not start_time then
        show_error("Failed to get start time")
        return
    end
    mp.osd_message(string.format("⏱️ Start: %.2f", start_time), 3)
    msg.info("Start time set to: " .. start_time)
end

function set_end_time()
    if not start_time then
        show_error("Set start time first (Ctrl+s)")
        return
    end
    end_time = mp.get_property_number("time-pos")
    if not end_time then
        show_error("Failed to get end time")
        return
    end
    mp.osd_message(string.format("⏱️ End: %.2f", end_time), 3)
    msg.info("End time set to: " .. end_time)
end

function get_active_subtitle_info()
    local sid = mp.get_property("sid")
    if sid and sid ~= "no" then
        local tracks = mp.get_property_native("track-list") or {}
        for _, t in ipairs(tracks) do
            if t.type == "sub" and tostring(t.id) == sid then
                return t.external and t["external-filename"] or sid, t.external
            end
        end
    end

    local sub_path = mp.get_property("sub-file")
    if sub_path and sub_path ~= "" and utils.file_info(sub_path) then
        return sub_path, true
    end

    local tracks = mp.get_property_native("track-list") or {}
    for _, t in ipairs(tracks) do
        if t.type == "sub" and t["default"] and not t.external then
            return tostring(t.id), false
        end
    end

    return nil, false
end

function render_video_with_mpv()
    local path = mp.get_property("path")
    if not path then
        show_error("No video loaded")
        return nil
    end

    local cmd = {
        "mpv", path,
        "--start=" .. tostring(start_time),
        "--end=" .. tostring(end_time),
        "--vf=sub",
        "--vo=lavc",
        "--o=" .. TEMP_VIDEO,
        "--of=mp4",
        "--ovc=libx264",
        "--ovcopts=crf=23,preset=medium,profile=baseline,level=3.1,tune=fastdecode",
        "--oac=aac",
        "--no-ocopy-metadata",
        "--quiet",
        "--sub-ass=yes",
        "--sub-ass-force-style=Fonts=true",
        "--vf=format=yuv420p"  -- Ensure compatible pixel format
    }

    local sub_info, is_external = get_active_subtitle_info()
    local vf = mp.get_property("vf")

    if sub_info then
        if is_external then
            table.insert(cmd, "--sub-file=" .. sub_info)
            msg.info("Using external subtitle: " .. sub_info)
        else
            table.insert(cmd, "--sid=" .. sub_info)
            msg.info("Using internal subtitle track: " .. sub_info)
        end
    else
        msg.info("No subtitle detected")
    end

    if vf and vf ~= "" then
        table.insert(cmd, "--vf-add=" .. vf)
        msg.info("Applying video filters: " .. vf)
    end

    msg.info("Rendering video with command: " .. table.concat(cmd, " "))
    local res = mp.command_native({
        name = "subprocess",
        args = cmd,
        capture_stdout = true,
        capture_stderr = true
    })

    if res.status == 0 and utils.file_info(TEMP_VIDEO) then
        msg.info("Video rendered successfully to: " .. TEMP_VIDEO)
        return TEMP_VIDEO
    else
        show_error("Failed to render video: " .. (res.stderr or "Unknown error"))
        return nil
    end
end

function get_clean_filename(path)
    local is_stream = path:match("^https?://") ~= nil
    local _, filename = utils.split_path(path)
    
    if is_stream then
        filename = filename:gsub("%%(%x%x)", function(hex)
            return string.char(tonumber(hex, 16))
        end)
        filename = filename:gsub("%?.*$", ""):gsub("%.%w+$", "")
        if filename == "" then filename = "stream" end
    else
        filename = filename:gsub("%.[^.]+$", "")
    end
    
    filename = filename:gsub("[<>:\"/\\|?*]", "_")
    return filename
end

function cut_video()
    if not start_time or not end_time then
        show_error("Set start/end times first (Ctrl+s/Ctrl+e)")
        return
    end
    if end_time <= start_time then
        show_error("End time must be after start time")
        return
    end

    local path = mp.get_property("path")
    if not path then
        show_error("No video loaded")
        return
    end

    local is_stream = path:match("^https?://") ~= nil
    local clean_name = get_clean_filename(path)
    local output_dir = is_stream and OUTPUT_DIR or utils.split_path(path)
    local output_file = utils.join_path(
        output_dir,
        string.format("%s_%.2f-%.2f.mp4", clean_name, start_time, end_time)
    )

    msg.info("Original path: " .. path)
    msg.info("Clean filename: " .. clean_name)
    msg.info("Output file: " .. output_file)

    if is_stream and not utils.file_info(OUTPUT_DIR) then
        os.execute(is_windows and 'mkdir "' .. OUTPUT_DIR .. '"' or "mkdir -p '" .. OUTPUT_DIR .. "'")
        msg.info("Created output directory: " .. OUTPUT_DIR)
    end

    local temp_video = render_video_with_mpv()
    if not temp_video then
        return
    end

    local cmd = {
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", temp_video,
        "-c:v", "copy",
        "-c:a", "copy",
        "-movflags", "+faststart",  -- Optimize for streaming
        "-pix_fmt", "yuv420p",     -- Ensure pixel format compatibility
        output_file
    }

    msg.info("Finalizing with command: " .. table.concat(cmd, " "))
    local res = mp.command_native({
        name = "subprocess",
        args = cmd,
        capture_stdout = true,
        capture_stderr = true
    })

    if res.status == 0 then
        mp.osd_message("✅ Saved: " .. output_file, 5)
        if utils.file_info(TEMP_VIDEO) then
            os.remove(TEMP_VIDEO)
            msg.info("Cleaned up temp video: " .. TEMP_VIDEO)
        end
    else
        show_error("❌ Failed to finalize: " .. (res.stderr or "Unknown error"))
    end
end

mp.add_key_binding("Ctrl+s", "set_start", set_start_time)
mp.add_key_binding("Ctrl+e", "set_end", set_end_time)
mp.add_key_binding("Ctrl+x", "cut_clip", cut_video)

mp.osd_message("🎬 Video Cutter loaded (Ctrl+s=start, Ctrl+e=end, Ctrl+x=cut)", 3)