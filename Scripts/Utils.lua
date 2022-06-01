local isDebugEnabled = false

function Log(message)
  if not isDebugEnabled then return end

  common.LogInfo(common.GetAddonName(), message)
  LogToChat(message)
end

function LogTable(table, level)
  if not isDebugEnabled then return end

  local indent = level or 1
  for k, v in pairs(table) do
    if (type(v) == "table") then
      Log(string.rep(" ", indent) .. tostring(k) .. " = {")
      LogTable(v, indent + 2)
      Log(string.rep(" ", indent) .. "}")
    else
      Log(string.rep(" ", indent) .. tostring(k) .. " = " .. tostring(v))
    end
  end
end
