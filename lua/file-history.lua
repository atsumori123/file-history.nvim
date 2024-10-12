-- separator
local SEPARATOR = vim.fn.has('win32') == 1 and "\\" or "/"
-- History file
local HISTORY_FILE = ""
-- old files
local OldFiles = {}

local self = {
		winid	= nil,
		bufnr	= nil,
	}

local M = {}

----------------------------------------------------------------
-- warn_msg
----------------------------------------------------------------
local function warn_msg(msg)
	vim.cmd("echohl WarningMsg")
	vim.cmd(string.format('echo "%s"', msg))
	vim.cmd("echohl None")
end

----------------------------------------------------------------
-- read_file
----------------------------------------------------------------
local function read_file_history()
	OldFiles = {}
	local f = io.open(HISTORY_FILE, 'r')
	if f ~= nil then
		for line in f:lines() do table.insert(OldFiles, line) end
		f:close()
	end
end

----------------------------------------------------------------
--  write_history_file
----------------------------------------------------------------
local function write_file_history()
	local f = io.open(HISTORY_FILE, 'w')
	for k,v in pairs(OldFiles) do f:write(v.."\n") end
	f:close()
end

----------------------------------------------------------------
-- get_filename
----------------------------------------------------------------
local function get_filename(path)
	local str = string.reverse(path)
	local idx = string.find(str, SEPARATOR)
	str = string.sub(str, 0, idx - 1)
	return string.reverse(str)
end

----------------------------------------------------------------
-- get_filepath
----------------------------------------------------------------
local function get_filepath(line)
	local a = string.find(line, "%(")
	local b = string.find(line, "%)")
	return string.sub(line, a + 1, b - 1)
end

----------------------------------------------------------------
-- input_char
----------------------------------------------------------------
local function input_char()
	local pat = "abcdefghijklmnopqrstuvwxyz."

	warn_msg("Filtering for 1 character: ")
	local c = vim.fn.nr2char(vim.fn.getchar())
	n = string.find(pat, c)

	return n ~= nil and c or ""
end

----------------------------------------------------------------
-- close
----------------------------------------------------------------
local function close()
	vim.api.nvim_win_close(self.winid, true)
	self.winid = nil
end

----------------------------------------------------------------
-- select_item
----------------------------------------------------------------
local function select_item(open_cmd)
	line = vim.fn.getline(".")
	if line == '' then return end

	-- Automatically close the window
	close()

	-- get file path from selected line data
	local file = get_filepath(line)

	-- If already open, jump to it or Edit the file
	winnum = vim.fn.bufwinnr('^'..file..'$')
	if winnum > 0 then
		vim.cmd(winnum.."wincmd w")
	else
		-- Return to recent window and open
		vim.cmd("wincmd p")
		vim.cmd(open_cmd.." "..file)
	end
end

----------------------------------------------------------------
-- draw_buffer
----------------------------------------------------------------
local function draw_buffer()
	-- make display format
	local output = {}
	for k,v in pairs(OldFiles) do
		table.insert(output, " "..get_filename(v).."  ("..v..")")
	end

	-- draw buffer
	vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, output)
	vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
end

----------------------------------------------------------------
-- filtering_item
----------------------------------------------------------------
local function filtering_item()
	read_file_history()

	-- input a search character
	local w = {}
	local c = input_char()
	if string.len(c) ~= 0 then
		-- filtering
		for k,v in pairs(OldFiles) do
			if string.find(get_filename(v), c) == 1 then
				table.insert(w, v)
			end
		end
		OldFiles = w
	end

	draw_buffer()
end

----------------------------------------------------------------
-- delete_item_from_file_history
----------------------------------------------------------------
local function delete_item_from_file_history()
	read_file_history()
	local file = get_filepath(vim.fn.getline("."))

	-- remove from file history
	for k,v in pairs(OldFiles) do
		if v == file then
			table.remove(OldFiles, k)
			write_file_history()
			break
		end
	end

	-- remove from window
	vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
	vim.cmd([[del _]])
	vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
end

----------------------------------------------------------------
-- remove_non_existing_item_from_history
----------------------------------------------------------------
local function remove_non_existing_item_from_history()
	read_file_history()
	local backup = OldFiles

	local count = 0
	for i = #OldFiles, 1, -1 do
		if vim.fn.filereadable(OldFiles[i]) == 0 then
			table.remove(OldFiles, i)
			count = count + 1
		end
	end

	local yesno = vim.fn.input(count.." files remove ? [y/n] ")
	if yesno == "y" then
		write_file_history()
		draw_buffer()
	else
		OldFiles = backup
	end
end

----------------------------------------------------------------
-- get_window_opts
----------------------------------------------------------------
local function get_window_opts()
	local width = math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
	local height = math.ceil(math.min(20, (vim.o.lines - 10)))
	local row = math.ceil(vim.o.lines - height) * 0.5 - 1
	local col = math.ceil(vim.o.columns - width) * 0.5 - 1

	return {title	= " file history ",
			style	= "minimal",
			relative= "editor",
			height	= height,
			width	= width,
			col		= col,
			row		= row,
			border	= "single",}
end

----------------------------------------------------------------
-- open_window
----------------------------------------------------------------
local function open_window()
	-- create buffer
	if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
		self.bufnr = vim.api.nvim_create_buf(false, true)
	end

	-- create floating window
	self.winid = vim.api.nvim_open_win(self.bufnr, true, get_window_opts())

	-- draw lines to buffer
	draw_buffer()

	-- set buffer option
	vim.api.nvim_buf_set_option(self.bufnr, 'bufhidden', 'delete')
	vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)

	-- set background color & highlighting Border and file names
	vim.cmd([[set winhighlight=Normal:Normal]])
	vim.api.nvim_set_hl(0, 'FloatBorder', {link = 'Normal'})
	vim.cmd([[syntax match FileHistoryFName '^.\{-}\ze(']])
	vim.api.nvim_set_hl(0, 'FileHistoryFName', {default = true, link = 'Identifier'})

	-- Create mappings to select and edit a file from the OL list
	local opts = { noremap = true, silent = true, buffer = self.bufnr }
	vim.keymap.set('n', '<CR>', function() select_item("edit") end, opts)
	vim.keymap.set('n', 'l', function() select_item("edit") end, opts)
	vim.keymap.set('n', 'v', function() select_item("vsplit") end, opts)
	vim.keymap.set('n', 'f', function() filtering_item() end, opts)
	vim.keymap.set('n', 'd', function() delete_item_from_file_history() end, opts)
	vim.keymap.set('n', 'q', function() close() end, opts)
	vim.keymap.set('n', 'clean', function() remove_non_existing_item_from_history() end, opts)
end

----------------------------------------------------------------
-- add_item
----------------------------------------------------------------
local add_item = function(fname)
	-- oldfiles list is currently locked
	if vim.g.lock_file_history == 1 then return end

	-- Get the full path to the filename
	local path = vim.fn.fnamemodify(fname, ':p')
	if path == '' then return end

	-- Skip temporary buffers with buftype set.
	-- The buftype is set for buffers used by plugins.
	if vim.bo.buftype ~= '' then return end

	-- If file is readable, then skip
	if vim.fn.filereadable(path) == 0 then return end

	-- Load the latest history
	read_file_history()

	-- Remove the new file name from the existing list (if already present)
	for k,v in pairs(OldFiles) do
		if v == path then table.remove(OldFiles, k) end
	end

	-- Add the new file list to the beginning of the updated old file list
	table.insert(OldFiles, 1, path)

	-- Trim the list
	while #OldFiles > 50 do
		table.remove(OldFiles)
	end

	-- Save the updated oldfiles list
	write_file_history()
end

----------------------------------------------------------------
-- open_history
----------------------------------------------------------------
local function open_history()
	if vim.bo.buftype == 'quickfix' then
		warn_msg("Cannot executed with quickfix window")
		return
	end

	-- Already in the window, jump to it
	if self.winid ~= nil and vim.fn.win_id2win(self.winid) > 0 then
		vim.cmd(vim.fn.win_id2win(self.winid).."wincmd w")
		return
	end

	read_file_history()

	if #OldFiles == 0 then
		warn_msg("file history is empty")
		return
	end

	open_window()
end

----------------------------------------------------------------
-- setup_commands
----------------------------------------------------------------
local function setup_commands()
	local command = vim.api.nvim_create_user_command
	command("FileHistory", open_history, { nargs = 0 })
end

----------------------------------------------------------------
-- setup_file_history
----------------------------------------------------------------
local function setup_file_history()
     if vim.fn.has('unix') == 1 or vim.fn.has('macunix') == 1 then
		 HISTORY_FILE = vim.env.HOME.."/.file_history"
	else
		if vim.fn.has('win32') == 1 and vim.env.USERPROFILE ~= nil and vim.env.USERPROFILE ~= '' then
			HISTORY_FILE = vim.env.USERPROFILE..[[\_file_history]]
		else
			HISTORY_FILE = vim.env.VIM.."/_file_history"
		end
	end
end

----------------------------------------------------------------
-- setup_autocommands
----------------------------------------------------------------
local function setup_autocommands()
	AUGROUP = "FileHistory"
	vim.api.nvim_create_augroup(AUGROUP, { clear = true })

	vim.api.nvim_create_autocmd("BufReadPost", {
		pattern = {'*'},
		group = AUGROUP,
		callback = function()
			add_item(vim.fn.expand('<afile>'))
		end,
	})

	vim.api.nvim_create_autocmd("BufNewFile", {
		pattern = {'*'},
		group = AUGROUP,
		callback = function()
			add_item(vim.fn.expand('<afile>'))
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = {'*'},
		group = AUGROUP,
		callback = function()
			add_item(vim.fn.expand('<afile>'))
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = {'*vimgrep*'},
		group = AUGROUP,
		callback = function() lock(1) end
	})

	vim.api.nvim_create_autocmd("QuickFixCmdPost", {
		pattern = {'*vimgrep*'},
		group = AUGROUP,
		callback = function() lock(0) end
	})
end

----------------------------------------------------------------
-- setup
----------------------------------------------------------------
function M.setup()
	setup_autocommands()
	setup_commands()
	setup_file_history()
	vim.g.lock_file_history = 0
end

return M
