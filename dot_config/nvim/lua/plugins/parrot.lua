return {
  "frankroeder/parrot.nvim",
  dependencies = { "ibhagwan/fzf-lua", "nvim-lua/plenary.nvim" },
  enabled = vim.env.DECAGON_ENV == nil, -- disable if DECAGON_ENV is set
  config = function()
    require("parrot").setup({
      providers = {
        anthropic = {
          name = "anthropic",
          api_key = os.getenv("ANTHROPIC_API_KEY"),
          endpoint = "https://api.anthropic.com/v1/messages",
          models = {
            "claude-sonnet-4-5",
            "claude-haiku-4-5",
          },
          headers = function(self)
            return {
              ["Content-Type"] = "application/json",
              ["x-api-key"] = self.api_key,
              ["anthropic-version"] = "2023-06-01",
            }
          end,
          preprocess_payload = function(payload)
            -- Anthropic requires system prompt at top level, not in messages
            local system_prompt = nil
            local messages = {}

            for _, message in ipairs(payload.messages) do
              if message.role == "system" then
                system_prompt = message.content
              else
                table.insert(messages, message)
              end
            end

            payload.messages = messages
            if system_prompt then
              payload.system = system_prompt
            end

            -- Ensure max_tokens is set (required by Anthropic)
            if not payload.max_tokens then
              payload.max_tokens = 8192
            end

            return payload
          end,
        },
      },
    })
  end,
}
