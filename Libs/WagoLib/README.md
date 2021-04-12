WagoLib adds import/export of table data to any addon. Additionally it can handle transmitting data between players.  
  
LibStub, ChatThrottleLib, LibSerialize and LibDeflate are included with WagoLib.

**<a href="https://addons.wago.io" class="button" target="_blank">Download WagoLib library</a>**

------------------------------------------------------

To get started, add the library to your .toc file by including the relative path to the WagoLib.xml file. This includes everything you'll need.

```sass
WagoLib\WagoLib.xml
```

Then initialize the library near the top of your code. The initializing `:Setup` function requires your addon name as the first parameter. This is used to identify the imports on Wago and when sharing data in-game via the chat functions.

```lua
local WagoLib = LibStub("WagoLib-1.0"):Setup("My Unique Addon Name")
```

------------------------------------------------------

## Exporting

### WagoLib:DataToString(tblData\[, metadata\], onComplete)

Converts a table into an encoded string for copy/pasting into Wago. This is run ascynchronously so as not to lower the player's framerate, and therefore does not have a return value. Instead, the onComplete callback is called with the string once complete.

Parameter | Type | Required? | Details 
--- | --- | --- | ---
tblData | Table | Required | Your table data to process into a string for export.
metaData | Table | Optional | Additional related data. This will be viewable on Wago&#46;io, and and can be setup to be searchable. Max size 512 bytes.
onComplete | Function | Required | Called when import string is ready.

onComplete is called with `onComplete(strError, strEncoded)`. strError will be nil if the process is successful.

```lua
WagoLib:DataToString(tblData, tblMetaData, function(strError, strEncoded)  
  if strError then  
    print("Encoding error:" .. strError)  
  else  
    MyAddon:ShowExport(strEncoded) -- However your addon wants to display the string. See :CreateExportFrame for a built in method!
  end  
end)
```

### WagoLib:CreateExportFrame()

WagoLib includes some basic tools to create a simple export frame for displaying an encoded string.

![Export Frame Screenshot](screenshot) 
```lua
local f = WagoLib:CreateExportFrame()  
f:SetTitle("My Addon: A Table for Export") -- Defaults to "Export My Unique Addon Name" (per Setup)  
f:SetText(strEncoded)  
f:Show()  
-- f.closeButton is accessible to call :SetText, :SetScript, etc as needed.
```

------------------------------------------------------

## Importing

### WagoLib:StringToData(strEncoded, onComplete)

Converts an encoded string back into a table. Like DataToString, this is run ascynchronously and the result is passed through to a callback function.

Parameter | Type | Required? | Details 
--- | --- | --- | ---
strEncoded | String | Required | Your import string to process into a table for your addon.
onComplete | Function | Required | Called when table is ready.

```lua
WagoLib:StringToData(strEncoded, function(strError, tblData, tblMetadata)  
  if strError then  
    print("Decoding error:" .. strError)  
  else  
    MyAddon:AddImport(tblData, tblMetadata) -- However your addon wants to handle the data.
  end  
end)
```

### WagoLib:CreateImportFrame(onPaste)

WagoLib includes some basic tools to create a simple import frame for pasting in an encoded string.

![Import Frame Screenshot](screenshot) 

Parameter | Type | Required? | Details 
--- | --- | --- | ---
onPaste | Function | Required | Called with the processed data table when the string is pasted in.

```lua
local f = WagoLib:CreateImportFrame(function(strError, tblData, tblMetadata)
  if strError then  
    print("Decoding error:" .. strError)  
  else  
    MyAddon:AddImport(tblData, tblMetadata) -- However your addon wants to handle the data.
  end  
end)  
f:SetTitle("My Addon: Import Data") -- Defaults to "Import My Unique Addon Name" (per Setup)  
f:Show()
-- f.closeButton is accessible to call :SetText, :SetScript, etc as needed.
```

------------------------------------------------------

## Transmitting

### WagoLib:SetOnChatLinkImport(onFinish)

WagoLib can facilitate transmitting table data between players through in-game chat. If your addon will make use of this, you must set the onChatLinkImport function in your addon's initialization steps. `onFinish` is triggered once the trasmission is complete and the data has been decoded into a proper table.

Parameter | Type | Required? | Details 
--- | --- | --- | ---
onPaste | Function | Required | Called with the received data table when the data after successful receipt and processing.

```lua
local f = WagoLib:SetOnChatLinkImport(function(strError, tblData, tblMetadata)
  if strError then  
    print("Encoding error:" .. strError)  
  else  
    MyAddon:AddImport(tblData, tblMetadata) -- However your addon wants to handle the table.
  end  
end)
```

### WagoLib:CreateChatLink(label, data[, metadata])

WagoLib will create a clickable link to send via the in-game chat. Guild, Officer, Party, Raid, Instance chat and Whispers will work, and the channel(s) the chat message is sent over are the channels that will listen requests for that data. The player must have an active textbox ready for typing or this will immediately return nil.

Parameter | Type | Required? | Details 
--- | --- | --- | ---
label | String | Required | Text label to use for the link itself.
data | Table | Required | Your table data to process into a string for export.
label | String | Required | Additional related data. This will be viewable on Wago&#46;io, and and can be setup to be searchable. Max size 512 bytes.

```lua
if GetCurrentKeyBoardFocus() and IsShiftKeyDown() then
  WagoLib:CreateChatLink('My Export', tblData, tblMetadata)
end
```