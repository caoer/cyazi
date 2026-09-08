-- ucc: start a ucc-* agent seat in yazi's current directory, in this
-- terminal, and return to yazi when it exits — the same handover `!` and
-- lazygit make.
--
--   plugin ucc          ucc-auto, launcher defaults (g a)
--   plugin ucc -- pick  choose launcher (fzf), model and effort (popups) (g A)
--
-- Model and effort are separate flags on every launcher; "launcher default"
-- passes neither. Endpoint wrappers pin their model and refuse (exit 2) a
-- different explicit one, so the default is the safe pick on anything but
-- ucc-auto / claude-profile launchers.

local get_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

local UCC_HOME = os.getenv("UCC_HOME") or (os.getenv("HOME") .. "/.local/share/ucc")

local MODELS = {
	{ on = "d", desc = "launcher default", value = nil },
	{ on = "f", desc = "claude-fable-5-1", value = "claude-fable-5-1" },
	{ on = "F", desc = "claude-fable-5", value = "claude-fable-5" },
	{ on = "o", desc = "claude-opus-5", value = "claude-opus-5" },
	{ on = "O", desc = "claude-opus-4-8", value = "claude-opus-4-8" },
	{ on = "s", desc = "sonnet", value = "sonnet" },
}

local EFFORTS = {
	{ on = "d", desc = "launcher default", value = nil },
	{ on = "l", desc = "low", value = "low" },
	{ on = "m", desc = "medium", value = "medium" },
	{ on = "h", desc = "high", value = "high" },
	{ on = "x", desc = "xhigh", value = "xhigh" },
	{ on = "M", desc = "max", value = "max" },
}

local function notify(content, level)
	ya.notify({ title = "ucc", content = content, level = level or "info", timeout = 4 })
end

-- Launcher names: ucc-* in $UCC_HOME/bin minus the -cli / -ip helpers and the
-- ucc-source-* env dumps, which are not seats. Sorted; ucc-auto floats first.
local function pick_launcher()
	local script = "cd " .. ya.quote(UCC_HOME .. "/bin") .. [[ && {
  [ -x ucc-auto ] && echo ucc-auto
  ls ucc-* | grep -v -e '-cli$' -e '-ip$' -e '^ucc-source-' -e '^ucc-auto$'
} | fzf --prompt='launcher> ' --no-multi]]
	local out, err = Command("sh")
		:arg({ "-c", script })
		:stdin(Command.INHERIT)
		:stdout(Command.PIPED)
		:stderr(Command.INHERIT)
		:output()
	if not out then
		notify("fzf failed: " .. tostring(err), "error")
		return nil
	end
	local name = out.stdout:gsub("%s+$", "")
	return name ~= "" and name or nil
end

local function pick(cands)
	local i = ya.which({ cands = cands })
	return i and cands[i] or nil
end

return {
	entry = function(_, job)
		local cwd = get_cwd()
		local launcher, argv = "ucc-auto", {}

		if job.args[1] == "pick" then
			local permit = ui.hide()
			launcher = pick_launcher()
			permit:drop()
			if not launcher then
				return
			end
			local model = pick(MODELS)
			if not model then
				return
			end
			local effort = pick(EFFORTS)
			if not effort then
				return
			end
			if model.value then
				argv[#argv + 1] = "--model"
				argv[#argv + 1] = model.value
			end
			if effort.value then
				argv[#argv + 1] = "--effort"
				argv[#argv + 1] = effort.value
			end
		end

		local permit = ui.hide()
		local status, err = Command(UCC_HOME .. "/bin/" .. launcher)
			:arg(argv)
			:cwd(cwd)
			:stdin(Command.INHERIT)
			:stdout(Command.INHERIT)
			:stderr(Command.INHERIT)
			:status()
		permit:drop()

		if not status then
			notify(launcher .. " failed to start: " .. tostring(err), "error")
		elseif not status.success then
			notify(launcher .. " exited with code " .. tostring(status.code), "warn")
		end
		ya.emit("refresh", {})
	end,
}
