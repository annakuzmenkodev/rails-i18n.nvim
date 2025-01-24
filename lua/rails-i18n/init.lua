local M = {}

-- Configuration
local config = {
	locales_path = "config/locales",
	default_locale = "en",
	rails_roots = { "app", "config", "lib" },
	default_value = "TODO",
}

-- Find Rails root directory
local function find_rails_root()
	local current_file = vim.api.nvim_buf_get_name(0)
	local path = current_file:match("(.*)/")
	if not path then
		return nil
	end

	while path ~= "" do
		for _, marker in ipairs(config.rails_roots) do
			if vim.fn.isdirectory(path .. "/" .. marker) == 1 then
				return path
			end
		end
		path = path:match("(.*)/")
	end
	return nil
end

-- Get current file's translation scope
local function get_current_scope()
	local file_path = vim.api.nvim_buf_get_name(0)
	local scope

	-- Handle views
	local views_prefix = "/app/views/"
	local view_index = file_path:find(views_prefix)
	if view_index then
		local rel_path = file_path:sub(view_index + #views_prefix)
		rel_path = rel_path:gsub("%..+$", "") -- Remove extensions
		rel_path = rel_path:gsub("/", ".") -- Convert path to dot notation
		scope = rel_path
	end

	return scope
end

-- Extract translation key under cursor
local function extract_translation_key()
	local line = vim.api.nvim_get_current_line()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)[2]

	local start_pos = 1
	while true do
		-- Find next t('...' or t("..." pattern
		local s, e, key = line:find([[t%(["'](.-)["']%)]], start_pos)
		if not s then
			break
		end

		-- Check if cursor is within this translation call
		if cursor_pos >= s - 1 and cursor_pos <= e - 1 then
			return key
		end

		start_pos = e + 1
	end

	return nil
end

-- Expand relative key to full path
local function expand_key(key, scope)
	if key:sub(1, 1) == "." then
		if not scope then
			return nil
		end
		return scope .. "." .. key:sub(2)
	end
	return key
end

-- Find key in YAML file
local function find_key_in_file(file, key)
	local key_parts = vim.split(key, ".", { plain = true })
	local current_indent = 0
	local current_level = 0
	local target_level = #key_parts - 1
	local locale = config.default_locale

	local fd = io.open(file, "r")
	if not fd then
		return false
	end

	local line_num = 0
	for line in fd:lines() do
		line_num = line_num + 1
		local indent = #line:match("^ *") or 0
		local content = line:match("^%s*([^:]+):") or ""

		if indent == 0 and content == locale then
			current_level = 1
			current_indent = 2
		elseif current_level > 0 then
			if indent == current_indent then
				local part = key_parts[current_level]
				if content == part then
					if current_level == #key_parts then
						fd:close()
						return true, line_num
					end
					current_level = current_level + 1
					current_indent = current_indent + 2
				end
			end
		end
	end

	fd:close()
	return false
end

-- Main function
function M.goto_translation()
	local key = extract_translation_key()
	if not key then
		print("No translation key found under cursor")
		return
	end

	local scope = get_current_scope()
	local full_key = expand_key(key, scope)
	if not full_key then
		print("Could not expand key")
		return
	end

	local rails_root = find_rails_root()
	if not rails_root then
		print("Not in a Rails project")
		return
	end

	local locale_dir = rails_root .. "/" .. config.locales_path
	local locale_files = vim.split(vim.fn.glob(locale_dir .. "/*.yml"), "\n")

	for _, file in ipairs(locale_files) do
		local found, line_num = find_key_in_file(file, full_key)
		if found then
			vim.cmd("edit " .. file)
			vim.api.nvim_win_set_cursor(0, { line_num, 0 })
			return
		end
	end

	-- Key not found; proceed to create in English locale
	local english_files = {}
	for _, file in ipairs(locale_files) do
		local filename = vim.fn.fnamemodify(file, ":t")
		-- Match either "en.yml" or "*.en.yml" pattern
		if
			filename:match("^" .. config.default_locale .. "%.yml$")
			or filename:match("%." .. config.default_locale .. "%.yml$")
		then
			table.insert(english_files, file)
		end
	end

	local selected_file
	if #english_files > 0 then
		local choices = {}
		for i, file in ipairs(english_files) do
			table.insert(choices, string.format("%d. %s", i, vim.fn.fnamemodify(file, ":t")))
		end
		table.insert(choices, "Cancel")
		local choice = vim.fn.inputlist(choices)
		if choice < 1 or choice > #english_files then
			print("Creation cancelled.")
			return
		end
		selected_file = english_files[choice]
	else
		selected_file = locale_dir .. "/" .. config.default_locale .. ".yml"
		local fd = io.open(selected_file, "r")
		if not fd then
			fd = io.open(selected_file, "w")
			if fd then
				fd:write(config.default_locale .. ":\n")
				fd:close()
			else
				print("Failed to create new locale file: " .. selected_file)
				return
			end
		else
			fd:close()
		end
	end

	-- Insert key into selected file
	local parts = vim.split(full_key, ".", { plain = true })
	local lines = {}
	local fd = io.open(selected_file, "r")
	if fd then
		for line in fd:lines() do
			table.insert(lines, line)
		end
		fd:close()
	else
		print("Failed to read locale file: " .. selected_file)
		return
	end

	-- Find or add default locale line
	local en_line = nil
	for i, line in ipairs(lines) do
		if line:match("^" .. config.default_locale .. ":") then
			en_line = i
			break
		end
	end
	if not en_line then
		table.insert(lines, config.default_locale .. ":")
		en_line = #lines
	end

	-- Parse line to get key and indentation level
	local function parse_line(line)
		local indent = #line:match("^ *") or 0
		local content = line:match("^%s*([^:]+):")
		return content, indent
	end

	-- Find insertion point for a key at given indent level
	local function find_insertion_point(lines, start_line, end_line, key, indent_level)
		for i = start_line, end_line do
			local line = lines[i]
			local content, indent = parse_line(line)
			if indent == indent_level and content and content > key then
				return i
			end
		end
		return end_line + 1
	end

	-- Find matching parent key
	local function find_matching_parent(lines, start_line, end_line, key, indent_level)
		for i = start_line, end_line do
			local line = lines[i]
			local content, indent = parse_line(line)
			if content == key and indent == indent_level then
				return i
			end
		end
		return nil
	end

	-- Insert key maintaining structure
	local current_line = en_line
	local current_indent = 2
	local parent_line = en_line

	for i, part in ipairs(parts) do
		local is_last = (i == #parts)
		local matching_line = find_matching_parent(lines, current_line + 1, #lines, part, current_indent)

		if matching_line then
			-- Key part exists, continue with next part
			parent_line = matching_line
			current_line = matching_line
			current_indent = current_indent + 2
		else
			-- Find where to insert the new key
			local insert_pos = find_insertion_point(lines, parent_line + 1, #lines, part, current_indent)
			local indent = string.rep(" ", current_indent)
			local new_line

			if is_last then
				new_line = indent .. part .. ": " .. config.default_value
			else
				new_line = indent .. part .. ":"
			end

			table.insert(lines, insert_pos, new_line)
			parent_line = insert_pos
			current_line = insert_pos
			current_indent = current_indent + 2
		end
	end

	-- Write to file
	fd = io.open(selected_file, "w")
	if fd then
		for _, line in ipairs(lines) do
			fd:write(line .. "\n")
		end
		fd:close()
	else
		print("Failed to write to locale file: " .. selected_file)
		return
	end

	-- Open file and navigate to new key
	vim.cmd("edit " .. selected_file)
	vim.api.nvim_win_set_cursor(0, { current_line, 0 })
end

-- Setup command
vim.api.nvim_create_user_command("I18nGoto", M.goto_translation, {})

return M
