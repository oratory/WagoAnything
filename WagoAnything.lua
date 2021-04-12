local _, WagoAnything = ...

local WagoLib = LibStub("WagoLib-0.1"):Setup("WagoAnything", {})
AWago = WagoLib
local dataTables = {}
local tinsert, tsort = table.insert, table.sort
local MAX_ROWS, ROW_HEIGHT, TABLE_WIDTH, TEXTAREA_WIDTH = 14, 20, 250-16, 450-16

local function isBlocked(str)
  -- for i,b in pairs(blocked) do
  --   if string.find(str, b) then return true end
  -- end
  return false
end

function isValidTable(tbl, depth)
  if not depth then depth = 0 end
  if depth > 10 then return true end
  local empty = true
  for k, v in pairs(tbl) do
    empty = false
    if type(v) == 'function' or type(v) == 'userdata' or (type(v) == 'table' and not isValidTable(v, depth+1)) then return false end
  end
  if depth == 0 and empty then return false end
  return true
end

local ImportingTable
local function GetDataTables(refresh)
  local search = ''
  -- check if search field is set up yet
  if WagoAnything and WagoAnything.MainFrame then
    search = WagoAnything.MainFrame.search:GetText()
  end
  if #dataTables == 0 or refresh then
    dataTables = {}
    for k, v in pairs(_G) do
      if type(v) == 'table' and not isBlocked(k) and isValidTable(v) then
        tinsert(dataTables, k)
      end
    end
  end
  tsort(dataTables)
  if ImportingTable then
    table.insert(dataTables, 1, '|cFFDCCD79' .. ImportingTable.name .. '|r')
  end
  if search ~= '' then
    local filteredTables = {}
    for k, v in ipairs(dataTables) do
      if v:lower():find(search:lower()) then
        tinsert(filteredTables, v)
      end
    end
    return filteredTables
  end
  return dataTables
end

local function updateScroller()
  local tableScroller = WagoAnything.MainFrame.tableScroller
  local tables = GetDataTables()
  local numTables = #tables
  FauxScrollFrame_Update(tableScroller, numTables, MAX_ROWS, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(tableScroller)
  tableScroller:Show()
  for i = 1, MAX_ROWS do
    local t = tables[i + offset]
    local row = tableScroller.rows[i]
    if t then
      if WagoAnything.selectedTable and WagoAnything.selectedTable == i + offset then
        row.label:SetText('|cFFD6373D' .. t .. '|r')
      else
        row.label:SetText(t)
      end
      row:Show()
    else
      row:Hide()
    end
  end
  tableScroller:SetWidth(TABLE_WIDTH)
end

function WagoAnything:CreateFrame()
  if WagoAnything.MainFrame then return WagoAnything.MainFrame end

  local f = CreateFrame('Frame', 'WagoAnythingFrame', UIParent, 'DialogBoxFrame')
  f:Hide()
  f:SetPoint('CENTER')
  f:SetSize(700, 392)

  f:SetBackdrop({
    bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
    edgeFile = 'Interface\\PVPFrame\\UI-Character-PVP-Highlight',
		edgeSize = 16,
    insets = { left = 8, right = 6, top = 8, bottom = 8 },
  })
  f:SetBackdropBorderColor(.44, .44, .11, 0.5)

  -- Make it movable
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:SetScript('OnMouseDown', function(frame, button)
    if button == 'LeftButton' then
      frame:StartMoving()
    end
  end)
  f:SetScript('OnMouseUp', f.StopMovingOrSizing)

  local title = f:CreateFontString(nil, 'ARTWORK')
  title:SetPoint('TOPLEFT', 16, -16)
  title:SetTextColor(.84, .215, .239, 1)
  title:SetFontObject(GameFontHighlightLarge)
  title:SetText('Wago Anything')

  local closeButton = _G['WagoAnythingFrameButton']
  closeButton:ClearAllPoints()
  closeButton:SetPoint('LEFT', f, 'TOPRIGHT', -36, -24)
  closeButton:SetNormalFontObject(ChatFontNormal)
  closeButton:SetHighlightFontObject(ChatFontNormal)
  closeButton:SetDisabledFontObject(ChatFontNormal)
  closeButton:SetText('x')
  closeButton:SetSize(24, 24)

  local searchText = f:CreateFontString(nil, 'BORDER', f)
  searchText:ClearAllPoints()
  searchText:SetPoint('LEFT', title, 'RIGHT', 24, 0)
  searchText:SetTextColor(.6, .6, .6, 1)
  searchText:SetFontObject(ChatFontNormal)
  searchText:SetText('Search')
  f.searchPlaceholder = searchText
  
  local searchBackground = CreateFrame('Frame', 'ARTWORK', f, 'BackdropTemplate')
  searchBackground:ClearAllPoints()
  searchBackground:SetPoint('LEFT', title, 'RIGHT', 16, 0)
  searchBackground:SetSize(128, 24)
  searchBackground:SetBackdrop({
    bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
    edgeFile = 'Interface\\PVPFrame\\UI-Character-PVP-Highlight',
		edgeSize = 10,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  searchBackground:SetBackdropBorderColor(.44, .44, .11, 0.5)

  local searchBox = CreateFrame('EditBox', nil, f)
  searchBox:ClearAllPoints()
  searchBox:SetPoint('LEFT', title, 'RIGHT', 24, 0)
  searchBox:SetSize(112, 24)
  searchBox:SetMultiLine(false)
  searchBox:SetMaxBytes(64)
  searchBox:SetFontObject(ChatFontNormal)
  searchBox:SetAutoFocus(false)
  searchBox:SetScript('OnTextChanged', function(self)
    if self:GetText() == '' then
      f.searchPlaceholder:Show()
    else
      f.searchPlaceholder:Hide()
    end
    updateScroller()
  end)
  searchBox:SetScript('OnEscapePressed', function() searchBox:ClearFocus() end)
  f.search = searchBox

  local contentScroller = CreateFrame('ScrollFrame', nil, f, 'UIPanelScrollFrameTemplate')
  contentScroller:SetPoint('LEFT', TABLE_WIDTH+64, 0)
  contentScroller:SetPoint('RIGHT', -32, 0)
  contentScroller:SetPoint('TOP', 0, -40)
  contentScroller:SetPoint('BOTTOM', 0, 50)
  contentScroller:Hide()

  local contentBox = CreateFrame('EditBox', nil, contentScroller)
  contentScroller:SetScrollChild(contentBox)
  contentBox:SetSize(contentScroller:GetSize())
  contentBox:SetMultiLine(true)
  contentBox:SetMaxBytes(nil)
  contentBox:SetFontObject(ChatFontNormal)
  contentBox:SetScript('OnEscapePressed', function() f:Hide(); end)
  contentBox:SetAutoFocus(false)
  contentBox:ClearFocus()
  contentBox.scrollbar = contentScroller
  f.contentBox = contentBox

  local exportButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  exportButton:ClearAllPoints()
  exportButton:SetPoint('LEFT', TABLE_WIDTH+64, 0)
  exportButton:SetPoint('BOTTOM', 0, 16)
  exportButton:SetNormalFontObject(ChatFontNormal)
  exportButton:SetHighlightFontObject(ChatFontNormal)
  exportButton:SetDisabledFontObject(ChatFontNormal)
  exportButton:SetText('Export Table')
  exportButton:SetSize(100, 24)
  exportButton:Hide()
  exportButton:SetScript("OnClick", function()
    WagoLib:DataToString(_G[WagoAnything.selectedTableName], {
      table = WagoAnything.selectedTableName
    }, function(strError, strEncoded)  
      if strError then
        print("|FFFF0000ENCODING ERROR:|r", strError)
      else
        local f = WagoLib:CreateExportFrame()
        f:SetTitle("Export ".. WagoAnything.selectedTableName)
        f:SetText(strEncoded)  
        f:Show()  
      end
    end)
  end)

  f.importButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.importButton:ClearAllPoints()
  f.importButton:SetPoint('LEFT', TABLE_WIDTH+64, 0)
  f.importButton:SetPoint('TOP', 0, -12)
  f.importButton:SetNormalFontObject(ChatFontNormal)
  f.importButton:SetHighlightFontObject(ChatFontNormal)
  f.importButton:SetDisabledFontObject(ChatFontNormal)
  f.importButton:SetText('Import Table')
  f.importButton:SetSize(100, 24)
  f.importButton:SetScript("OnClick", function()
    f.importFrame = WagoLib:CreateImportFrame(function(strError, tblData, tblMetadata)
      if strError then  
        print("|FFFF0000DECODING ERROR:|r", strError)  
      else
        ImportingTable = {
          name = tblMetadata.table,
          data = tblData
        }
        WagoAnything.selectedTable = 1
        contentBox:SetText(WagoAnything.PrettyTable(ImportingTable.data, ImportingTable.name))
        contentBox.scrollbar:Show()
        updateScroller()
        f.importFrame:Hide()
        f.importButton:Hide()
        f.importFrame:SetText('')
        f.confirmImportButton:Show()
      end  
    end)  
    f.importFrame:SetTitle("Import table")
    f.importFrame:Show()
  end)

  f.confirmImportButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.confirmImportButton:ClearAllPoints()
  f.confirmImportButton:SetPoint('LEFT', TABLE_WIDTH+64, 0)
  f.confirmImportButton:SetPoint('TOP', 0, -12)
  f.confirmImportButton:SetNormalFontObject(ChatFontNormal)
  f.confirmImportButton:SetHighlightFontObject(ChatFontNormal)
  f.confirmImportButton:SetDisabledFontObject(ChatFontNormal)
  f.confirmImportButton:SetText('Confirm Import')
  f.confirmImportButton:SetSize(100, 24)
  f.confirmImportButton:Hide()
  f.confirmImportButton:SetScript("OnClick", function()
    print('|cFFDCCD79' .. ImportingTable.name .. '|r stored.')
    _G[ImportingTable.name] = ImportingTable.data
    ImportingTable = nil
    f.confirmImportButton:Hide()
    contentBox:SetText('')
    WagoAnything.selectedTable = nil
    updateScroller()
  end)

  local tableScrollerContainer = CreateFrame('Frame', "$parentTableScroller", f)
  tableScrollerContainer:SetPoint('LEFT', 16, 0)
  tableScrollerContainer:SetPoint('RIGHT', -TEXTAREA_WIDTH, 0)
  tableScrollerContainer:SetPoint('TOP', title, 'BOTTOM')
  tableScrollerContainer:SetPoint('BOTTOM', 0, 50)
  tableScrollerContainer:SetWidth(TABLE_WIDTH)

  local tableScroller = CreateFrame("ScrollFrame", "$parentContent", tableScrollerContainer, "FauxScrollFrameTemplate")
  tableScroller:SetAllPoints()
  tableScroller:SetWidth(TABLE_WIDTH)
  tableScroller:SetAllPoints()
  tableScroller:SetScript('OnVerticalScroll', function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() updateScroller(f) end)
  end)
  tableScroller:SetScript('OnShow', function() updateScroller(f) end)
  f.tableScroller = tableScroller

  local rows = {}
  local tables = GetDataTables()
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", "$parentRow" .. i, tableScroller)
    row:Hide()
    row:SetWidth(TABLE_WIDTH)
    row:SetHeight(ROW_HEIGHT)

    local label = CreateFrame("Frame", "$parentLevel", row)
    label:SetWidth(TABLE_WIDTH)
    label:SetPoint("LEFT", row, "LEFT")
    label:SetPoint("TOP", row, "TOP")
    label:SetPoint("BOTTOM", row, "BOTTOM")

    local labelText = label:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    labelText:SetJustifyH("LEFT")
    labelText:SetPoint("TOPLEFT", label, "TOPLEFT")
    labelText:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT")
    labelText:SetText(tables[i])
    row.label = labelText

    local highlight = row:CreateTexture(nil, 'HIGHLIGHT')
    highlight:SetAllPoints(true)
    highlight:SetColorTexture(0, 0, 0, 0)
    row.highlight = highlight

    row:EnableMouse(true)
    row:SetScript('OnMouseDown', function()
      exportButton:Show()
      WagoAnything.selectedTable = i + FauxScrollFrame_GetOffset(tableScroller)
      WagoAnything.selectedTableName = tables[WagoAnything.selectedTable]
      updateScroller()
      if WagoAnything.selectedTable == 1 and ImportingTable then
        contentBox:SetText(WagoAnything.PrettyTable(ImportingTable.data, ImportingTable.name))
        f.confirmImportButton:Show()
        f.importButton:Hide()
      else
        contentBox:SetText(WagoAnything.PrettyTable(_G[tables[WagoAnything.selectedTable]], tables[WagoAnything.selectedTable]))
        f.confirmImportButton:Hide()
        f.importButton:Show()
        
        if IsShiftKeyDown() then
          WagoLib:CreateChatLink(tables[WagoAnything.selectedTable], _G[tables[WagoAnything.selectedTable]], {
            table = tables[WagoAnything.selectedTable]
          })
        end
      end
      contentBox.scrollbar:Show()
    end)
    row:SetScript('OnEnter', function()
      row.highlight:SetColorTexture(.44, .44, .11, 0.5)
    end)
    row:SetScript('OnLeave', function()
      row.highlight:SetColorTexture(0, 0, 0, 0)
    end)

    if (rows[i - 1] == nil) then
        row:SetPoint("TOPLEFT", tableScroller, 8, -8)
    else
        row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
    end

    rawset(rows, i, row)
  end
  tableScroller.rows = rows
  WagoAnything.MainFrame = f
  return f
end


local function openWindow()
  local frame = WagoAnything:CreateFrame()
  frame:Show()
  updateScroller()
end

WagoLib:SetOnChatLinkImport(function(strError, tblData, tblMetadata)
  local tables = GetDataTables(true)
  _G[tblMetadata.table] = tblData
  for i,v in pairs(tables) do
    if v == tblMetadata.table then
      WagoAnything.selectedTable = i
      WagoAnything.selectedTableName = v
      break
    end
  end
  local f = WagoAnything:CreateFrame()
  f:Show()
  f.contentBox:SetText(WagoAnything.PrettyTable(tblData, tblMetadata.table))
  f.contentBox:Show()
  f.contentBox.scrollbar:Show()
  updateScroller()
end)


SLASH_WAGO1 = "/wago"
SlashCmdList["WAGO"] = function(cmd)
  GetDataTables(true)
  openWindow() 
  -- cmd = string.lower(cmd)
  -- if (cmd == '') then 
  --   openWindow() 
  -- end
end


