
-- Automatisch generiert

local frmError = 1;
local frmNoDatabase = 3;
local frmNoUser = 4;
local frmWAScan = 5;
local frmWAScanHelp = 6;
local frmFaultChoose = 7;
local frmFault = 8;
local frmService = 9;
local frmFaultHelp = 10;
local frmInfoChoose = 11;
local frmWAList = 12;
local frmHistory = 13;
local frmUserList = 14;
local frmWAInfo = 15;
local frmWAView = 16;
local frmWAMengen = 17;
local frmWAViewHelp = 18;
local frmUserPause = 19;
local VK_RFID = 1;
local VK_SCAN = 2;
local VK_F4 = 260;
local VK_F5 = 261;
local VK_F11 = 267;
local VK_LEFT = 280;
local VK_RIGHT = 281;
local VK_ESC = 27;
local VK_RETURN = 13;

--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,94


StringBuilder = luanet.import_type("System.Text.StringBuilder");

function BdeString(text, maxlen)
  if string.len(text) > maxlen then
    text = string.sub(text, 1, maxlen);
  end;
  return string.upper(text);
end;


function IsNull(val, def)
  if val == nil then
    return def;
  else
    return val;
  end;
end;


function SafeString(value)
  if value == nil then
    return "";
  else
    return tostring(value);
  end;
end;


function RefreshUserVariables(self)

  local sUsers = StringBuilder();
  local dv = self.dvPED:GetDataViewLocked();
  if dv == nil then
    return;
  end;

  -- Alle Nutzer in eine Liste setzen
  while dv:MoveNext() do

    -- Durch Komma Trennen
    if sUsers.Length > 0 then
      sUsers:Append(",");
    end;

    -- Nutzer anhängen
    local sUser = dv:GetValue("PERSNAME");
    local iPos, tmp = string.find(sUser, ",");
    if iPos ~= nil then
      sUser = string.sub(sUser, 1, iPos - 1);
    end;

    -- Liste erweitern
    sUsers:Append(string.upper(sUser));

    -- Status P,F
    local lPause = false;

    if dv:GetValue("PERSSTATECUR") == "P" then
      sUsers:Append("(P");
      lPause = true;
    end;
    if dv:GetValue("PEDNOAUTOLOGOUT") == true then
      if lPause then
        sUsers:Append(",F)");
      else
        sUsers:Append("(F)");
      end;
    elseif lPause then
      sUsers:Append(")");
    end;
  end;

  dv:Dispose();

  SetConstant("U", sUsers:ToString());
end;


function StartWA(self, auftrag)
  -- Einfache Kontrolle des WA
  if auftrag == nil or string.len(auftrag) ~= 10 or string.sub(auftrag, 1, 1) ~= "W" then
    if auftrag == nil then
      auftrag = "<NIL>";
    end;
    self.sError = "'" .. auftrag .. "' IST KEIN AUFTRAG...";
  else
    -- Versuche den Auftrag anzumelden
    self.sError = StateProcedureSafe(true, "pps.BdeMaStartWA", { WANRAGNR = auftrag });
    if self.sError ~= nil then
      self.sError = string.upper(self.sError);
    end;
  end;

  -- Lösche Inhalt
  SetVariable("0", nil);

  self:Refresh();
end;


function UpdateHeader()

  local sConstX;
  local sAuftr;
  local sStatusText;

  if bde.dvAUD.RowCount == 0 then
    sStatusText = "LEERLAUF";
  else

    local aufId = bde.dvAUD:GetValue(0, "AUDAUFID", nil);
    local loarId = bde.dvAUD:GetValue(0, "AUDLOARID", nil);

    if aufId == nil then -- Sonderauftrag

      sConstX = "";
      sAuftr = "";

      if loarId == "700" then
        sStatusText = "WARTUNG";
      elseif loarId == "710" then
        sStatusText = "STÖRUNG";
      elseif loarId == nil then
        sStatusText = "S=NIL";
      else
        StatusText = "S=" .. loarId;
      end;

    else

      local state = bde.dvAUD:GetValue(0, "AUDPAUSE", nil);

      local dv = CreateDataView("AUF", string.format("AUFID = %d", aufId), "AUFID");
      sAuftr = dv:GetValue(0, "WAKOWANR", "") .. "-" .. dv:GetValue(0, "WAPOPOS", "");
      dv:Dispose();

      sConstX = "WERKAUFTRAG";

      if state ~= "A" then
        sStatusText = "UNTERBR";
      elseif loarId == "100" then
        sStatusText = "FERTIGEN";
      elseif loarId == "200" then
        sStatusText = "RÜSTEN";
      elseif loarId == "810" then
        sStatusText = "NACHARBEIT";
      elseif loarId == nil then
        sStatusText = "A=NIL";
      else
        StatusText = "A=" .. loarId;
      end;

    end;
  end;

  SetConstant('X', sConstX);
  SetConstant('Y', sAuftr);
  SetConstant('Z', sStatusText);

end;

--PDB

bde = {
  Init = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,260

    self.dvPED = RegisterView("PED", string.format("PEDDEVID = %d", host.Id), "PEDSORT asc");
    self.dvAUD = RegisterView("AUD", string.format("AUDDEVID = %d", host.Id), "AUDPAUSE asc"); -- Sortierung, bestimmt die Störung oder Fertigung
--PDB
  end,
  Done = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,266

    UnregisterView(self.dvPED);
    UnregisterView(self.dvAUD);
--PDB
  end,
  Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,272

    local newTopForm = 0;

    -- Wähle das passende Formular aus
    if not IsBdeConnected() then
      newTopForm = frmNoDatabase;
    elseif self.dvAUD.RowCount > 0 then -- Auftrag angemeldet
      if self.dvAUD:GetValue(0, "AUDAUFID", nil) ~= nil then -- Auftrag
        newTopForm = frmWAView;
      else
        if self.dvAUD:GetValue(0, "AUDLOARID", nil) == "700" then -- Wartung?
          newTopForm = frmService;
        else -- Sonst Störung
          newTopForm = frmFault;
        end;
      end;
    elseif self.dvPED.RowCount > 0 then -- Nutzer angemeldet
      newTopForm = frmWAScan;
    else
      newTopForm = frmNoUser;
    end;

    -- Setze das neue TopFormular
    if host.TopFormularId ~= newTopForm then
      SetFormular(newTopForm, nil); -- Ruft Refresh auf
    else
      -- Aktualisiere die Nutzer
      RefreshUserVariables(self);
    end;
--PDB
  end,
  Trigger = function (self, trigger, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,304

    if trigger == VK_RFID then -- Nutzeraktion durchführen
      StateProcedure(false, "pps.BdeMaToggleKey", { PAUSE = 0, PERSRFID = extra.Code });
      return true;
    elseif trigger == VK_RIGHT then
      StateProcedure(false, "pps.BdeMaUserRoll", { RIGHT = 1 });
      return true;
    elseif trigger == VK_LEFT then
      StateProcedure(false, "pps.BdeMaUserRoll", { RIGHT = 0 });
      return true;
    elseif trigger == VK_F4 then
      PushFormular(frmUserPause, nil);
      return true;
    elseif trigger == VK_F5 then
      if host.CurrentFormularId == frmHistory or 
         host.CurrentFormularId == frmWAList or
         host.CurrentFormularId == frmUserList or
         host.CurrentFormularId == frmWAInfo then
        PopFormular();
      else
        PushFormular(frmInfoChoose, nil);
      end;
      return true;
    elseif trigger == VK_F11 and self.dvPED.RowCount > 0 then
      PushFormular(frmFaultChoose, nil);
      return true;
    end;
--PDB
  end
};

--------------------------------------------------------------------------------
-- frmEmpty
function __Form0__()
  return {
  };
end;

--------------------------------------------------------------------------------
-- frmError
function __Form1__()
  return {
    Refresh = function (self)
--PDB BDE.Common.xml,21

      SetConstant("A", self.args.sText);
--PDB
    end,
    Trigger = function (self, trigger, extra)
--PDB BDE.Common.xml,26

      if trigger == VK_ESC or trigger == VK_RETURN or trigger == VK_RIGHT or trigger == VK_LEFT then
        PopFormular();
        return true;
      end;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmInfo
function __Form2__()
  return {
    Refresh = function (self)
--PDB BDE.Common.xml,51

      SetConstant("A", self.args.sText);
--PDB
    end,
    Trigger = function (self, trigger, extra)
--PDB BDE.Common.xml,56

      if trigger == VK_ESC or trigger == VK_RETURN or trigger == VK_RIGHT or trigger == VK_LEFT then
        PopFormular();
        return true;
      end;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmNoDatabase
function __Form3__()
  return {
    Init = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,350

      self.sOfflineTime = GetTimeStampStr();
--PDB
    end,
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,355

      SetConstant("A", self.sOfflineTime);
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmNoUser
function __Form4__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,375

      local dv = CreateDataView("DEV", string.format("DEVID = %d", host.Id), "DEVID asc");
      if dv ~= nil then
        if dv.RowCount > 0 then
          SetConstant("M", StrFmt("{0} ({1:00000})", { dv:GetValue(0, "BMSTNAME", ""), host.Id }));
        end;
        dv:Dispose();
      end;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmWAScan
function __Form5__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,404

      SetConstant("E", self.sError);
--PDB
    end,
    Trigger = function (self, trigger, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,409

      if trigger == VK_SCAN then
        StartWA(self, extra);
        return true;
      end;
--PDB
    end,
    Trigger_VK_F1 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,419

      PushFormular(frmWAScanHelp, nil);
      return true;
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,430

      StartWA(self, "W" .. SafeString(GetVariable("0")));
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmWAScanHelp
function __Form6__()
  return {
    Trigger_VK_F1 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,455

      PopFormular();
      return true;
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,464

      PopFormular();
      return true;
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,470

      PopFormular();
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmFaultChoose
function __Form7__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,502

      UpdateHeader();
--PDB
    end,
    Trigger_VK_0 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,509

      -- Ende
      if StateProcedure(false, "pps.BdeMaEndeAufgabe", {}) then
        PopFormular();
      end;
      return true;
--PDB
    end,
    Trigger_VK_1 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,518

      -- Wartung
      if StateProcedure(false, "pps.BdeMaStartAufgabe", { CODE = "1" }) then
        PopFormular();
      end;
      return true;
--PDB
    end,
    Trigger_VK_2 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,527

      -- Störung
      if StateProcedure(false, "pps.BdeMaStartAufgabe", { CODE = "2" }) then
        PopFormular();
      end;
      return true;
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,539

      PopFormular();
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmFault
function __Form8__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,567

      SetConstant("A", StrFmt("SEIT {0:g}", { bde.dvAUD:GetValue(0, "AUDSTART", nil) }));
--PDB
    end,
    Trigger_VK_F1 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,574

      PushFormular(frmFaultHelp, nil);
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmService
function __Form9__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,599

      SetConstant("A", StrFmt("SEIT {0:g}", { bde.dvAUD:GetValue(0, "AUDSTART", nil) }));
--PDB
    end,
    Trigger_VK_F1 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,606

      PushFormular(frmFaultHelp, nil);
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmFaultHelp
function __Form10__()
  return {
    Trigger_VK_F1 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,631

      PopFormular();
      return true;
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,640

      PopFormular();
      return true;
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,646

      PopFormular();
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmInfoChoose
function __Form11__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,675

      UpdateHeader();
--PDB
    end,
    Trigger_VK_1 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,682

      -- Arbeitsvorrat
      PopFormular();
      PushFormular(frmWAList, nil);
      return true;
--PDB
    end,
    Trigger_VK_2 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,690

      -- Buchungsverlauf
      PopFormular();          
      PushFormular(frmHistory, nil);
      return true;
--PDB
    end,
    Trigger_VK_3 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,698

      -- Angemeldete Nutzer
      PopFormular();
      PushFormular(frmUserList, nil);
      return true;
--PDB
    end,
    Trigger_VK_4 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,706

      -- Arbeitsgangtext
      PopFormular();
      PushFormular(frmWAInfo, nil);
      return true;
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,717

      PopFormular();
      PushFormular(frmWAList, nil);
      return true;
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,724

      PopFormular();
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmWAList
function __Form12__()
  return {
    Init = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,755

      -- Initialisiere die Daten die angezeigt werden sollen
      self.iCurrentPage = 0;
      self.iPageCount = 0;
      self.dvAUF = RegisterView("AUF", string.format("AUFDEVID = %d", host.Id), "AUFSORT asc");
--PDB
    end,
    Done = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,763

      UnregisterView(self.dvAUF);
--PDB
    end,
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,768


      local iRowCount = self.dvAUF.RowCount;

      -- Seitenzahl ausrechnen
      self.iPageCount = math.ceil(iRowCount / 6);
      if self.iPageCount == 0 then
        self.iPageCount = 1;
      end;

      -- Korrigiere eve. die Seite
      if self.iCurrentPage >= self.iPageCount then
        if self.iPageCount == 0 then
          self.iCurrentPage = 0;
        else
          self.iCurrentPage = self.iPageCount - 1;
        end;
      end;

      -- Spalten setzen
      local dv = self.dvAUF:GetDataViewLocked();
      if dv ~= nil then
        local iOfs = self.iCurrentPage * 6
        for i = 0, 5 do

          local iIdx = iOfs + i;
          if iIdx < dv.RowCount then
            -- Setze die aktuelle Zeile
            dv.CurrentIndex = iIdx;

            local iWakoLos = dv:GetValue("WAKOLOS");                
            local iWapoLieg = dv:GetValue("WAPOLIEGEM");
            if iWakoLos == nil then
              iWakoLos = -1;
            end;
            if iWapoLieg == nil then
              iWapoLieg = -1;
            end;

            -- Setze die Daten
            SetConstant(string.char(65 + i * 3), dv:GetValue("WAKOWANR") .. " " .. dv:GetValue("WAPOPOS"));
            SetConstant(string.char(66 + i * 3), BdeString(dv:GetValue("TEILNAME"), 20));
            SetConstant(string.char(67 + i * 3), StrFmt("{0,4:N0}/{1,4:N0}", { iWakoLos, iWapoLieg }));
          else

            -- Setze leere Felder
            SetConstant(string.char(65 + i * 3), nil);
            SetConstant(string.char(66 + i * 3), nil);
            SetConstant(string.char(67 + i * 3), nil);
          end;            
        end;
        dv:Dispose();
      end;

      -- Seitenzahl setzen
      SetConstant("Z", StrFmt("{0}/{1}", { self.iCurrentPage + 1, self.iPageCount }));
--PDB
    end,
    Trigger_VK_DOWN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,833

      if self.iCurrentPage < self.iPageCount - 1 then
        self.iCurrentPage = self.iCurrentPage + 1;
        self:Refresh();
      end;
      return true;
--PDB
    end,
    Trigger_VK_UP = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,842

      if self.iCurrentPage > 0 then
        self.iCurrentPage = self.iCurrentPage - 1;
        self:Refresh();
      end;
      return true;
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,851

      PopFormular();
      PushFormular(frmHistory, nil);
      return true;
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,858

      PopFormular();
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmHistory
function __Form13__()
  return {
    Init = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,903

      self.dvBLG = RegisterView("BLG", string.format("BLGDEVID = %d", host.Id), "BLGID desc");
--PDB
    end,
    Done = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,908

      UnregisterView(self.dvBLG);
--PDB
    end,
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,913

      -- Spalten setzen
      local dv = self.dvBLG:GetDataViewLocked();
      if dv ~= nil then
        for i = 0, 5 do

          if i < dv.RowCount then
            -- Setze die aktuelle Zeile
            dv.CurrentIndex = i;

            -- Setze die Daten
            SetConstant(string.char(65 + i * 3), StrFmt("{0:t}", { dv:GetValue("BLGZEIT") }));
            SetConstant(string.char(66 + i * 3), dv:GetValue("PERSPNR"));
            SetConstant(string.char(67 + i * 3), BdeString(dv:GetValue("BLGTEXT"), 80));
          else

            -- Setze leere Felder
            SetConstant(string.char(65 + i * 3), nil);
            SetConstant(string.char(66 + i * 3), nil);
            SetConstant(string.char(67 + i * 3), nil);
          end;            
        end;
        dv:Dispose();
      end;
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,946

      PopFormular();
      PushFormular(frmUserList, nil);
      return true;
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,953

      PopFormular();
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmUserList
function __Form14__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,998

      local dv = bde.dvPED:GetDataViewLocked();
      if dv ~= nil then

        for i = 0, 5, 1 do
          if i < dv.RowCount then
            dv.CurrentIndex = i;

            -- Setze die Inhalte
            local sState;
            if dv:GetValue("PERSSTATECUR") == "P"  then
              sState = "PAUSE";
            else
              sState = nil;
            end;

            SetConstant(string.char(65 + i * 3), dv:GetValue("PERSPNR"));
            SetConstant(string.char(66 + i * 3), string.upper(dv:GetValue("PERSNAME")));
            SetConstant(string.char(67 + i * 3), sState);
          else
            -- Setze leere Felder
            SetConstant(string.char(65 + i * 3), nil);
            SetConstant(string.char(66 + i * 3), nil);
            SetConstant(string.char(67 + i * 3), nil);
          end;
        end;
        dv:Dispose();
      end;
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1035

      PopFormular();
      PushFormular(frmWAInfo, nil);
      return true;
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1042

      PopFormular();
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmWAInfo
function __Form15__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1086


      -- Suche den Auftrag
      local aufId = nil;
      local sAgText;
      for i = 0, bde.dvAUD.RowCount - 1, 1 do
        local curAufId = bde.dvAUD:GetValue(i, "AUDAUFID", nil);
        if curAufId ~= nil and bde.dvAUD:GetValue(i, "AUDPAUSE", "") == "A" then
           aufId = curAufId;
         end;
      end;

      -- Hole die Infos zum Auftrag ab
      if aufId == nil then
        sAgText = "KEIN WERKAUFTRAG GEWÄHLT...";
      else
        local dv = CreateDataView("AUF", string.format("AUFID = %d", aufId), "AUFID asc");
        if dv ~= nil then
          if dv.RowCount > 0 then
            sAgText = BdeString(dv:GetValue(0, "WAPONAME", ""), 255);
          end;
          dv:Dispose();
        end;
      end;

      SetConstant("A", sAgText);
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1122

      PopFormular();
      PushFormular(frmWAList, nil);
      return true;
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1129

      PopFormular();
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmWAView
function __Form16__()
  return {
    Init = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1151

      -- Lese den aktuellen Auftrag aus
      if bde.dvAUD.RowCount > 0 then
        self.aufId = bde.dvAUD:GetValue(0, "AUDAUFID", nil);
      end;

      -- Erzeuge einen View auf die Auftragsdaten
      if self.aufId ~= nil then
        self.dvAUF = RegisterView("AUF", string.format("AUFID = %d", self.aufId), "AUFID asc");
       end;
--PDB
    end,
    Done = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1164

      if self.dvAUF ~= nil then
        UnregisterView(self.dvAUF);
      end;
--PDB
    end,
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1171


      if self.dvAUF == nil then
        SetConstant("A", "FEHLER BEI DEN DATEN");
        return;
      end;

      -- Kopfdaten setzen
      local iLos = self.dvAUF:GetValue(0, "WAKOLOS", 0);
      SetConstant("A", BdeString(self.dvAUF:GetValue(0, "WAPONAME", nil), 60));
      SetConstant('B', BdeString(self.dvAUF:GetValue(0, "TEILTNR", nil), 10));
      SetConstant('C', BdeString(self.dvAUF:GetValue(0, "TEILNAME", nil), 40));
      SetConstant('D', StrFmt("{0,4}/{1,4}", { iLos, self.dvAUF:GetValue(0, "WAPOLIEGEM", 0) }));
      SetConstant('E', BdeString(self.dvAUF:GetValue(0, "TEILZNR", nil), 28));

      local iGutM = bde.dvAUD:GetValue(0, "AUDCURGUTM", 0);
      local iAusM = bde.dvAUD:GetValue(0, "AUDCURAUSM", 0);
      local iProbM = bde.dvAUD:GetValue(0, "AUDCURPROPM", 0);

      local iGutMSum = self.dvAUF:GetValue(0, "WAPOGUTM", 0);
      local iAusMSum = self.dvAUF:GetValue(0, "WAPOAUSSCH", 0);
      local iProbMSum = self.dvAUF:GetValue(0, "WAPOBRUNO", 0);

      SetConstant('F', StrFmt("{0:N0}", { iGutM }));
      SetConstant('G', StrFmt("{0:N0}", { iProbM }));
      SetConstant('H', StrFmt("{0:N0}", { iAusM }));

      SetConstant('I', StrFmt("{0:N0}", { iGutMSum }));
      SetConstant('J', StrFmt("{0:N0}", { iProbMSum }));
      SetConstant('K', StrFmt("{0:N0}", { iAusMSum }));

      SetConstant('L', StrFmt("{0:N0}", { iLos - (iGutMSum + iAusMSum + iProbMSum) }));

      UpdateHeader();
--PDB
    end,
    Trigger_VK_F1 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1210

      PushFormular(frmWAViewHelp, nil);
      return true;
--PDB
    end,
    Trigger_VK_F2 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1216

      StateProcedure(true, "pps.BdeMaMengeWA", { GUTM = 1, PROBM = nil, PROBCODE = nil, AUSM = nil, AUSCODE = nil });
      return true;
--PDB
    end,
    Trigger_VK_F3 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1223

      PushFormular(frmWAMengen, nil);
      return true;
--PDB
    end,
    Trigger_VK_F6 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1232

      StateProcedure(false, "pps.BdeMaChangeWA", { STATE = "R" });
      return true;
--PDB
    end,
    Trigger_VK_F7 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1239

      StateProcedure(false, "pps.BdeMaChangeWA", { STATE = "F" });
      return true;
--PDB
    end,
    Trigger_VK_F8 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1246

      StateProcedure(false, "pps.BdeMaChangeWA", { STATE = "N" });
      return true;
--PDB
    end,
    Trigger_VK_F9 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1253

      StateProcedure(false, "pps.BdeMaChangeWA", { STATE = "U" });
      return true;
--PDB
    end,
    Trigger_VK_F12 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1261

      StateProcedure(false, "pps.BdeMaEndeWA", { });
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmWAMengen
function __Form17__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1341

      UpdateHeader();
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1355

      PopFormular();
      return true;
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1361


      -- Lese die Variablen
      local iGutM = tonumber(GetVariable("0"));
      local iProbM = tonumber(GetVariable("1"));
      local iProbCode = tonumber(GetVariable("2"));
      local iAusM = tonumber(GetVariable("3"));
      local iAusCode = tonumber(GetVariable("4"));


      local sErr = StateProcedureSafe(true, "pps.BdeMaMengeWA", { GUTM = iGutM, PROBM = iProbM, PROBCODE = iProbCode, AUSM = iAusM, AUSCODE = iAusCode });
      if sErr == nil then
        PopFormular();
      else
        PushFormular(frmError, { sText = sErr });
      end;
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmWAViewHelp
function __Form18__()
  return {
    Trigger_VK_F1 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1405

      PopFormular();
      return true;
--PDB
    end,
    Trigger_VK_F2 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1411
      PopFormular();
--PDB
    end,
    Trigger_VK_F3 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1414
      PopFormular();
--PDB
    end,
    Trigger_VK_F5 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1418
      PopFormular();
--PDB
    end,
    Trigger_VK_F6 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1421
      PopFormular();
--PDB
    end,
    Trigger_VK_F7 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1424
      PopFormular();
--PDB
    end,
    Trigger_VK_F8 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1427
      PopFormular();
--PDB
    end,
    Trigger_VK_F9 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1430
      PopFormular();
--PDB
    end,
    Trigger_VK_F11 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1433
      PopFormular();
--PDB
    end,
    Trigger_VK_F12 = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1436
      PopFormular();
--PDB
    end,
    Trigger_VK_ESC = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1441

      PopFormular();
      return true;
--PDB
    end,
    Trigger_VK_RETURN = function (self, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1447

      PopFormular();
      return true;
--PDB
    end
  };
end;

--------------------------------------------------------------------------------
-- frmUserPause
function __Form19__()
  return {
    Refresh = function (self)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1496

      UpdateHeader();
--PDB
    end,
    Trigger = function (self, trigger, extra)
--PDB C:\Projects\DEServer\PPS\mod-server\PPS2000Mod\BDE\Sos\BDE.Kersten.xml,1501

      if trigger == VK_RFID then
        if StateProcedure(true, "pps.BdeMaToggleKey", { PAUSE = 1, PERSRFID = extra.Code }) then
          PopFormular();
        end;
        return true;
      elseif trigger == VK_RETURN or trigger == VK_ESC then
        PopFormular();
        return true;
      elseif trigger == VK_F4 then
        return true;
      end;
--PDB
    end
  };
end;

