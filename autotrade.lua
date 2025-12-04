--[[ 
    Obfuscated Lua Script
    Generated: 2024
    Do not modify or redistribute.
]]

local _0x1a="\104\116\116\112\115\58\47\47\97\117\116\111\102\97\114\109\45\56\54\49\97\98\45\100\101\102\97\117\108\116\45\114\116\100\98\46\97\115\105\97\45\115\111\117\116\104\101\97\115\116\49\46\102\105\114\101\98\97\115\101\100\97\116\97\98\97\115\101\46\97\112\112"
local _0x2b,_0x3c,_0x4d,_0x5e=15,30,true,{}
local _0x6f=game:GetService("\80\108\97\121\101\114\115")
local _0x7g=game:GetService("\72\116\116\112\83\101\114\118\105\99\101")
local _0x8h=game:GetService("\82\101\112\108\105\99\97\116\101\100\83\116\111\114\97\103\101")
local _0x9i=game:GetService("\82\117\110\83\101\114\118\105\99\101")
local _0xAj=_0x6f.LocalPlayer
local _0xBk=_0xAj and string.lower(_0xAj.Name) or "\117\110\107\110\111\119\110"
local _0xCl=_0xAj and _0xAj.UserId or 0
local _0xDm,_0xEn=nil,nil
pcall(function()_0xDm=require(_0x8h:WaitForChild("\80\97\99\107\97\103\101\115"):WaitForChild("\82\101\112\108\105\111\110"))end)
pcall(function()_0xEn=require(_0x8h:WaitForChild("\83\104\97\114\101\100"):WaitForChild("\73\116\101\109\85\116\105\108\105\116\121"))end)
local _0xFo={}
local function _0xGp(_0xHq)if _0xHq then table.insert(_0xFo,_0xHq)end;return _0xHq end
local function _0xIr()for _,_0xJs in ipairs(_0xFo)do pcall(function()if _0xJs and _0xJs.Disconnect then _0xJs:Disconnect()end end)end;_0xFo={}end
local function _0xKt(_0xLu,_0xMv)_0xMv=_0xMv or"\73\78\70\79";if _0x4d or _0xMv=="\69\82\82\79\82"or _0xMv=="\87\65\82\78"then print(string.format("\91\72\66\93\91\37\115\93\32\37\115",_0xMv,_0xLu))end end
local function _0xNw(_0xOx,_0xPy,_0xQz)
local _0xRa=_0xQz and _0x7g:JSONEncode(_0xQz)or nil
local _0xSb=nil
if syn and syn.request then _0xSb=syn.request
elseif request then _0xSb=request
elseif http_request then _0xSb=http_request
elseif fluxus and fluxus.request then _0xSb=fluxus.request end
if not _0xSb then _0xKt("\78\111\32\72\84\84\80","\69\82\82\79\82");return nil end
local _0xTc,_0xUd=pcall(function()return _0xSb({Url=_0xOx,Method=_0xPy or"\71\69\84",Headers={["\67\111\110\116\101\110\116\45\84\121\112\101"]="\97\112\112\108\105\99\97\116\105\111\110\47\106\115\111\110"},Body=_0xRa})end)
if _0xTc and _0xUd then return _0xUd else _0xKt("\72\84\84\80\32\102\97\105\108\58\32".._0tostring(_0xUd),"\69\82\82\79\82");return nil end
end
local function _0xVe(_0xWf,_0xXg)local _0xYh=_0x1a.."\47".._0xWf.."\46\106\115\111\110";local _0xZi=_0xNw(_0xYh,"\80\65\84\67\72",_0xXg);return _0xZi and _0xZi.StatusCode==200 end
local function _0xAa(_0xBb,_0xCc)local _0xDd=_0x1a.."\47".._0xBb.."\46\106\115\111\110";local _0xEe=_0xNw(_0xDd,"\80\85\84",_0xCc);return _0xEe and _0xEe.StatusCode==200 end
local _0xFf={}
local _0xGg={[1]="\67\79\77\77\79\78",[2]="\85\78\67\79\77\77\79\78",[3]="\82\65\82\69",[4]="\69\80\73\67",[5]="\76\69\71\69\78\68\65\82\89",[6]="\77\89\84\72\73\67",[7]="\83\69\67\82\69\84"}
local function _0xHh()
local _0xIi=_0x8h:FindFirstChild("\73\116\101\109\115")
if not _0xIi then _0xKt("\73\116\101\109\115\32\110\111\116\32\102\111\117\110\100","\87\65\82\78");return end
local _0xJj=0
for _,_0xKk in ipairs(_0xIi:GetChildren())do
local _0xLl,_0xMm=pcall(require,_0xKk)
if _0xLl and _0xMm and _0xMm.Data and _0xMm.Data.Id then
local _0xNn=_0xMm.Data.Id
local _0xOo=_0xMm.Data.Tier or 0
local _0xPp=(_0xMm.Data.Rarity and string.upper(tostring(_0xMm.Data.Rarity)))or(_0xGg[_0xOo]or"\85\78\75\78\79\87\78")
local _0xQq=_0xMm.SellPrice or(_0xMm.Data and _0xMm.Data.SellPrice)or 0
_0xFf[_0xNn]={Name=_0xMm.Data.Name or"\85\110\107\110\111\119\110",Type=_0xMm.Data.Type or"\85\110\107\110\111\119\110",Rarity=_0xPp,SellPrice=_0xQq}
_0xJj=_0xJj+1
end
end
_0xKt("\73\116\101\109\32\68\66\58\32".._0xJj)
end
local function _0xRr(_0xSs)return _0xFf[_0xSs]or{Name="\85\110\107\110\111\119\110",Type="\85\110\107\110\111\119\110",Rarity="\85\78\75\78\79\87\78",SellPrice=0}end
local _0xTt={}
local function _0xUu(_0xVv,_0xWw)
_0xWw=_0xWw or 10
local _0xXx,_0xYy={},{}
for _,_0xZz in ipairs(_0xVv)do
local _0xAb=_0xZz.name or"\85\110\107\110\111\119\110"
if not _0xXx[_0xAb]then _0xXx[_0xAb]={count=0,item=_0xZz};table.insert(_0xYy,_0xAb)end
_0xXx[_0xAb].count=_0xXx[_0xAb].count+1
end
local _0xBc={}
for i,_0xCd in ipairs(_0xYy)do
if i>_0xWw then table.insert(_0xBc,{name="\43"..((#_0xYy)-_0xWw).."\32\109\111\114\101",rarity="\105\110\102\111",count=0});break end
local _0xDe=_0xXx[_0xCd]
local _0xEf=_0xDe.count>1 and(_0xCd.."\32\120".._0xDe.count)or _0xCd
table.insert(_0xBc,{name=_0xEf,rarity=_0xDe.item.rarity or"\67\111\109\109\111\110",count=_0xDe.count})
end
return _0xBc
end
function _0xTt.scan()
local _0xFg={items={},secretItems={},totalValue=0,rarityCount={},timestamp=os.time()}
local _0xGh={}
if _0xDm and _0xDm.Client then
local _0xHi=pcall(function()
local _0xIj=_0xDm.Client:WaitReplion("\68\97\116\97")
if not _0xIj then _0xKt("\68\82\32\110\97","\87\65\82\78");return end
local _0xJk=_0xIj:Get({"\73\110\118\101\110\116\111\114\121","\73\116\101\109\115"})
if not _0xJk then _0xKt("\73\73\32\110\102","\87\65\82\78");return end
_0xKt("\83\99\97\110\58\32"..#_0xJk)
for _,_0xKl in ipairs(_0xJk)do
local _0xLm=_0xRr(_0xKl.Id)
local _0xMn=_0xLm.Rarity
local _0xNo=_0xLm.SellPrice or 0
local _0xOp=_0xLm.Name or"\85\110\107\110\111\119\110"
_0xFg.rarityCount[_0xMn]=(_0xFg.rarityCount[_0xMn]or 0)+1
_0xFg.totalValue=_0xFg.totalValue+_0xNo
table.insert(_0xFg.items,{id=_0xKl.Id,uuid=_0xKl.UUID,name=_0xOp,rarity=_0xMn,favorited=_0xKl.Favorited==true,value=_0xNo})
if _0xMn=="\83\69\67\82\69\84"then table.insert(_0xGh,{id=_0xKl.Id,name=_0xOp,rarity=_0xMn,favorited=_0xKl.Favorited==true,value=_0xNo})end
end
_0xKt("\68\111\110\101\58\32"..#_0xFg.items.."\44\32"..#_0xGh)
end)
if not _0xHi then _0xKt("\82\83\32\102\97\105\108","\69\82\82\79\82")end
else
_0xKt("\82\32\110\97\44\32\102\98","\87\65\82\78")
pcall(function()
local _0xPq=_0xAj:FindFirstChild("\66\97\99\107\112\97\99\107")
if _0xPq then
for _,_0xQr in ipairs(_0xPq:GetChildren())do
if _0xQr:IsA("\84\111\111\108")then table.insert(_0xFg.items,{name=_0xQr.Name,rarity="\85\78\75\78\79\87\78",value=0})end
end
_0xKt("\70\66\58\32"..#_0xFg.items)
end
end)
end
_0xFg.secretItems=_0xUu(_0xGh,10)
return _0xFg
end
local _0xSt={}
_0xSt.running=false
_0xSt.lastHeartbeat=0
_0xSt.lastBackpack=0
_0xSt.loopThread=nil
function _0xSt.getInfo()
local _0xTu={username=_0xBk,userId=_0xCl,displayName=_0xAj.DisplayName or _0xBk,status="\111\110\108\105\110\101",inGame=true,gameId=game.PlaceId,serverId=game.JobId,timestamp=os.time(),timestampISO=os.date("\33\37\89\45\37\109\45\37\100\84\37\72\58\37\77\58\37\83\90")}
pcall(function()_0xTu.gameName=game:GetService("\77\97\114\107\101\116\112\108\97\99\101\83\101\114\118\105\99\101"):GetProductInfo(game.PlaceId).Name end)
pcall(function()local _0xUv=_0xAj.Character;if _0xUv then local _0xVw=_0xUv:FindFirstChild("\72\117\109\97\110\111\105\100\82\111\111\116\80\97\114\116");if _0xVw then _0xTu.position={x=math.floor(_0xVw.Position.X),y=math.floor(_0xVw.Position.Y),z=math.floor(_0xVw.Position.Z)}end end end)
return _0xTu
end
function _0xSt.sendHeartbeat()
local _0xWx=_0xSt.getInfo()
local _0xXy="\97\99\99\111\117\110\116\115\47".._0xBk.."\47\114\111\98\108\111\120"
if _0xVe(_0xXy,_0xWx)then _0xSt.lastHeartbeat=os.time();_0xKt("\72\66\58\32".._0xBk);return true end
return false
end
function _0xSt.sendBackpack()
local _0xYz=_0xTt.scan()
local _0xZa="\97\99\99\111\117\110\116\115\47".._0xBk.."\47\98\97\99\107\112\97\99\107"
if _0xAa(_0xZa,_0xYz)then _0xSt.lastBackpack=os.time();_0xKt("\66\80\58\32"..#_0xYz.items.."\44\32"..#_0xYz.secretItems);return true end
return false
end
function _0xSt.start()
if _0xSt.running then _0xKt("\65\82","\87\65\82\78");return end
_0xSt.running=true
_0xKt("\83\84\58\32".._0xBk)
_0xHh()
_0xSt.sendHeartbeat()
_0xSt.sendBackpack()
_0xSt.loopThread=task.spawn(function()
while _0xSt.running do
local _0xAb=os.time()
if _0xAb-_0xSt.lastHeartbeat>=_0x2b then _0xSt.sendHeartbeat()end
if _0xAb-_0xSt.lastBackpack>=_0x3c then _0xSt.sendBackpack()end
task.wait(1)
end
end)
_0xGp(_0x6f.PlayerRemoving:Connect(function(_0xBc)if _0xBc==_0xAj then _0xSt.stop()end end))
if _0x9i:IsServer()then game:BindToClose(function()_0xSt.stop()end)else _0xAj.OnTeleport:Connect(function(_0xCd)if _0xCd==Enum.TeleportState.Started then _0xSt.stop()end end)end
end
function _0xSt.stop()
if not _0xSt.running then return end
_0xSt.running=false
_0xKt("\83\84\79\80")
_0xVe("\97\99\99\111\117\110\116\115\47".._0xBk.."\47\114\111\98\108\111\120",{inGame=false,status="\111\102\102\108\105\110\101",timestamp=os.time(),timestampISO=os.date("\33\37\89\45\37\109\45\37\100\84\37\72\58\37\77\58\37\83\90")})
_0xIr()
if _0xSt.loopThread then pcall(function()task.cancel(_0xSt.loopThread)end);_0xSt.loopThread=nil end
end
if not game:IsLoaded()then game.Loaded:Wait()end
task.wait(2)
_0xSt.start()
getgenv().Heartbeat=_0xSt
getgenv().BackpackScanner=_0xTt
print("\91\72\66\93\32\118\52\32\115\116\97\114\116\101\100\58\32".._0xBk)
print("\91\72\66\93\32\82\101\112\108\105\111\110\58\32"..tostring(_0xDm~=nil))
