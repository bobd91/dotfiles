return { 
	"catppuccin/nvim", 
	name = "catppuccin", 
	priority = 1000,
	opts = {
		flavour = "mocha",
		color_overrides = {
				mocha = {
					base = "#000000",
					mantle = "#000000",
					crust = "#000000",
				},
			},
		},
}

--[[
return {
    "tiagovla/tokyodark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        vim.cmd("colorscheme tokyodark")
    end,
}
]]--
