# rails-i18n.nvim

[![Neovim 0.8.0+](https://img.shields.io/badge/Neovim-0.8.0%2B-blueviolet.svg)](https://neovim.io)

A Neovim plugin that provides seamless navigation and management of Rails i18n translations. Quickly jump to translation definitions in your YAML files and create new translations on the fly.

## Features

- Jump to translation definitions directly from your code
- Automatic creation of missing translations
- Smart scope detection based on file location
- Support for multi-locale projects
- Seamless integration with Rails project structure

## Requirements

- Neovim >= 0.8.0
- Rails project with standard i18n structure

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
"annakuzmenkodev/rails-i18n.nvim"

```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use 'annakuzmenkodev/rails-i18n.nvim'
```

## Configuration

```lua
require('rails-i18n').setup({
    locales_path = "config/locales",  -- Path to your locale files
    default_locale = "en",            -- Default locale to use
    rails_roots = { "app", "config", "lib" }, -- Rails root directories
    default_value = "TODO"            -- Default value for new translations
})
```

## Usage

Position your cursor on a Rails translation key and use the `:I18nGoto` command to jump to its definition. If the translation doesn't exist, the plugin will offer to create it in the appropriate locale file.

### Example

```ruby
# In a view file
<%= t('.welcome') %>  # Will look for the translation under the current view's scope
```

### Commands

| Command     | Description                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------ |
| `:I18nGoto` | Jump to the translation definition under the cursor. Creates the translation if it doesn't exist |

## Author

Anna Kuzmenko
