local MAJOR, MINOR = 'WagoLib-0.1', 1
local WagoLib = LibStub:NewLibrary(MAJOR, MINOR)
if not WagoLib then return end

local STRING_VERSION = 1
local STRING_PREFIX = 'Wago.io;'

local LibSerialize = LibStub('LibSerialize-mod')
local LibDeflate = LibStub('LibDeflate-mod')
WagoLib.EventListener = WagoLib.EventListener or CreateFrame("Frame")
WagoLib.instances = WagoLib.instances or {}
WagoLib.shipping = WagoLib.shipping or {}
local WagoAPI = {}

function WagoLib:Setup(name)
  if not name then
    return error('WagoLib: Must setup with a name name.')
  elseif type(name) ~= 'string' then
    return error('WagoLib: Name arg must be a string.')
  end

  local wagoInstance = {}
  wagoInstance.name = name
  for k, v in pairs(WagoAPI) do
		wagoInstance[k] = v
  end
  WagoLib.instances = WagoLib.instances or {}
  WagoLib.instances[name] = wagoInstance

  return wagoInstance
end

local function setupQueue(shippingID, channel, target)
  if channel ~= "WHISPER" then
    target = nil
  end
  local queue = {q={}, requested={}, shippingID=shippingID, active=false}
  function queue:add(prio, prefix, text, channel, target)
    if prio=='BULK' then
      tinsert(self.q, {prefix=prefix, text=text, prio=prio, channel=channel, target=target})
    else
      tinsert(self.q, 1, {prefix=prefix,text=text, prio=prio, channel=channel, target=target})
    end
    if not self.active then
      self.active = true
      self:send()
    end
  end
  
  local function tSize(tbl)
    if not tbl or type(tbl) ~= 'table' then return 0 end
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
  end

  function queue:send(_self)
    if not self then self = _self end
    local q = tremove(self.q, 1)
    if not q and self.sentPart then
      -- check requests for anything else to queue up before stopping
      for i=self.sentPart+1, WagoLib.shipping[shippingID].totalParts do
        if tSize(self.requested[i]) > 0 then
          self.sentPart = i
          q = {
            prefix = 'Wago' .. shippingID,
            text = 'DATA:' .. i .. ':' .. WagoLib.shipping[shippingID].parts[i],
            prio = 'BULK'
          }
          self.requested[i] = nil
          break
        end
      end
    end
    -- if still no requests then try at the start of the table
    if not q and self.sentPart then
      for i=1, self.sentPart do
        if tSize(self.requested[i]) > 0 then
          self.sentPart = i
          q = {
            prefix = 'Wago' .. shippingID,
            text = 'DATA:' .. i .. ':' .. WagoLib.shipping[shippingID].parts[i],
            prio = 'BULK'
          }
          self.requested[i] = nil
          break
        end
      end
    end
    -- if nothing to send to deactivate queue
    if not q then
      self.active = false
      return
    end

    if q.channel then
      ChatThrottleLib:SendAddonMessage(q.prio, q.prefix, q.text, q.channel, q.target, nil, self.send, self)
    else
      local channel, target
      for channel in pairs(WagoLib.shipping[shippingID].channels) do
        if not channel:match('^%u+$') then
          target = channel
          channel = 'WHISPER'
        else
          target = nil
        end
        ChatThrottleLib:SendAddonMessage(q.prio, q.prefix, q.text, channel, target, nil, self.send, self)
      end
    end
  end
  
  return queue
end


--------------------------------------------------------------------------------
-- base 85 https://github.com/aiq/basexx/blob/master/lib/basexx.lua

local function ignore_set( str, set )
  if set then
     str = str:gsub( '['..set..']', '' )
  end
  return str
end

local function pure_from_bit( str )
  return ( str:gsub( '........', function ( cc )
              return string.char( tonumber( cc, 2 ) )
           end ) )
end

local function unexpected_char_error( str, pos )
  local c = string.sub( str, pos, pos )
  return string.format( 'unexpected character at position %d: '%s'', pos, c )
end

local bitMap = { o = '0', i = '1', l = '1' }

local function from_bit( str, ignore )
  str = ignore_set( str, ignore )
  str = string.lower( str )
  str = str:gsub( '[ilo]', function( c ) return bitMap[ c ] end )
  local pos = string.find( str, '[^01]' )
  if pos then return nil, unexpected_char_error( str, pos ) end

  return pure_from_bit( str )
end

local function to_bit( str )
  return ( str:gsub( '.', function ( c )
    local byte = string.byte( c )
    local bits = {}
    for _ = 1,8 do
        table.insert( bits, byte % 2 )
        byte = math.floor( byte / 2 )
    end
    return table.concat( bits ):reverse()
  end ) )
end

local z85Decoder = { 0x00, 0x44, 0x00, 0x54, 0x53, 0x52, 0x48, 0x00,
                    0x4B, 0x4C, 0x46, 0x41, 0x00, 0x3F, 0x3E, 0x45, 
                    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 
                    0x08, 0x09, 0x40, 0x00, 0x49, 0x42, 0x4A, 0x47, 
                    0x51, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 
                    0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x32, 
                    0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 
                    0x3B, 0x3C, 0x3D, 0x4D, 0x00, 0x4E, 0x43, 0x00, 
                    0x00, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 
                    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 
                    0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20, 
                    0x21, 0x22, 0x23, 0x4F, 0x00, 0x50, 0x00, 0x00 }

local function decodeB85( str, ignore )
  str = ignore_set( str, ignore )
  if ( #str % 5 ) ~= 0 then
    return nil, 'String length must be a multiple of 5.'
  end

  local result = {}

  local value = 0
  for i = 1, #str do
    local index = string.byte( str, i ) - 31
    if index < 1 or index >= #z85Decoder then
      return nil, unexpected_char_error( str, i )
    end
    value = ( value * 85 ) + z85Decoder[ index ]
    if ( i % 5 ) == 0 then
      local divisor = 256 * 256 * 256
      while divisor ~= 0 do
        local b = math.floor( value / divisor ) % 256
        table.insert( result, string.char( b ) )
        divisor = math.floor( divisor / 256 )
      end
      value = 0
    end
    
    if #str > 10000 and i % 10000 == 0 then
      coroutine.yield(nil, i/#str)
    end
  end

  return table.concat( result )
end

local z85Encoder = '0123456789'..
                  'abcdefghijklmnopqrstuvwxyz'..
                  'ABCDEFGHIJKLMNOPQRSTUVWXYZ'..
                  '.-:+=^!/*?&<>()[]{}@%$#'

local function encodeB85( str )
  if #str % 4 > 0 then
    -- string length must be divisible by 4 so append whitespace if necessary
    str = str .. strrep(' ', 4 - (#str % 4))
  end

  local result = {}

  local value = 0
  for i = 1, #str do
    local b = string.byte( str, i )
    value = ( value * 256 ) + b
    if ( i % 4 ) == 0 then
      local divisor = 85 * 85 * 85 * 85
      while divisor ~= 0 do
        local index = ( math.floor( value / divisor ) % 85 ) + 1
        table.insert( result, z85Encoder:sub( index, index ) )
        divisor = math.floor( divisor / 85 )
      end
      value = 0
    end
    if #str > 10000 and i % 10000 == 0 then
      coroutine.yield(nil, i/#str)
    end
  end

  return table.concat( result )
end

--------------------------------------------------------------------------------
-- Frame tools

local function MakeFrame(name, type, importFn)
  if type ~= 'Import' and type ~= 'Export' and type ~= 'Receiving' then 
    type = 'Text'
  end

  if WagoLib.instances['WagoLibFrame' .. name .. type] then return WagoLib.instances['WagoLibFrame' .. name .. type] end
  local f = CreateFrame('Frame', 'WagoLibFrame' .. name .. type, UIParent, 'DialogBoxFrame')

  f:Hide()
  f:SetPoint('CENTER')
  if type == 'Receiving' then
    f:SetSize(450, 120)
  else
    f:SetSize(450, 220)
  end

	f:SetBackdrop({
		bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
		edgeFile = 'Interface\\PVPFrame\\UI-Character-PVP-Highlight',
		edgeSize = 16,
		insets = { left = 8, right = 6, top = 8, bottom = 8 },
	})
	f:SetBackdropBorderColor(.44, .44, .11, 0.5)

	-- Movable
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:SetScript('OnMouseDown', function(frame, button)
		if button == 'LeftButton' then
			frame:StartMoving()
		end
	end)
	f:SetScript('OnMouseUp', f.StopMovingOrSizing)

	-- TitleFrame
  local title = f:CreateFontString(nil, 'ARTWORK')
  title:SetPoint('LEFT', 16, 0)
  title:SetPoint('TOP', 0, -16)
  title:SetTextColor(.84, .215, .239, 1)
	title:SetFontObject(GameFontHighlightLarge)
	title:SetText("Export" .. name)

  -- EditBox
  local contentBox
  if type == 'Receiving' then
    contentBox = f:CreateFontString(nil, 'ARTWORK')
    contentBox:SetPoint('LEFT', 16, 0)
    contentBox:SetPoint('TOP', 0, -40)
    contentBox:SetTextColor(1, 1, 1, 1)
    contentBox:SetFontObject(ChatFontNormal)
    contentBox:SetJustifyH("LEFT")
    
    f.closeButton = _G['WagoLibFrame' .. name .. type .. 'Button']
    f.closeButton:SetNormalFontObject(ChatFontNormal)
    f.closeButton:SetHighlightFontObject(ChatFontNormal)
    f.closeButton:SetDisabledFontObject(ChatFontNormal)
    f.closeButton:SetText('Cancel')
    f.closeButton:SetSize(80, 24)
    f.closeButton:SetPoint('BOTTOMRIGHT', -16, 16)

    f.importButton = CreateFrame('Button', 'WagoLibFrame' .. name .. type .. 'ImportButton', f, 'UIPanelButtonTemplate')
    f.importButton:SetPoint('BOTTOMLEFT', 16, 16)
    f.importButton:SetNormalFontObject(ChatFontNormal)
    f.importButton:SetHighlightFontObject(ChatFontNormal)
    f.importButton:SetDisabledFontObject(ChatFontNormal)
    f.importButton:SetText('Import')
    f.importButton:SetSize(80, 24)
    f.importButton:Hide()
  else -- Import and Export
    local scroller = CreateFrame('ScrollFrame', nil, f, 'UIPanelScrollFrameTemplate')
    scroller:SetPoint('LEFT', 16, 0)
    scroller:SetPoint('RIGHT', -32, 0)
    scroller:SetPoint('TOP', 0, -40)
    scroller:SetPoint('BOTTOM', f, 'BOTTOM', 0, 50)

    contentBox = CreateFrame('EditBox', nil, scroller)
    contentBox:SetSize(scroller:GetSize())
    contentBox:SetMultiLine(true)
    contentBox:SetMaxBytes(nil)
    contentBox:SetFontObject(ChatFontNormal)
    contentBox:SetScript('OnEscapePressed', function() f:Hide(); end)
    scroller:SetScrollChild(contentBox)
    
    f.closeButton = _G['WagoLibFrame' .. name .. type .. 'Button']
    f.closeButton:SetNormalFontObject(ChatFontNormal)
    f.closeButton:SetHighlightFontObject(ChatFontNormal)
    f.closeButton:SetDisabledFontObject(ChatFontNormal)
    f.closeButton:SetText('Close')
    f.closeButton:SetSize(80, 24)
  end

  f.SetTitle = function(self, text)
    title:SetText(text)
  end

  f.SetText = function(self, text)
    contentBox:SetText(text)
    if type == 'Export' then
      contentBox:HighlightText() 
      contentBox:SetScript('OnChar', function()
        contentBox:SetText(text)
        contentBox:HighlightText() 
      end)
      contentBox:SetScript('OnMouseUp', function()
        contentBox:SetText(text)
        contentBox:HighlightText() 
      end)
    end
  end

  if type == 'Import' and importFn then
    local textBuffer, i, lastPaste = {}, 0, 0
    local function processBuffer(self)
      f:SetScript('OnUpdate', nil)
      local pasted = strtrim(table.concat(textBuffer))
      contentBox:ClearFocus()
      if pasted:match('^Wago%.io;(.+)%.%d+$') then
        contentBox:SetText(strsub(pasted, 1, 2500))
        local tbl = WagoAPI:StringToData(pasted, function(strError, tblData, tblMetadata)
          if strError then
            return importFn(strError)
          else
            return importFn(nil, tblData, tblMetadata)
          end
        end)
      else
        contentBox:SetText('Error: Invalid import string.')
        contentBox:HighlightText() 
      end
    end
    contentBox:SetScript('OnChar', function(self, c)
      if lastPaste ~= GetTime() then
        textBuffer, i, lastPaste = {}, 0, GetTime()
        f:SetScript('OnUpdate', processBuffer)
      end
      i = i + 1
      textBuffer[i] = c
    end)
  end

  WagoLib.instances['WagoLibFrame' .. name .. type] = f
  return WagoLib.instances['WagoLibFrame' .. name .. type]
end

function WagoAPI:CreateExportFrame()
  return MakeFrame(self.name, 'Export')
end
function WagoAPI:CreateImportFrame(onPaste)
  return MakeFrame(self.name, 'Import', onPaste)
end

-- meta data should be a flat table
local function filter_metadata(meta) 
  if type(meta) ~= 'table' then return nil end
  local len = 0
  for k, v in pairs(meta) do
    if type(v) ~= 'number' and type(v) ~= 'string' then
      len = len + #k + #tostring(v)
      meta[k] = nil
    end
  end
  if len > 4096 then
    error("WagoLib: Metadata must be less than 4KB.")
  end
  return meta
end

-- API
function WagoAPI:DataToString(data, metadata, onComplete)
  if type(metadata) == 'table' then
    metadata = filter_metadata(metadata)
  elseif type(metadata) == 'function' then
    onComplete = metadata
    metadata = nil
  else
    metadata = nil
  end
  if type(onComplete) ~= 'function' then
    error('WagoLib: onComplete must be a function. Expected use WagoLib.DataToString(data [, metadata], onComplete)')
  end
  local tocversion = select(4, GetBuildInfo())
  local tbl = {addon=self.name, tocversion=tocversion, metadata=metadata, data=data}
  local processing = CreateFrame('Frame')
  -- setup serialize
  local thread = coroutine.create(LibSerialize.SerializeEx)
  processing:SetScript('OnUpdate', function()
    if coroutine.status(thread) ~= 'dead' then
      -- process serialize
      local success_serial, serialized = coroutine.resume(thread, LibSerialize, {async=true}, tbl)
      if not success_serial then
        return onComplete("Failed serializing process")
      elseif serialized then
        -- setup compression
        thread = coroutine.create(LibDeflate.CompressDeflate)
        processing:SetScript('OnUpdate', function()
          if coroutine.status(thread) ~= 'dead' then
            -- process compression
            local success_deflate, compressed = coroutine.resume(thread, LibDeflate, serialized, {async=true, level=9})
            if not success_deflate then
              return onComplete("Failed compression process")
            elseif compressed then
              -- setup encoding
              thread = coroutine.create(encodeB85)
              processing:SetScript('OnUpdate', function()
                if coroutine.status(thread) ~= 'dead' then
                  -- process encoding
                  local success_encode, encoded, progress = coroutine.resume(thread, compressed)
                  if not success_encode then
                    onComplete("Failed encoding process")
                  elseif encoded then
                    processing:SetScript('OnUpdate', nil)
                    encoded = STRING_PREFIX .. encoded .. '.' .. STRING_VERSION
                    if onComplete then
                      return onComplete(nil, encoded)
                    end
                  end
                end
              end)
            end
          end
        end)
      end
    end
  end)
end

function StringHash(text)
  local counter = 1
  local len = string.len(text)
  for i = 1, len, 3 do 
    counter = math.fmod(counter*8161, 4294967279) +  -- 2^32 - 17: Prime!
  	  (string.byte(text,i)*16776193) +
  	  ((string.byte(text,i+1) or (len-i+256))*8372226) +
  	  ((string.byte(text,i+2) or (len-i+256))*3932164)
  end
  local n = math.fmod(counter, 4294967291) -- 2^32 - 5: Prime (and different from the prime in the loop)
  -- always return a 10digit num
  while n <= 999999999 do
    n = n * 10
  end
  while n > 9999999999 do
    n = math.floor(n / 10)
  end
  return n
end

function WagoAPI:SetOnChatLinkImport(onImport)
  if type(onImport) == 'function' then
    self.onChatLinkImport = onImport
  else
    error("onImport must be a function.")
  end
end

function WagoAPI:CreateChatLink(label, data, metadata)
  if not self.onChatLinkImport then
    return error("Must call SetOnChatLinkImport before creating a link.")
  end

  local editbox = GetCurrentKeyBoardFocus()
  if not editbox then return end

  local processing = CreateFrame('Frame')  
  local thread = coroutine.create(LibSerialize.SerializeEx)
  local name = self.name
  processing:SetScript('OnUpdate', function()
    if coroutine.status(thread) ~= 'dead' then
      local success_serial, serialized = coroutine.resume(thread, LibSerialize, {async=true}, data)
      if success_serial and serialized then
        processing:SetScript('OnUpdate', nil)
        local id = tostring(StringHash(serialized))
        WagoLib.shipping[id] = {
          data = data,
          metadata = metadata,
          label = label,
          name = name,
          expires = GetTime() + 120,
          channels = {},
          parts = {},
          seeds = {},
          completedParts = 0
        }

        local prefix = 'Wago' .. id
        if not C_ChatInfo.RegisterAddonMessagePrefix(prefix) then
          -- unlikely to ever happen
          print('|FFFF0000ERROR:|r Listening to too many addon channels.')
          return
        end
        editbox:Insert('[' .. name .. ': ' .. label .. ' (' .. id .. ')]')
      end
    end
  end)
end

local function clearExpiredShipments()
  for k, v in pairs(WagoLib.shipping) do
    if not v.expires or v.expires <= GetTime() then
      WagoLib.shipping[k] = nil
    end
  end
end

local eventToChannel = {
  ['CHAT_MSG_GUILD'] = 'GUILD',
  ['CHAT_MSG_OFFICER'] = 'OFFICER',
  ['CHAT_MSG_PARTY'] = 'PARTY',
  ['CHAT_MSG_PARTY_LEADER'] = 'PARTY',
  ['CHAT_MSG_RAID'] = 'RAID',
  ['CHAT_MSG_RAID_LEADER'] = 'RAID',
  ['CHAT_MSG_INSTANCE_CHAT'] = 'INSTANCE_CHAT',
  ['CHAT_MSG_INSTANCE_CHAT_LEADER'] = 'INSTANCE_CHAT',
  ['CHAT_MSG_WHISPER'] = 'WHISPER',
  ['CHAT_MSG_WHISPER_INFORM'] = 'WHISPER'
}

local function textToLink(shippingID, name, label, channel)
  return '|Hgarrmission:wagolib:' .. channel .. ':' .. shippingID .. '|h|cFFD6373D['..name..': |r|cFFD6AC3C'..label..'|r|cFFD6373D]|r|h'
end

local function ChatFrameFilter(_, event, msg, player, l, cs, t, flag, channelId, ...)
  if flag == 'GM' or flag == 'DEV' then
    return false, newMsg, player, l, cs, t, flag, channelId, ...
  end
  clearExpiredShipments()

  local newMsg = ''
  local shippingID
  local _, _, before, name, label, id, after = msg:find('(.*)%[(.+): (.+) %((%d%d%d%d%d%d%d%d%d%d)%)%](.*)')
  if id and WagoLib.instances[name] then
    local channel = eventToChannel[event]

    shippingID = id
    newMsg = newMsg .. before
    newMsg = newMsg .. textToLink(shippingID, name, label, channel)
    newMsg = newMsg .. after
    if event == 'CHAT_MSG_BN_WHISPER_INFORM' or event == 'CHAT_MSG_BN_WHISPER' then
      return false, newMsg, player, l, cs, t, flag, channelId, ...
    end

    WagoLib.shipping[shippingID] = WagoLib.shipping[shippingID] or {
      label = label,
      name = name,
      channels = {},
      completedParts = 0,
      parts = {},
      seeds = {}
    }
    WagoLib.shipping[shippingID].expires = GetTime() + 15 * 60
    if channel == "WHISPER" then
      WagoLib.shipping[shippingID].channels[player] = 1
    else
      WagoLib.shipping[shippingID].channels[channel] = 1
    end

    if WagoLib.shipping[shippingID].data and not WagoLib.shipping[shippingID].inProgress then
      -- setup data
      WagoLib.shipping[shippingID].inProgress = true
      WagoLib.instances[name]:DataToString(WagoLib.shipping[shippingID].data, WagoLib.shipping[shippingID].metadata, function(strError, strEncoded)
        if strError then
          print('|FFFF0000ERROR:|r ' .. strError)
          return
        end
        WagoLib.shipping[shippingID].parts = {}
        local n = 1
        local i = 1
        while n < strlen(strEncoded) do
          WagoLib.shipping[shippingID].parts[i] = strsub(strEncoded, n, n + 245)
          i = i + 1
          n = n + 246
        end
        WagoLib.shipping[shippingID].completedParts = #WagoLib.shipping[shippingID].parts
        WagoLib.shipping[shippingID].totalParts = WagoLib.shipping[shippingID].completedParts
        WagoLib.shipping[shippingID].data = nil
        WagoLib.shipping[shippingID].metadata = nil
        WagoLib.shipping[shippingID].inProgress = nil
        tinsert(WagoLib.shipping[shippingID].seeds, UnitName('player') .. '-' .. GetRealmName())
      end)
    end

    WagoLib.shipping[shippingID].messaging = WagoLib.shipping[shippingID].messaging or setupQueue(shippingID)
    if channel ~= "WHISPER" then
      player = nil
    end
    return false, newMsg, player, l, cs, t, flag, channelId, ...
  end
end

ChatFrame_AddMessageEventFilter('CHAT_MSG_GUILD', ChatFrameFilter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_OFFICER', ChatFrameFilter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_PARTY', ChatFrameFilter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_PARTY_LEADER', ChatFrameFilter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_RAID', ChatFrameFilter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_RAID_LEADER', ChatFrameFilter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_WHISPER', ChatFrameFilter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_WHISPER_INFORM', ChatFrameFilter)
-- ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", ChatFrameFilter)
-- ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", ChatFrameFilter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_INSTANCE_CHAT', ChatFrameFilter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_INSTANCE_CHAT_LEADER', ChatFrameFilter)

local function EventHandler(self, event, ...)
  if event == "CHAT_MSG_ADDON" then
    local prefix, text, channel, sender, sentto = ...
    local _, _, shippingID = prefix:find('^Wago(%d%d%d%d%d%d%d%d%d%d)$')
    if shippingID and WagoLib.shipping[shippingID] then      
      if channel == 'WHISPER' and not WagoLib.shipping[shippingID].channels[sender] then 
        return
      elseif channel ~= 'WHISPER' and not WagoLib.shipping[shippingID].channels[channel] then 
        return 
      end

      -- we have a valid WagoLib-receieved message
      local _, _, command, data = text:find("^([^:]+):?(.*)$")
      if command == 'INFO' and data == '' and #WagoLib.shipping[shippingID].parts > 0 and #WagoLib.shipping[shippingID].parts == WagoLib.shipping[shippingID].completedParts then -- if someone is requesting info on shipment and we have that data complete
        WagoLib.shipping[shippingID].messaging:add('ALERT', prefix, 'INFO:' .. #WagoLib.shipping[shippingID].parts)

      elseif command == 'INFO' and tonumber(data) > 0 then -- If receiving info on shipment
        -- Display progress
        local parts = tonumber(data)
        WagoLib.shipping[shippingID].totalParts = parts
        WagoLib.shipping[shippingID].Frame:SetText("Parts: 0 / " .. parts .. " - 0.00%")
        -- Setup import button
        WagoLib.shipping[shippingID].Frame.importButton:SetScript("OnClick", function()
          WagoLib.shipping[shippingID].recieving = true
          WagoLib.shipping[shippingID].Frame.importButton:SetScript("OnClick", nil)
          WagoLib.shipping[shippingID].Frame.importButton:SetText("Importing")
          WagoLib.shipping[shippingID].Frame.importButton:Disable()            
          WagoLib.shipping[shippingID].messaging:add('ALERT', prefix, 'REQUEST', channel, sender)
          
          -- Setup cancel button
          WagoLib.shipping[shippingID].Frame.closeButton:SetScript("OnClick", function()
            WagoLib.shipping[shippingID].messaging:add('ALERT', prefix, 'CANCEL', channel, sender)
            WagoLib.shipping[shippingID].parts = {}
            WagoLib.shipping[shippingID].Frame:Hide()
          end)
        end)

      elseif command == 'REQUEST' then
        -- set all parts as requested
        for k=1, WagoLib.shipping[shippingID].totalParts do
          WagoLib.shipping[shippingID].messaging.requested[k] = WagoLib.shipping[shippingID].messaging.requested[k] or {}
          WagoLib.shipping[shippingID].messaging.requested[k][sender] = 1
        end
        -- if we're currently sending then we don't need to do anything else right now
        if WagoLib.shipping[shippingID].messaging.active then return end

        -- sort list of current inactive seeds
        table.sort(WagoLib.shipping[shippingID].seeds)

        -- determine seed position and start sending parts
        local position = 1
        local size = math.floor(WagoLib.shipping[shippingID].completedParts / #WagoLib.shipping[shippingID].seeds)
        local me = UnitName('player') .. '-' .. GetRealmName()
        for k, v in ipairs(WagoLib.shipping[shippingID].seeds) do
          if v == me then position = size * (k-1) + 1 end
        end
        WagoLib.shipping[shippingID].messaging.sentPart = position
        WagoLib.shipping[shippingID].messaging:add('BULK', prefix, 'DATA:' .. position .. ':' .. WagoLib.shipping[shippingID].parts[position], channel, sender)
        WagoLib.shipping[shippingID].messaging.requested[position] = nil

      elseif command == 'DATA' then
        local _, _, partnum, str = data:find("^(%d+):(.*)$")
        if partnum and tonumber(partnum) > 0 and str then
          partnum = tonumber(partnum)
          -- remove sender from idle seeds
          for k, v in pairs(WagoLib.shipping[shippingID].seeds) do
            if sender == v then tremove(WagoLib.shipping[shippingID].seeds, k) end
          end

          -- remove part from requested table
          WagoLib.shipping[shippingID].messaging.requested[partnum] = nil

          -- if receiving is true and this is a new part, then add data to table
          if WagoLib.shipping[shippingID].recieving and not WagoLib.shipping[shippingID].parts[partnum] then
            WagoLib.shipping[shippingID].parts[partnum] = str

            -- update progress
            WagoLib.shipping[shippingID].completedParts = WagoLib.shipping[shippingID].completedParts + 1
            local pct = string.format('%.2f', 100 * WagoLib.shipping[shippingID].completedParts / WagoLib.shipping[shippingID].totalParts)
            WagoLib.shipping[shippingID].Frame:SetText('Parts: ' .. WagoLib.shipping[shippingID].completedParts .. ' / ' .. WagoLib.shipping[shippingID].totalParts .. ' - ' .. pct .. '%')
          end

          -- if progress is complete
          if WagoLib.shipping[shippingID].recieving and WagoLib.shipping[shippingID].completedParts == WagoLib.shipping[shippingID].totalParts then
            if WagoLib.instances[WagoLib.shipping[shippingID].name].onChatLinkImport then
              local tbl = WagoAPI:StringToData(table.concat(WagoLib.shipping[shippingID].parts), function(strError, tblData, tblMetadata)
                if strError then
                  print('|FFFF0000ERROR:|r ' .. strError)
                else
                  WagoLib.shipping[shippingID].messaging:add('BULK', prefix, 'FINISHED', channel, sender)
                  WagoLib.instances[WagoLib.shipping[shippingID].name].onChatLinkImport(nil, tblData, tblMetadata)
                  local f = MakeFrame(WagoLib.shipping[shippingID].name, 'Receiving')
                  f:Hide()
                end
              end)
            else
              error("Must set a function for onChatImport in WagoLib config.")
            end
          end
        end
      end
    end
  end
end
WagoLib.EventListener:RegisterEvent("CHAT_MSG_ADDON")
-- WagoLib.EventListener:RegisterEvent("BN_CHAT_MSG_ADDON")
WagoLib.EventListener:SetScript("OnEvent", EventHandler)

local function ChatLinkHook(link, text)
  local _, _, channel, shippingID = link:find('^garrmission:wagolib:([%a-]+):(%d%d%d%d%d%d%d%d%d%d)$')
  if not shippingID or not channel then return end
  if not WagoLib.shipping[shippingID] then return end
  if text ~= textToLink(shippingID, WagoLib.shipping[shippingID].name, WagoLib.shipping[shippingID].label, channel) then
    return
  end
  
  local prefix = 'Wago' .. shippingID
  if not WagoLib.shipping[shippingID].totalParts or #WagoLib.shipping[shippingID].parts ~= WagoLib.shipping[shippingID].completedParts then
    local receivingFrame = MakeFrame(WagoLib.shipping[shippingID].name, 'Receiving')
    receivingFrame:SetTitle(WagoLib.shipping[shippingID].name .. ': |cFFD6AC3C' .. WagoLib.shipping[shippingID].label .. '|r')
    if not C_ChatInfo.RegisterAddonMessagePrefix(prefix) then
      -- unlikely to ever happen
      receivingFrame:SetText('|FFFF0000ERROR:|r Listening to too many addon channels.')
      return
    end
    receivingFrame:SetText('Requesting data')
    receivingFrame:Show()
    WagoLib.shipping[shippingID].Frame = receivingFrame
    WagoLib.shipping[shippingID].messaging:add('NORMAL', prefix, 'INFO')

    local n = 0
    local handle
    local update = function()
      n = n + 1
      if n >= 15 and not WagoLib.shipping[shippingID].totalParts then
        receivingFrame:SetText('Data is not available.')
        receivingFrame.importButton:Hide()
      elseif not WagoLib.shipping[shippingID].totalParts and n % 2 == 0 then
        receivingFrame:SetText('Requesting data' .. ('.'):rep(math.floor(n/2)))
      elseif WagoLib.shipping[shippingID].totalParts then
        receivingFrame.importButton:Show()
        receivingFrame.importButton:SetText('Import')
        receivingFrame.importButton:Enable()    
        handle:Cancel()
      end
    end
    handle = C_Timer.NewTicker(0.1, update, 15)
  else
    local tbl = WagoAPI:StringToData(table.concat(WagoLib.shipping[shippingID].parts), function(strError, tblData, tblMetadata)
      if strError then
        print('|FFFF0000ERROR:|r ' .. strError)
      else
        WagoLib.shipping[shippingID].messaging:add('BULK', prefix, 'FINISHED', channel, sender)
        WagoLib.instances[WagoLib.shipping[shippingID].name].onChatLinkImport(nil, tblData, tblMetadata)
        local f = MakeFrame(WagoLib.shipping[shippingID].name, 'Receiving')
        f:Hide()
      end
    end)
  end
end
hooksecurefunc('SetItemRef', ChatLinkHook)


function WagoAPI:StringToData(strEncoded, onComplete)
  local _, _, encoded, stringVersion = strEncoded:find('^Wago%.io;(.+)%.(%d+)$')
  if not encoded or not stringVersion then print('|FFFF0000ERROR:|r Decoding error. Improper format.') return nil end
  stringVersion = tonumber(stringVersion)
  local encodeVersion, compressVersion, serializeVersion = 1, 1, 1
  -- if stringVersion >= 2 then
  -- end
  local processing = CreateFrame('Frame')
  -- setup decode
  local thread = coroutine.create(decodeB85)
  processing:SetScript('OnUpdate', function()
    if coroutine.status(thread) ~= 'dead' then
      -- process decode
      local success_decode, decoded, progress = coroutine.resume(thread, encoded)
      if success_decode and decoded then
        -- setup compression
        thread = coroutine.create(LibDeflate.DecompressDeflate)
        processing:SetScript('OnUpdate', function()
          if coroutine.status(thread) ~= 'dead' then
            -- process compression
            local success_deflate, decompressed = coroutine.resume(thread, LibDeflate, decoded, {async=true})
            if success_deflate and decompressed then
              -- process deserializing
              processing:SetScript('OnUpdate', nil)
              -- deserialize goes through a pcall which doesn't play nice with coroutines, so this last process is synchronous
              success_deserialized, tbl = LibSerialize:Deserialize(decompressed)
              if success_deserialized and tbl then
                onComplete(nil, tbl.data, tbl.metadata)
              else                
                -- onComplete('Failed deserializing process')
              end
            else
              -- onComplete('Failed deflating process')
            end
          end
        end)
      else
        -- onComplete('Failed decoding process')
      end
    elseif success_decode and progress then
      WagoLibFrame:Show({mode='PROGRESS', progress=(math.floor(progress*100000)/1000) .. '%', title='Import Progress'})
    end
  end)
end

function WagoAPI:ImportFrame(opt)
  WagoLibFrame:Show({mode='IMPORT', title='Import: ' .. (self.name or 'Paste here'), onPaste=opt.onPaste})
end

function WagoAPI:ExportFrame(opt)
  WagoLibFrame:SetText('0%')
  WagoLibFrame:Show({mode='IMPORT', title='Import: ' .. (self.name or 'Paste here'), onPaste=opt.onPaste, onProgress=function(p)
    WagoLibFrame:SetText((math.floor(p*100000)/1000) .. '%')
  end})
end
