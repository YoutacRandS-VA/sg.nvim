local void = require("plenary.async").void

local shared = require "sg.components.shared"

local CodyPrompt = require "sg.components.cody_prompt"
local CodyHistory = require "sg.components.cody_history"
local Message = require "sg.cody.message"
local Speaker = require "sg.cody.speaker"
local State = require "sg.cody.state"

---@class CodyBaseLayoutOpts
---@field name string?
---@field state CodyState?
---@field prompt CodyPromptOpts?
---@field history CodyHistoryOpts

---@class CodyBaseLayout
---@field opts CodyBaseLayoutOpts
---@field state CodyState
---@field history CodyHistory
---@field prompt CodyPrompt?
---@field _active CodyBaseLayout?
---@field created boolean
local Base = {}
Base.__index = Base

--- Create a new base layout object
---@param opts CodyBaseLayoutOpts
---@return CodyBaseLayout
function Base.init(opts)
  return setmetatable({
    opts = opts,
    visible = false,
    state = opts.state or State.init {
      name = opts.name,
    },
  }, Base)
end

function Base:get_active()
  return self._active
end
function Base:set_active(obj)
  self._active = obj
end

function Base:run() end

function Base:request_completion()
  error "Base:request_completion() is an abstract function"
end

function Base:create()
  local active = self:get_active()
  if active then
    active:delete()
    self:set_active(nil)
  end

  self.history = CodyHistory.init(self.opts.history)
  if self.opts.prompt then
    -- Override prompt options
    -- TODO: Do the other options as well
    local prompt_opts = assert(vim.deepcopy(self.opts.prompt))
    prompt_opts.on_submit = function(bufnr, text, submit_opts)
      void(function()
        print("submitting...", text)
        if self.opts.prompt.on_submit then
          self.opts.prompt.on_submit(bufnr, text, submit_opts)
        end

        self:on_submit(bufnr, text, submit_opts)
      end)()
    end

    print "Creating prompt..."
    self.prompt = CodyPrompt.init(prompt_opts)
  end

  self.created = true
end

--- Something
---@param self CodyBaseLayout
function Base:show()
  if not self.created then
    self:create()
  end

  self:set_active(self.state)

  self.history:show()
  if self.prompt then
    self.prompt:show()
    vim.api.nvim_set_current_win(self.prompt.win)
  end

  self:set_keymaps()
  self:render()
end

function Base:render()
  self.state:render(self.history.bufnr, self.history.win)
end

function Base:hide()
  self.history:hide()
  if self.prompt then
    self.prompt:hide()
  end
end

function Base:delete()
  self.history:delete()
  if self.prompt then
    self.prompt:delete()
  end

  self.created = false
end

--- Callback for running on submit
function Base:on_submit(bufnr, text, submit_opts)
  self.state:append(Message.init(Speaker.user, text))
  self:request_completion()
end

function Base:set_keymaps() end

return Base