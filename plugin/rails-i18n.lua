if vim.g.loaded_rails_i18n then
	return
end
vim.g.loaded_rails_i18n = true

require("rails-i18n")
