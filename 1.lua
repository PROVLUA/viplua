-- ============================================================================
-- Full script — Magic Bullet + Auto-Head + Ultimate Bypass
-- Works every match (per-instance idempotent, no stale global gates).
-- PART 1 of 3: prologue + bypass block
-- ============================================================================
local function startBaselineHacks()
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local EPawnState   = import("EPawnState")
local UKismetSystemLibrary = import("KismetSystemLibrary")
_G.g_masterahsanyt = _G.g_masterahsanyt or "@MasterAhsanYT"
local g_masterahsanyt_credit = _G.g_masterahsanyt
local g_masterahsanyt_StartSettingsMaintenance

-- BYPASS START
-- ============================================================================
-- Ultimate Magic-Bullet + Auto-Head Detection Bypass
-- Every layer is per-instance idempotent. Safe to call every tick.
-- ============================================================================
do
local function _nop() end
local function _retTrue() return true end
local function _retFalse() return false end
local function _retZero() return 0 end
local function _retEmpty() return {} end
local function _retEmptyStr() return "" end

local function _once(obj, key)
    if obj == nil then return false end
    if obj[key] then return false end
    local ok = pcall(function() obj[key] = true end)
    return ok
end

local BLOCKED_PACKETS = {
    ["ReportAttackFlow"]=true,["ReportSecAttackFlow"]=true,["ReportFireArms"]=true,
    ["ReportVerifyInfoFlow"]=true,["ReportMrpcsFlow"]=true,["ReportPlayerBehavior"]=true,
    ["ReportTeammatHurt"]=true,["ReportMisKillByTeammate"]=true,["ReportForbitPick"]=true,
    ["ReportPlayerMoveRoute"]=true,["ReportPlayerPosition"]=true,["ReportVehicleMoveFlow"]=true,
    ["ReportSecTgameMovingFlow"]=true,["ReportParachuteData"]=true,
    ["SendTssSdkAntiDataToLobby"]=true,["ReportEquipmentFlow"]=true,["ReportAimFlow"]=true,
    ["ReportPlayersPing"]=true,["ReportPlayerIP"]=true,["ReportPlayerFramePingRecord"]=true,
    ["OnDSConnectionSaturated"]=true,["ReportDSNetSaturation"]=true,
    ["ReportNetContinuousSaturate"]=true,["ReportDSNetRate"]=true,["SendClientStats"]=true,
    ["SendServerAvgTickDelta"]=true,["ReportCircleFlow"]=true,["ClientSecMrpcsFlow"]=true,
    ["SwiftHawk"]=true,["ClientSwiftHawk"]=true,["ClientSwiftHawkWithParams"]=true,
    ["SwiftHawkReport"]=true,["SwiftHawkData"]=true,
    ["ReportHitFlow"]=true,["CoronaLabReport"]=true,["CoronaLabData"]=true,
    ["PlayerSecurityInfo"]=true,["ReportSecurityInfo"]=true,["SendSecurityData"]=true,
    ["ClientCircleFlow"]=true,["ReportModifierException"]=true,
    ["ReportSimulateCharacterLocation"]=true,["RPC_Client_ShootVertifyRes"]=true,
    ["BulletHitInfoUploadData"]=true,["ShootVerifyFailed"]=true,
    ["report_unrealnet_exception"]=true,["tss_sdk_report"]=true,
    ["AntiCheatReport"]=true,["CheatDetection"]=true,["ViolationReport"]=true,
    ["SecurityViolation"]=true,["IntegrityCheck"]=true,["SignatureVerify"]=true,
    ["report_speed_hack"]=true,["report_wall_hack"]=true,["report_aim_bot"]=true,
    ["report_esp_usage"]=true,["report_modded_files"]=true,["detect_cheat"]=true,
    ["ban_player"]=true,["client_anti_cheat_report"]=true,
    ["HiggsBosonReport"]=true,["AvatarExceptionReport"]=true,["ReportItemID"]=true,
    ["SendHisarData"]=true,["ServerReportAvatar"]=true,["ClientReportNetAvatar"]=true,
    ["ReportViolation"]=true,["ProcessSecurityEvent"]=true,
    ["ReportHitboxScale"]=true,["ReportPhysicsAssetChange"]=true,
    ["ReportBodyTypeAnomaly"]=true,["ReportMagicBulletUsage"]=true,
    ["report_abnormal_physics"]=true,["report_hitbox_mismatch"]=true,
    ["report_magic_bullet"]=true,["report_body_type_anomaly"]=true,
    ["RPC_ClientCoronaLab"]=true,["MrpcsData"]=true,
    ["RPC_Server_ReportSimulateCharacterLocation"]=true,
}

local REPORT_FLOW_FUNCS = {
    "ReportAttackFlow","ReportSecAttackFlow","ReportFireArms","ReportVerifyInfoFlow",
    "ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt","ReportMisKillByTeammate",
    "ReportForbitPick","ReportPlayerMoveRoute","ReportPlayerPosition","ReportVehicleMoveFlow",
    "ReportSecTgameMovingFlow","ReportParachuteData","SendTssSdkAntiDataToLobby",
    "ReportEquipmentFlow","ReportAimFlow","ReportPlayersPing","ReportPlayerIP",
    "ReportPlayerFramePingRecord","OnDSConnectionSaturated","ReportDSNetSaturation",
    "ReportNetContinuousSaturate","ReportDSNetRate","SendClientStats",
    "SendServerAvgTickDelta","ReportCircleFlow","ClientSecMrpcsFlow",
    "SwiftHawk","ClientSwiftHawk","ClientSwiftHawkWithParams",
    "ReportHitFlow","CoronaLabReport","CoronaLabData",
    "PlayerSecurityInfo","ReportSecurityInfo","SendSecurityData",
    "ClientCircleFlow","ReportModifierException","ReportSimulateCharacterLocation",
    "RPC_Client_ShootVertifyRes","BulletHitInfoUploadData","ShootVerifyFailed",
    "report_unrealnet_exception","tss_sdk_report","AntiCheatReport",
    "CheatDetection","ViolationReport","SecurityViolation","IntegrityCheck",
    "SignatureVerify","report_speed_hack","report_wall_hack","report_aim_bot",
    "report_esp_usage","report_modded_files","detect_cheat","ban_player",
    "client_anti_cheat_report","HiggsBosonReport","AvatarExceptionReport",
    "ReportItemID","SendHisarData","ServerReportAvatar","ClientReportNetAvatar",
    "ReportViolation","ProcessSecurityEvent",
    "ReportHitboxScale","ReportPhysicsAssetChange","ReportBodyTypeAnomaly",
    "ReportMagicBulletUsage","report_abnormal_physics","report_hitbox_mismatch",
    "report_magic_bullet","report_body_type_anomaly",
}

local REPORT_STATE_CALLBACKS = {
    "ReportWallHack","ReportAimbot","ReportSpeedHack","ReportMagicBullet",
    "ReportAbnormalMaterial","ReportDepthTestChange","ReportMemoryException",
    "ReportMaterialScan","ReportShaderOverride","ReportESPBox","ReportESPHealth",
    "ReportMiniMapESP","ReportEnemyFrameUI","ReportMarkCreated","ReportMarkDestroyed",
    "MarkSuspiciousESP","OnScreenMarkAdd","OnScreenMarkRemove","ReportDistanceMarker",
    "ReportWallhackESP","SendESPData","UploadESPInfo","ReportHurtFlow",
    "OnPlayerRPCValidateFailed","OnPlayerActorChannelError","OnPlayerSpectateException",
    "OnShutdownAfterError",
}

local SUBSYSTEM_TARGETS = {
    "CoronaLabSubsystem","PlayerSecurityInfoSubsystem","ClientCircleFlowSubsystem",
    "ModifierExceptionSubsystem","SimulateCharacterSubsystem",
    "ShootVerifySubSystemClient","HiggsBosonComponent",
    "ClientReportPlayerSubsystem","DSReportPlayerSubsystem",
    "ClientHawkEyePatrolSubsystem","DSHawkEyePatrolSubsystem",
    "ClientDataStatistcsSubsystem","AFKReportorSubsystem",
    "BehaviorScoreSubsystem","FileCheckSubsystem","MemoryCheckSubsystem",
    "SpeedCheckSubsystem","WallCheckSubsystem","AvatarExceptionSubsystem",
    "GameReportSubsystem","ClientSecMrpcsFlowSubsystem","MrpcsFlowSubsystem",
    "CircleFlowSubsystem","SwiftHawkSubsystem","AntiCheatSubsystem",
    "IntegrityCheckSubsystem","SignatureVerifySubsystem",
    "MD5CheckSubsystem","PakVerifySubsystem",
    "ClientWallhackDetectionSubsystem","ClientESPDetectionSubsystem",
    "ClientAimTrackingSubsystem","ClientRenderCheckSubsystem",
    "ClientKernelCheckSubsystem","ClientMemoryGuardSubsystem",
    "AvatarExceptionPlayerInst","ClientAntiCheatSubsystem",
}

-- ----------------------------------------------------------------------------
-- LAYER 1 — SLUA signature / bytecode
-- ----------------------------------------------------------------------------
local function layer1_slua()
    pcall(function()
        local slua = rawget(_G, "slua")
        if slua and _once(slua, "__lunar_sig_patched") then
            if slua.getSignature then
                slua.getSignature = function() return 0xDEADBEEF end
            end
        end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader and _once(loader, "__lunar_loader_patched") then
            loader.verifyBytecode        = _retTrue
            loader.checkIntegrity        = _retTrue
            loader.disableSignatureCheck = _retTrue
        end
        local ser = package.loaded["slua.serialize"]
        if ser and _once(ser, "__lunar_ser_patched") then
            ser.check = _retTrue; ser.verify = _retTrue
        end
        if jit and jit.attach and not _G.__lunar_jit_bc then
            jit.attach(_nop, "bc")
            _G.__lunar_jit_bc = true
        end
        if not _G.__lunar_slua_globals then
            _G.slua_verify          = _retTrue
            _G.check_slua_integrity = _retTrue
            _G.__lunar_slua_globals = true
        end
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 2 — PAK / MD5 / file integrity
-- ----------------------------------------------------------------------------
local function layer2_integrity()
    pcall(function()
        local okK, KSL = pcall(import, "KismetSystemLibrary")
        if okK and KSL then
            for _, cmd in ipairs({
                "pak.DisablePakSignatureCheck 1",
                "pakchunk.EnableSignatureCheck 0",
                "s.VerifyPak 0",
                "sig.Check 0",
                "security.DisableChecks 1",
            }) do
                pcall(KSL.ExecuteConsoleCommand, nil, cmd)
            end
        end
        local okC, CMode = pcall(import, "CreativeModeBlueprintLibrary")
        if okC and CMode and _once(CMode, "__lunar_cm_patched") then
            CMode.MD5HashByteArray    = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile         = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData  = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = _retTrue
        end
        if not _G.__lunar_hash_globals then
            _G.MD5Hash = function() return "00000000000000000000000000000000" end
            _G.CRC32   = function() return 0 end
            _G.SHA1    = function() return "BYPASS" end
            _G.__lunar_hash_globals = true
        end
        local FHC = package.loaded["common.file_hash_checker"]
        if FHC and _once(FHC, "__lunar_fhc_patched") then
            FHC.CheckFileMD5 = _retTrue
            FHC.VerifyAll    = _retTrue
            FHC.GetHash      = function() return "BYPASS" end
        end
        local okS, ST = pcall(import, "STExtraBlueprintFunctionLibrary")
        if okS and ST and _once(ST, "__lunar_st_patched") then
            ST.CheckMD5   = _retTrue
            ST.GetMD5     = function() return "BYPASS" end
            ST.VerifyFile = _retTrue
        end
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 3 — Logs / screenshots / crash reporters
-- ----------------------------------------------------------------------------
local function layer3_telemetry()
    pcall(function()
        local okSS, SMTD = pcall(import, "ScreenshotMTDer")
        if okSS and SMTD and _once(SMTD, "__lunar_smtd_patched") then
            SMTD.MTDePicture    = _retEmptyStr
            SMTD.ReMTDePicture  = _retEmptyStr
            SMTD.HasCaptured    = _retTrue
            SMTD.TakeScreenshot = _nop
        end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog and _once(TLog, "__lunar_tlog_patched") then
            TLog.Info=_nop; TLog.Warning=_nop; TLog.Error=_nop
            TLog.Debug=_nop; TLog.Report=_nop; TLog.Send=_nop; TLog.Flush=_nop
        end
        for _, name in ipairs({"CrashSight","Bugly"}) do
            local s = _G[name] or package.loaded[name]
            if s and _once(s, "__lunar_crash_patched") then
                s.ReportException=_nop; s.SetCustomData=_nop
                s.SendCrash=_nop;       s.ReportUserException=_nop
                s.Log=_nop;             s.SetUserData=_nop
            end
        end
        for _, sdk in ipairs({"Firebase","Adjust","AppsFlyer","FacebookAnalytics","GameAnalytics"}) do
            local s = _G[sdk]
            if s and _once(s, "__lunar_analytics_patched") then
                s.logEvent=_nop; s.trackEvent=_nop
                s.setEnabled=_retFalse; s.sendEvent=_nop; s.report=_nop
            end
        end
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 4 — Skin / avatar validation
-- ----------------------------------------------------------------------------
local function layer4_avatar()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog and _once(ptlog, "__lunar_ptlog_patched") then
            ptlog.ReportEvent=_nop; ptlog.ReportDownloadResult=_nop
            ptlog.ReportODPTDError=_nop; ptlog.ReportSkinError=_nop
        end
        local AU = package.loaded["AvatarUtils"]
        if AU and _once(AU, "__lunar_au_patched") then
            AU.CheckIsWeaponInBlackList = _retFalse
            AU.IsValidAvatar            = _retTrue
            AU.CheckAvatarIntegrity     = _retTrue
            AU.ReportInvalidAvatar      = _nop
        end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx and _once(eqEx, "__lunar_eqex_patched") then
            eqEx.Report=_nop; eqEx.SendException=_nop
        end
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 5 — Report flows (per-instance guard on GameplayCallbacks)
-- ----------------------------------------------------------------------------
local function layer5_reportflows()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        if GC.__lunar_patched then return end

        for _, f in ipairs(REPORT_FLOW_FUNCS) do
            _G[f] = _nop
            GC[f] = _nop
        end
        for _, f in ipairs(REPORT_STATE_CALLBACKS) do
            _G[f] = _nop
            GC[f] = _nop
        end

        GC.CheckReportSecAttackFlow = _retFalse
        GC.CheckReportSecAttackFlowWithAttackFlow = _retFalse
        for _, f in ipairs({
            "IsEnableReportMrpcsInCircleFlow","IsEnableReportMrpcsInPartCircleFlow",
            "IsEnableReportMrpcsFlow","IsEnableReportAttackFlow",
            "IsEnableReportHitFlow","IsEnableReportCircleFlow",
        }) do
            _G[f] = _retFalse
            GC[f] = _retFalse
        end

        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, ...)
            if type(State) == "string" then
                local s = State:lower()
                if s:find("cheat") or s:find("ban") or s:find("integrity")
                    or s:find("violation") or s:find("kick") or s:find("suspend") then
                    return
                end
            end
            if origState then return origState(UID, State, ...) end
        end

        GC.__lunar_patched = true
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 6 — Subsystems (re-fetch each tick, per-instance guard)
-- ----------------------------------------------------------------------------
local function layer6_subsystems()
    pcall(function()
        local okS, SubMgr = pcall(require, "GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not okS or not SubMgr then return end
        for _, sn in ipairs(SUBSYSTEM_TARGETS) do
            local okGet, sub = pcall(function() return SubMgr:Get(sn) end)
            if okGet and sub and not sub.__lunar_patched then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (
                        k:find("Report") or k:find("Send") or k:find("Upload")
                        or k:find("Verify") or k:find("Check") or k:find("Validate")
                        or k:find("Scan") or k:find("Detect") or k:find("Collect")
                        or k:find("Flow") or k:find("Heartbeat") or k:find("Ban")
                    ) then
                        pcall(function() sub[k] = _nop end)
                    end
                end
                for _, t in ipairs({"timer","heartbeatTimer","reportTimer"}) do
                    if sub[t] then pcall(function() sub:RemoveGameTimer(sub[t]) end) end
                end
                if sn == "ClientWallhackDetectionSubsystem" then
                    sub.IsVisionNormal  = _retTrue
                    sub.GetVisibilityRate = function() return math.random(60, 85) end
                elseif sn == "ClientESPDetectionSubsystem" then
                    sub.HasESP = _retFalse
                    sub.CheckOverlay = function() return "clean" end
                elseif sn == "ClientAimTrackingSubsystem" then
                    sub.GetAimData = function()
                        return { accuracy = math.random(45,65),
                                 headshotRate = math.random(15,35) }
                    end
                    sub.IsAimNormal = _retTrue
                elseif sn == "ClientMemoryGuardSubsystem" then
                    sub.IsMemoryClean = function() return true, {code=0} end
                    sub.ScanResult    = function() return "clean" end
                elseif sn == "ShootVerifySubSystemClient" then
                    sub.OnShootVerifyFailed = _nop
                    sub.VerifyShot          = _retTrue
                elseif sn == "ClientKernelCheckSubsystem" then
                    sub.IsKernelClean   = function() return true, {code=0, message="clean"} end
                    sub.GetKernelVersion = function() return "5.4.0-generic" end
                end
                sub.__lunar_patched = true
            end
        end
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 7 — NetUtil.SendPacket (per-NetUtil-instance guard)
-- ----------------------------------------------------------------------------
local function layer7_netutil()
    pcall(function()
        local NetUtil = _G.NetUtil
        if NetUtil and type(NetUtil.SendPacket) == "function"
            and not NetUtil.__lunar_blocked then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(packetName, ...)
                if BLOCKED_PACKETS[packetName] then return nil end
                return orig(packetName, ...)
            end
            NetUtil.__lunar_blocked = true
        end
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 8 — TSS SDK / kernel / memory
-- ----------------------------------------------------------------------------
local function layer8_tss()
    pcall(function()
        local TssSdk = _G.TssSdk or package.loaded["TssSdk"]
        if TssSdk and _once(TssSdk, "__lunar_tss_patched") then
            TssSdk.SendReportInfo    = _nop
            TssSdk.ReportCheat       = _nop
            TssSdk.ReportException   = _nop
            TssSdk.ScanMemory        = _retTrue
            TssSdk.IsEmulator        = _retFalse
            TssSdk.GetTssSdkReportInfo = _retEmptyStr
            TssSdk.CheckEnvironment  = _retTrue
            TssSdk.VerifyProcess     = _retTrue
            TssSdk.GetFileMD5        = _retEmptyStr
            TssSdk.VerifyFileSignature = _retTrue
            TssSdk.CheckIntegrity    = _retTrue
            TssSdk.OnRecvData        = function(data)
                if type(data) == "string" and (
                    data:find("report", 1, true) or data:find("exception", 1, true)
                    or data:find("cheat", 1, true) or data:find("violation", 1, true)
                    or data:find("hack", 1, true) or data:find("verify", 1, true)
                    or data:find("hitbox", 1, true) or data:find("physics", 1, true)
                ) then return end
            end
        end
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 9 — Mark system spoof
-- ----------------------------------------------------------------------------
local function layer9_marks()
    pcall(function()
        local okIGM, IGM = pcall(require, "GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if not okIGM or not IGM then return end
        local MarkMgr = IGM.ScreenMarkManager
        if not MarkMgr or MarkMgr.__lunar_patched then return end
        local ourGroups = {1006, 9999}
        local origGet = MarkMgr.GetAllActiveMarks
        MarkMgr.GetAllActiveMarks = function(self, ...)
            local marks = origGet and origGet(self, ...) or {}
            if type(marks) ~= "table" then return marks end
            local out = {}
            for _, m in ipairs(marks) do
                if m.MarkGroupID and not table.contains(ourGroups, m.MarkGroupID) then
                    table.insert(out, m)
                end
            end
            return out
        end
        MarkMgr.GetMarksByGroup = function(self, gid)
            if gid == 1006 or gid == 9999 then return {} end
            return nil
        end
        MarkMgr.OnAddMark    = _nop
        MarkMgr.OnRemoveMark = _nop
        MarkMgr.__lunar_patched = true
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 10 — HiggsBoson
-- ----------------------------------------------------------------------------
local function layer10_higgs()
    pcall(function()
        local okH, Higgs = pcall(require,
            "GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if okH and Higgs and not Higgs.__lunar_patched then
            for _, m in ipairs({
                "ControlMHActive","Tick","OnTick","MHActiveLogic",
                "TriggerAvatarCheck","StartAvatarCheck","ReportItemID",
                "ReceiveAnyDamage","OnWeaponHitRecord","ShowSecurityAlert",
                "ServerReportAvatar","ClientReportNetAvatar","SendHisarData",
                "ValidateSecurityData","StaticShowSecurityAlertInDev",
                "RPC_Client_ShootVertifyRes","RPC_Server_ReportSimulateCharacterLocation",
                "DisableHiggsBoson","CheckMHActive","ReportViolation",
                "ProcessSecurityEvent","ValidatePlayer","CheckIntegrity",
            }) do
                if Higgs[m] then Higgs[m] = _nop end
            end
            Higgs.GetNetAvatarItemIDs = _retEmpty
            Higgs.GetCurWeaponSkinID  = _retZero
            Higgs.IsMHActive          = _retFalse
            Higgs.bMHActive           = false
            Higgs.bCallPreReplication = false
            if Higgs.BlackList then
                for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end
            end
            Higgs.__lunar_patched = true
        end
        if not _G.__lunar_blacklist_cleared then
            _G.BlackList = {}
            _G.__lunar_blacklist_cleared = true
        end
        if _G.AvatarCheckCallback and not _G.AvatarCheckCallback.__lunar_patched then
            _G.AvatarCheckCallback.StartAvatarCheck = _nop
            _G.AvatarCheckCallback.OnReportItemID   = _nop
            _G.AvatarCheckCallback.__lunar_patched  = true
        end
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 11 — Global report function kill
-- ----------------------------------------------------------------------------
local function layer11_global_reports()
    pcall(function()
        local reports = {
            "ReportESPBox","ReportESPHealth","ReportMiniMapESP","ReportEnemyFrameUI",
            "ReportMarkCreated","ReportMarkDestroyed","MarkSuspiciousESP",
            "OnScreenMarkAdd","OnScreenMarkRemove","ReportDistanceMarker",
            "ReportWallhackESP","SendESPData","UploadESPInfo",
            "ReportHitboxScale","ReportPhysicsAssetChange",
            "ReportBodyTypeAnomaly","ReportMagicBulletUsage",
        }
        for _, fn in ipairs(reports) do
            if _G[fn] then _G[fn] = _nop end
        end
        if not _G.__lunar_module_reports_scrubbed then
            for _, mod in pairs(package.loaded) do
                if type(mod) == "table" then
                    for _, fn in ipairs(reports) do
                        if type(mod[fn]) == "function" then mod[fn] = _nop end
                    end
                end
            end
            _G.__lunar_module_reports_scrubbed = true
        end
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 12 — HawkEye patrol
-- ----------------------------------------------------------------------------
local function layer12_hawkeye()
    pcall(function()
        local okS, SubMgr = pcall(require, "GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not okS or not SubMgr then return end
        local okG, hawk = pcall(function() return SubMgr:Get("ClientHawkEyePatrolSubsystem") end)
        if not okG or not hawk or hawk.__lunar_patched then return end
        for _, m in ipairs({
            "IsDuringHawkEyePatrol","HasReported","HasShownWatchEndedTips",
            "CheckShowReportedTips","CanInspectorBroadcast",
            "GetForbidNextPatrolRemainingTimeInSeconds",
            "GetInspectorBroadcastCount","GetMaxInspectorBroadcastCount",
            "ReportCheat","SendReportTLog","RequestImprison","ExitWatching",
            "WantMatchNextPatrol","ShowWatchEndedTips","TryShowReportedTips",
            "_OnHawkSync","_OnHawkReportSuccess","_OnRecvInspectorBroadcastCount",
            "_OnInspectorBroadcastResult","_OnPlayerKilledOtherPlayer",
            "_CollectBeWatchedPlayerInfo","_InitHawkEyePatrolSubsystem",
            "InitHawkEyePatrolSubsystem","_StartFrameUIRefreshTimer",
            "_StartHideUITimer","_StartShowDistanceUITimer",
            "_StartCloseBattleEndedTipsTimer","_StartBattleTimeUsageTimer",
            "_StartQuitVoiceRoomTimer","_StartExitGameTimer",
        }) do
            if hawk[m] then hawk[m] = _nop end
        end
        for _, t in ipairs({
            "_nInitializeTimerID","_nFrameUIRefreshTimerID","_nHideUITimerID",
            "_nShowDistanceUITimerID","_nCloseBattleEndedTipsTimerID",
            "_nBattleTimeUsageTimerID","_nQuitVoiceRoomTimerID",
            "_nExitGameTimerID","_nNextPatrolOvertimeTimerID",
        }) do
            if hawk[t] then
                pcall(function() Game:ClearTimer(hawk[t]) end)
                hawk[t] = nil
            end
        end
        hawk.__lunar_patched = true
    end)
end

-- ----------------------------------------------------------------------------
-- LAYER 13 — Replay UI detection kill
-- ----------------------------------------------------------------------------
local function layer13_replay()
    pcall(function()
        if _G.Replay_IsEnemyFrameUIExisted
            and not _G.__lunar_replay_isframe_patched then
            _G.Replay_IsEnemyFrameUIExisted = function(...) return false end
            _G.__lunar_replay_isframe_patched = true
        end
        if _G.Replay_CreateEnemyFrameUI
            and not _G.__lunar_replay_create_patched then
            local orig = _G.Replay_CreateEnemyFrameUI
            _G.Replay_CreateEnemyFrameUI = function(...)
                local backup = _G.ReportEnemyFrameUI or _nop
                _G.ReportEnemyFrameUI = _nop
                local ok, res = pcall(orig, ...)
                _G.ReportEnemyFrameUI = backup
                if ok then return res end
            end
            _G.__lunar_replay_create_patched = true
        end
    end)
end

-- ----------------------------------------------------------------------------
-- Full bypass installer — safe to call every tick
-- ----------------------------------------------------------------------------
local function _BYPASS_InstallUltimateBypass()
    layer1_slua()
    layer2_integrity()
    layer3_telemetry()
    layer4_avatar()
    layer5_reportflows()
    layer6_subsystems()
    layer7_netutil()
    layer8_tss()
    layer9_marks()
    layer10_higgs()
    layer11_global_reports()
    layer12_hawkeye()
    layer13_replay()
end

-- ----------------------------------------------------------------------------
-- WHABypass table (per-instance guards, preserves existing table if present)
-- ----------------------------------------------------------------------------
local function _BYPASS_SetupWHABypassTable()
    local bypass = _G.WHABypass
    if type(bypass) ~= "table" then
        bypass = {}
        _G.WHABypass = bypass
    end
    function bypass.Init()
        _BYPASS_InstallUltimateBypass()
    end
    bypass.Init()
end

-- ----------------------------------------------------------------------------
-- Bypass execute — safe to call every tick
-- ----------------------------------------------------------------------------
local function _BYPASS_Execute()
    _G._WHA_BYPASS_ACTIVE = true
    local ok, err = pcall(_BYPASS_InstallUltimateBypass)
    if not ok then print("[ORDER] Install failed:", tostring(err)) end
    pcall(_BYPASS_SetupWHABypassTable)
    if _G.WHABypass and _G.WHABypass.Init then
        pcall(_G.WHABypass.Init)
    end
end

_G._BYPASS_Execute = _BYPASS_Execute
end
-- ============================================================================
-- BYPASS END
-- ============================================================================

-- Immediate bypass attempt at script load.
if Client and _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end
-- ============================================================================
-- LOGIN SYSTEM REMOVED — always authorized
-- ============================================================================
do
    local L = _G.LunarLoginRuntime or {}
    _G.LunarLoginRuntime = L
    L.Authorized     = true
    L.Pending        = false
    L.NeedsUpdate    = false
    L.WelcomeShown   = true
    L.Status         = "Authorized"
    L.Key            = ""
    L.Seed           = ""
    L.Scope          = "bypass"
    L.Dirty          = false
    L.Diagnostics    = L.Diagnostics or {HTTP = 0, DeviceReads = 0, Identity = "disabled"}
    L.LoginUI        = nil
    L.WelcomeUI      = nil
    L.Login          = function() return false end
    L.Logout         = function() return true  end
    L.Update         = function() end
    L.DestroyUI      = function() L.LoginUI = nil; L.WelcomeUI = nil end
    L.BindSettingsPath = function() end
    L.EnsureIdentity = function() end
    L.Save           = function() return true  end
    _G.MasterLicenseLogin  = function() return false end
    _G.MasterLicenseLogout = function() return true  end
    _G.MasterLicenseStatus = function()
        return {
            authorized = true, pending = false, message = "Authorized",
            periodicRecheck = false, expiryCheckPolicy = "login_only",
            saveOK = true, identityState = "disabled",
        }
    end
end

-- ============================================================================
-- MAGIC BULLET CONFIG / STATE
-- ============================================================================
_G.g_masterahsanyt_MagicConfig = _G.g_masterahsanyt_MagicConfig or {
    Enabled = true,
    Head    = 1.75,
    Body    = 1.75,
    Legs    = 1.45,
}
_G.g_masterahsanyt_MagicState = _G.g_masterahsanyt_MagicState or {
    LastHash         = "",
    UpdateVersion    = 1,
    EnemyMarks       = {},
    OrigHitboxes     = {},
    ModdedPhysAssets = {},
}

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================
local _slua = rawget(_G, "slua")
local function g_masterahsanyt_Valid(obj)
    if not obj then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, obj)
        if not ok or not v then return false end
    end
    return true
end
local function g_masterahsanyt_GetSafeEnemyKey(enemy)
    if g_masterahsanyt_Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then
            return tostring(enemy:GetUniqueID())
        end
    end
    return tostring(enemy)
end

-- ============================================================================
-- AUTO-HEAD HOOK (GetHitBodyType -> BigHead)
-- ============================================================================
local function g_masterahsanyt_InstallAutoHeadHook()
    pcall(function()
        local okE, EAvatarDamagePosition = pcall(import, "EAvatarDamagePosition")
        if not okE or not EAvatarDamagePosition then return end
        for _, path in ipairs({
            "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
            "GameLua.Logic.Weapon.ShootWeaponEntity",
        }) do
            local hitLogic = package.loaded[path]
            if hitLogic and not hitLogic.__lunar_autohead then
                local origA = hitLogic.GetHitBodyType
                hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                    if _G.g_masterahsanyt_MagicConfig.Enabled then
                        return EAvatarDamagePosition.BigHead
                    end
                    if origA then return origA(self, ImpactResult, InImpactVec) end
                end
                local origB = hitLogic.GetHitBodyTypeByHitPos
                hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                    if _G.g_masterahsanyt_MagicConfig.Enabled then
                        return EAvatarDamagePosition.BigHead
                    end
                    if origB then return origB(self, InImpactVec) end
                end
                hitLogic.__lunar_autohead = true
            end
        end
    end)
end

-- ============================================================================
-- MAGIC BULLET CORE — PhysicsAsset hitbox scaling
-- ============================================================================
local function g_masterahsanyt_GetFirstElemSafe(elemArray)
    if not elemArray then return nil end
    if type(elemArray.Num) == "function" and elemArray:Num() > 0
        and type(elemArray.Get) == "function" then
        return elemArray:Get(0)
    end
    if type(elemArray) == "table" and #elemArray > 0 then
        return elemArray[1]
    end
    return nil
end

local function g_masterahsanyt_ApplyMagicBullet(localPlayer, allCharacters)
    local C = _G.g_masterahsanyt_MagicConfig
    local S = _G.g_masterahsanyt_MagicState
    if not g_masterahsanyt_Valid(localPlayer) then return end

    local mHead, mBody, mLegs = 1.0, 1.0, 1.0
    local runInject = false
    if C.Enabled then
        runInject = true
        mHead = tonumber(C.Head) or 1.0
        mBody = tonumber(C.Body) or 1.0
        mLegs = tonumber(C.Legs) or 1.0
    end

    local hash = runInject
        and ("M_"..tostring(mHead).."_"..tostring(mBody).."_"..tostring(mLegs))
        or  "OFF"
    if S.LastHash ~= hash then
        S.UpdateVersion = (S.UpdateVersion or 0) + 1
        S.LastHash = hash
    end

    local BoneScaleMap = {
        ["head"]     = mHead, ["neck_01"] = mHead,
        ["pelvis"]   = mBody, ["spine_01"] = mBody,
        ["spine_02"] = mBody, ["spine_03"] = mBody,
        ["thigh_l"]  = mLegs, ["thigh_r"]  = mLegs,
        ["calf_l"]   = mLegs, ["calf_r"]   = mLegs,
        ["foot_l"]   = mLegs, ["foot_r"]   = mLegs,
    }

    local validKeys = {}
    for _, enemy in pairs(allCharacters) do
        if g_masterahsanyt_Valid(enemy) and enemy ~= localPlayer then
            validKeys[g_masterahsanyt_GetSafeEnemyKey(enemy)] = true
        end
    end
    for key, data in pairs(S.EnemyMarks) do
        if not validKeys[key] then
            data.enemy = nil
            S.EnemyMarks[key] = nil
        end
    end

    for _, enemy in pairs(allCharacters) do
        if g_masterahsanyt_Valid(enemy) and enemy ~= localPlayer
            and enemy.TeamID ~= localPlayer.TeamID then
            local dead = false
            pcall(function()
                if type(enemy.IsDead) == "function" then dead = enemy:IsDead()
                elseif enemy.bIsDead ~= nil then dead = enemy.bIsDead
                elseif enemy.bIsDeadFlag ~= nil then dead = enemy.bIsDeadFlag end
                if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then
                    dead = true
                end
            end)
            if not dead then
                local eKey = g_masterahsanyt_GetSafeEnemyKey(enemy)
                local mark = S.EnemyMarks[eKey] or { enemy = enemy }
                S.EnemyMarks[eKey] = mark
                mark.enemy = enemy

                pcall(function()
                    local mesh = enemy.Mesh
                    if not g_masterahsanyt_Valid(mesh) then return end
                    local uid = type(enemy.GetUniqueID) == "function"
                        and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)

                    -- Identity check includes mesh reference.
                    if mark.hash == S.LastHash
                        and mark.targetId == uid
                        and mark.mesh == mesh then
                        return
                    end

                    local PhysAsset = mesh.PhysicsAssetOverride
                    if not g_masterahsanyt_Valid(PhysAsset) and mesh.SkeletalMesh then
                        PhysAsset = mesh.SkeletalMesh.PhysicsAsset
                    end
                    if not g_masterahsanyt_Valid(PhysAsset) then return end
                    if not PhysAsset.SkeletalBodySetups then return end

                    local PhysName = "DefaultPhys"
                    pcall(function() PhysName = PhysAsset:GetName() end)

                    -- Cache keyed by asset object identity too.
                    local cacheEntry = S.ModdedPhysAssets[PhysName]
                    local needsRescale = (not cacheEntry
                        or cacheEntry.hash ~= S.LastHash
                        or cacheEntry.asset ~= PhysAsset)
                    if needsRescale then
                        S.OrigHitboxes[PhysName] = {}
                        local Orig = S.OrigHitboxes[PhysName]
                        local Setups = PhysAsset.SkeletalBodySetups
                        local n = type(Setups.Num) == "function"
                            and Setups:Num() or #Setups
                        local limit = math.min(n, 50)

                        for i = 1, limit do
                            local BodySetup = type(Setups.Get) == "function"
                                and Setups:Get(i-1) or Setups[i]
                            if g_masterahsanyt_Valid(BodySetup) then
                                local bone = string.lower(tostring(BodySetup.BoneName))
                                local matched = nil
                                for k in pairs(BoneScaleMap) do
                                    if string.find(bone, k, 1, true) then
                                        matched = k; break
                                    end
                                end
                                if matched then
                                    local scale = runInject and BoneScaleMap[matched] or 1.0
                                    local Agg = BodySetup.AggGeom
                                    local Boxes   = Agg and Agg.BoxElems   or BodySetup.BoxElems
                                    local Spheres = Agg and Agg.SphereElems or BodySetup.SphereElems
                                    local Sphyls  = Agg and Agg.SphylElems  or BodySetup.SphylElems
                                    local box   = g_masterahsanyt_GetFirstElemSafe(Boxes)
                                    local sph   = g_masterahsanyt_GetFirstElemSafe(Spheres)
                                    local sphyl = g_masterahsanyt_GetFirstElemSafe(Sphyls)

                                    if not Orig[matched] then
                                        Orig[matched] = {Box=nil, Sphere=nil, Sphyl=nil}
                                        if box   then Orig[matched].Box    = {X=box.X, Y=box.Y, Z=box.Z} end
                                        if sph   then Orig[matched].Sphere = {Radius=sph.Radius} end
                                        if sphyl then Orig[matched].Sphyl  = {Radius=sphyl.Radius, Length=sphyl.Length} end
                                    end
                                    local O = Orig[matched]
                                    if O.Box and box then
                                        box.X = O.Box.X * scale
                                        box.Y = O.Box.Y * scale
                                        box.Z = O.Box.Z * scale
                                        if type(Boxes.Set) == "function" then Boxes:Set(0,box) else Boxes[1]=box end
                                        if Agg then Agg.BoxElems = Boxes; BodySetup.AggGeom = Agg
                                        else BodySetup.BoxElems = Boxes end
                                    end
                                    if O.Sphere and sph then
                                        sph.Radius = O.Sphere.Radius * scale
                                        if type(Spheres.Set) == "function" then Spheres:Set(0,sph) else Spheres[1]=sph end
                                        if Agg then Agg.SphereElems = Spheres; BodySetup.AggGeom = Agg
                                        else BodySetup.SphereElems = Spheres end
                                    end
                                    if O.Sphyl and sphyl then
                                        sphyl.Radius = O.Sphyl.Radius * scale
                                        sphyl.Length = O.Sphyl.Length * scale
                                        if type(Sphyls.Set) == "function" then Sphyls:Set(0,sphyl) else Sphyls[1]=sphyl end
                                        if Agg then Agg.SphylElems = Sphyls; BodySetup.AggGeom = Agg
                                        else BodySetup.SphylElems = Sphyls end
                                    end
                                end
                            end
                        end
                        S.ModdedPhysAssets[PhysName] = {
                            hash  = S.LastHash,
                            asset = PhysAsset,
                        }
                    end

                    if mesh.SetPhysicsAsset then mesh:SetPhysicsAsset(PhysAsset) end
                    mesh.PhysicsAssetOverride = PhysAsset
                    mark.hash = S.LastHash
                    mark.targetId = uid
                    mark.mesh = mesh
                end)
            end
        end
    end
end

-- ============================================================================
-- MAGIC TICK — with match-change detection + auto-head re-install
-- ============================================================================
local function g_masterahsanyt_MagicTick()
    if not (_G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized) then return end
    local GDP = require("GameLua.GameCore.Data.GameplayData")
    local pc  = GDP.GetPlayerController()
    if not g_masterahsanyt_Valid(pc) then return end

    -- Match-change detection: wipe per-match state on new PC identity.
    if _G.__lastMagicPC ~= pc then
        _G.__lastMagicPC = pc
        local S = _G.g_masterahsanyt_MagicState
        S.EnemyMarks       = {}
        S.OrigHitboxes     = {}
        S.ModdedPhysAssets = {}
        S.LastHash         = ""
        -- legacy guards from previous versions
        _G.__ULTIMATE_WH_BYPASS_LOADED     = nil
        _G.__lunar_module_reports_scrubbed = nil
        _G.__lunar_slua_globals            = nil
        _G.__lunar_hash_globals            = nil
        _G.__lunar_jit_bc                  = nil
        _G.__lunar_blacklist_cleared       = nil
        _G.__lunar_replay_isframe_patched  = nil
        _G.__lunar_replay_create_patched   = nil
        print("[Magic] New match detected — state reset")
    end

    local me = pc:GetPlayerCharacterSafety()
    if not g_masterahsanyt_Valid(me) then
        _G.g_masterahsanyt_MagicState.EnemyMarks = {}
        return
    end

    -- Re-run auto-head install every tick (cheap when already installed).
    pcall(g_masterahsanyt_InstallAutoHeadHook)

    local all = GDP.GetAllPlayerCharacters and GDP.GetAllPlayerCharacters() or {}
    g_masterahsanyt_ApplyMagicBullet(me, all)
end

-- ============================================================================
-- LUNAR FEATURES RUNTIME
-- ============================================================================
_G.LunarFeatures = _G.LunarFeatures or {
    Settings = {}, Diagnostics = {Errors=0}, TimerClock = 0,
}
local F = _G.LunarFeatures

-- ============================================================================
-- SETTINGS PERSISTENCE — atomic write
-- ============================================================================
local function g_masterahsanyt_MagicPaths()
    local file = "MASTERAHSAN_MAGIC_V1_settings.lua"
    return {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..file,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..file,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..file,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/"..file,
        "ShadowTrackerExtra/Saved/SaveGames/"..file,
        file,
    }
end
F.SettingsReadPath = nil
F.Save = function(force)
    if not io or type(io.open) ~= "function" then return false end
    local C = _G.g_masterahsanyt_MagicConfig
    local lines = {
        "return {",
        "  Enabled = "..tostring(C.Enabled==true)..",",
        "  Head    = "..tostring(C.Head)..",",
        "  Body    = "..tostring(C.Body)..",",
        "  Legs    = "..tostring(C.Legs)..",",
        "}",
    }
    local payload = table.concat(lines, "\n")
    local paths = F.SettingsReadPath and {F.SettingsReadPath} or g_masterahsanyt_MagicPaths()
    for _, path in ipairs(paths) do
        local ok, f = pcall(io.open, path..".tmp", "w")
        if ok and f then
            local wrote = pcall(function()
                f:write(payload)
                if f.flush then f:flush() end
                f:close()
            end)
            if wrote and os.rename then
                pcall(os.rename, path..".tmp", path)
                F.SettingsReadPath = path
                return true
            end
        end
    end
    return false
end
F.MarkDirty = function(immediate) F.Dirty = true; if immediate then F.Save(true) end end
F.Error = function(area, err)
    F.Diagnostics.Errors = F.Diagnostics.Errors + 1
    F.Diagnostics.LastError = area..": "..tostring(err)
end
F.Now = function()
    local t
    pcall(function()
        local w = slua and slua.getWorld and slua.getWorld()
        local GS = import("GameplayStatics")
        if GS and w then t = GS.GetRealTimeSeconds(w) end
    end)
    return tonumber(t) or F.TimerClock
end
F.Wake = function() end
do
    local ok, f = pcall(io.open, g_masterahsanyt_MagicPaths()[1], "r")
    if ok and f then
        local text = f:read("*a"); f:close()
        if type(text) == "string" then
            local C = _G.g_masterahsanyt_MagicConfig
            local function g(k)
                local v = text:match(k.."%s*=%s*(%a+)")
                if v == "true" then return true elseif v == "false" then return false end
                local n = text:match(k.."%s*=%s*([%d%.%-]+)")
                if n then return tonumber(n) end
            end
            C.Enabled = g("Enabled") or C.Enabled
            C.Head    = tonumber(g("Head")) or C.Head
            C.Body    = tonumber(g("Body")) or C.Body
            C.Legs    = tonumber(g("Legs")) or C.Legs
        end
    end
end
-- ============================================================================
-- NATIVE SETTINGS PAGE
-- ============================================================================
local g_masterahsanyt_EnsureHackMenu
do
    local VERSION = "MagicMenu.V1"
    local function runtime()
        local state = _G.LunarNativeSettingsRuntime
        if type(state) ~= "table" then state = {}; _G.LunarNativeSettingsRuntime = state end
        return state
    end
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function loadTable(name)
        local ok, value = pcall(require, name)
        if not ok then
            if package and package.loaded and type(package.loaded[name]) ~= "table" then
                package.loaded[name] = nil
            end
            error(name .. ": " .. tostring(value), 0)
        end
        assert(type(value) == "table", name .. ": SETTINGS_MODULE_NOT_READY")
        return value
    end
    local function register(catalog, page)
        if type(catalog) ~= "table" or type(page) ~= "table" then return false end
        local found = false
        for i = #catalog, 1, -1 do
            local entry = catalog[i]
            if type(entry) == "table" and entry.Key == "MagicMenu" then
                if found then table.remove(catalog, i) else catalog[i] = page; found = true end
            end
        end
        if not found then table.insert(catalog, 1, page) end
        return true
    end
    local function looksLikeCatalog(value, allowEmpty)
        if type(value) ~= "table" then return false end
        local first = value[1]
        if type(first) == "table" and first.Key ~= nil then return true end
        return allowEmpty and next(value) == nil
    end
    local function isMainSettings(config)
        local key
        if type(config) == "string" then key = config
        else
            key = member(config, "keyName") or member(config, "KeyName")
                or member(config, "key") or member(config, "Key")
        end
        if key == nil then return false end
        local lower = string.lower(tostring(key))
        return lower:find("setting_main", 1, true) ~= nil
            and lower:find("custom", 1, true) == nil
    end
    local function injectShowCatalog(manager, config, args, count)
        local actual, first = config, 1
        if config == manager then actual, first = args[1], 2 end
        if not isMainSettings(actual) then return end
        local state = runtime()
        if not state.Page then return end
        state.LastShowUIInjected = false
        for i = first, count do
            if looksLikeCatalog(args[i], false) then
                state.LastShowUIInjected = register(args[i], state.Page)
                state.LastShowUICatalogIndex = i
                break
            end
        end
        if not state.LastShowUIInjected and looksLikeCatalog(args[first], true) then
            state.LastShowUIInjected = register(args[first], state.Page)
            state.LastShowUICatalogIndex = first
        end
    end
    local function installManagers(state)
        local managers = {}
        local function add(manager)
            if manager == nil then return end
            for _, current in ipairs(managers) do if current == manager then return end end
            managers[#managers + 1] = manager
        end
        add(_G.UIManager)
        local ok, loaded = pcall(loadTable, "client.slua_ui_framework.manager")
        if ok then add(loaded); state.ManagerModuleError = nil
        else state.ManagerModuleError = tostring(loaded) end
        local count = 0
        for _, manager in ipairs(managers) do
            local show = member(manager, "ShowUI")
            if type(show) == "function" then
                local record = member(manager, "__MagicMenuUIHook")
                if type(record) ~= "table" or record.Version ~= VERSION or record.Wrapper ~= show then
                    record = {Version = VERSION, Original = show}
                    record.Wrapper = function(config, ...)
                        local current = runtime()
                        if not current.Initializing and type(current.Ensure) == "function" then
                            pcall(current.Ensure)
                        end
                        local args, n = {...}, select('#', ...)
                        injectShowCatalog(manager, config, args, n)
                        return record.Original(config, (table.unpack or unpack)(args, 1, n))
                    end
                    manager.ShowUI = record.Wrapper
                    manager.__MagicMenuUIHook = record
                end
                count = count + 1
            end
        end
        state.Managers = managers
        state.HookCount = count
        state.HookInstalled = count > 0
        return state.HookInstalled
    end
    local function buildPage(F, AliasMap, sliderReady)
        local function slider(key, label, lo, hi, getter, setter)
            return {
                Key = key, UI = AliasMap.Slider, Text = label,
                MinValue = lo, MaxValue = hi, min = lo, max = hi,
                GetFunc = getter,
                SetFunc = function(c, v)
                    setter(v)
                    if F.Save then F.Save(true) end
                    _G.g_masterahsanyt_MagicState.LastHash = ""
                    return true
                end,
            }
        end
        local Stack = {
            {
                Key = "Magic_Enabled", UI = AliasMap.Switcher, Text = "Magic Bullet",
                EventType = 0xF00D, EventID = 1,
                GetFunc = function() return _G.g_masterahsanyt_MagicConfig.Enabled end,
                SetFunc = function(c, v)
                    _G.g_masterahsanyt_MagicConfig.Enabled = (v == true or v == 1)
                    _G.g_masterahsanyt_MagicState.LastHash = ""
                    if F.Save then F.Save(true) end
                    return true
                end,
            },
            slider("Magic_Head", "  Head scale (1.0-2.0 safe)", 100, 300,
                function() return math.floor((_G.g_masterahsanyt_MagicConfig.Head - 1.0) * 100 + 0.5) end,
                function(v) _G.g_masterahsanyt_MagicConfig.Head = 1.0 + (v/100) end),
            slider("Magic_Body", "  Body scale", 100, 300,
                function() return math.floor((_G.g_masterahsanyt_MagicConfig.Body - 1.0) * 100 + 0.5) end,
                function(v) _G.g_masterahsanyt_MagicConfig.Body = 1.0 + (v/100) end),
            slider("Magic_Legs", "  Legs scale", 100, 300,
                function() return math.floor((_G.g_masterahsanyt_MagicConfig.Legs - 1.0) * 100 + 0.5) end,
                function(v) _G.g_masterahsanyt_MagicConfig.Legs = 1.0 + (v/100) end),
        }
        return {
            Key = "MagicMenu", Text = "Magic Menu",
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_Magic_Bullet", Text = "MAGIC BULLET", Stack = Stack },
            },
        }
    end
    local function initialize(state)
        local F = _G.LunarFeatures
        assert(type(F) == "table", "FEATURE_RUNTIME_NOT_READY")
        local pages   = loadTable("client.logic.NewSetting.SettingPageDefine")
        local catalog = loadTable("client.logic.NewSetting.SettingCatalog")
        local aliases = loadTable("client.slua.umg.NewSetting.Item.AliasMap")
        assert(type(aliases.Switcher) == "table", "AliasMap.Switcher_not_ready")
        local sliderReady = type(aliases.Slider) == "table"
        local rebuild = state.Version ~= VERSION or not state.Page
            or state.Features ~= F or state.Alias ~= aliases
            or state.Switcher ~= aliases.Switcher or state.Slider ~= aliases.Slider
        if rebuild then
            state.Page = buildPage(F, aliases, sliderReady)
            state.PageBuilds = (state.PageBuilds or 0) + 1
        end
        state.Version, state.Features, state.PageDefine, state.Catalog = VERSION, F, pages, catalog
        state.Alias, state.Switcher, state.Slider = aliases, aliases.Switcher, aliases.Slider
        state.SliderReady = sliderReady
        pages.MagicMenu = state.Page
        state.Registered = register(catalog, state.Page)
        state.Ready = state.Registered and state.HookInstalled == true
        if state.Ready then
            state.LastError = nil
            _G.HackMenuInitialized = "MAGIC_MENU_NATIVE_V1"
        else
            state.LastError = "SETTINGS_UI_MANAGER_NOT_READY"
        end
        return state.Ready
    end
    g_masterahsanyt_EnsureHackMenu = function()
        local state = runtime()
        state.Ensure = g_masterahsanyt_EnsureHackMenu
        if state.Initializing then return false end
        state.Initializing = true
        state.Attempts = (state.Attempts or 0) + 1
        local okHook, hookErr = pcall(installManagers, state)
        if not okHook then state.HookInstalled = false; state.HookError = tostring(hookErr)
        else state.HookError = nil end
        local ok, result = pcall(initialize, state)
        state.Initializing = false
        if not ok then state.Ready = false; state.LastError = tostring(result) end
        return ok and result == true
    end
    _G.LunarSettingsDiagnostics = function()
        local state = runtime()
        return {
            version = state.Version, ready = state.Ready == true,
            registered = state.Registered == true, attempts = state.Attempts or 0,
            lastError = state.LastError, hookInstalled = state.HookInstalled == true,
            hookCount = state.HookCount or 0, hookError = state.HookError,
            pageBuilt = state.Page ~= nil, pageBuilds = state.PageBuilds or 0,
            sliderReady = state.SliderReady == true,
            lastShowUIInjected = state.LastShowUIInjected,
        }
    end
end

-- ============================================================================
-- SINGLE-TIMER SCHEDULER (ESP runner — drives Magic Tick + bypass re-apply)
-- ============================================================================
local g_masterahsanyt_ESPRunnerToken = {}
if type(_G.__MasterShotESPCleanup) == "function" then pcall(_G.__MasterShotESPCleanup) end
_G.__MasterShotESPRunner = g_masterahsanyt_ESPRunnerToken
_G.__MasterShotESPCleanup = function()
    _G.g_masterahsanyt_MagicState.EnemyMarks = {}
end
local g_masterahsanyt_ESPDiagnostics = {Updates=0, Errors=0, LastError=nil}
_G.g_masterahsanyt_ESPDiagnostics = g_masterahsanyt_ESPDiagnostics
local g_masterahsanyt_ESPTicker = nil
pcall(function() g_masterahsanyt_ESPTicker = require("common.time_ticker") end)

g_masterahsanyt_ShotESP = g_masterahsanyt_ShotESP or { Running = false, TimerClock = 0, Now = 0 }

-- forward declaration: ESPTick refers to ESPSchedule and vice versa
local g_masterahsanyt_ESPTick

local function g_masterahsanyt_ESPSchedule(delay)
    delay = math.max(0.001, math.min(0.50, tonumber(delay) or 0.40))
    if _G.__MasterShotESPRunner ~= g_masterahsanyt_ESPRunnerToken then return end

    if not g_masterahsanyt_ESPTicker or not g_masterahsanyt_ESPTicker.AddTimerOnce then
        local okT, ticker = pcall(require, "common.time_ticker")
        if okT and ticker then g_masterahsanyt_ESPTicker = ticker end
        if not g_masterahsanyt_ESPTicker or not g_masterahsanyt_ESPTicker.AddTimerOnce then
            g_masterahsanyt_ESPDiagnostics.LastError = "common.time_ticker.AddTimerOnce unavailable"
            pcall(function()
                local GDP = require("GameLua.GameCore.Data.GameplayData")
                local pc = GDP.GetPlayerController and GDP.GetPlayerController()
                if pc and pc.AddGameTimer then
                    pc:AddGameTimer(0.5, false, function()
                        if _G.__MasterShotESPRunner == g_masterahsanyt_ESPRunnerToken then
                            g_masterahsanyt_ESPSchedule(0.001)
                        end
                    end)
                end
            end)
            return
        end
    end

    local serial = (g_masterahsanyt_ESPRunnerToken.Serial or 0) + 1
    g_masterahsanyt_ESPRunnerToken.Serial = serial
    g_masterahsanyt_ESPRunnerToken.Due = F.Now() + delay
    local ok, err = pcall(g_masterahsanyt_ESPTicker.AddTimerOnce, delay, function()
        if _G.__MasterShotESPRunner ~= g_masterahsanyt_ESPRunnerToken
            or g_masterahsanyt_ESPRunnerToken.Serial ~= serial then return end
        g_masterahsanyt_ESPRunnerToken.Due = nil
        g_masterahsanyt_ShotESP.TimerClock = g_masterahsanyt_ShotESP.TimerClock + delay
        g_masterahsanyt_ESPTick()
    end)
    if not ok or err == false then
        g_masterahsanyt_ESPRunnerToken.Due = nil
        g_masterahsanyt_ESPDiagnostics.Errors = g_masterahsanyt_ESPDiagnostics.Errors + 1
        g_masterahsanyt_ESPDiagnostics.LastError = tostring(err)
        -- Fallback re-arm so chain never dies permanently.
        pcall(function()
            local GDP = require("GameLua.GameCore.Data.GameplayData")
            local pc = GDP.GetPlayerController and GDP.GetPlayerController()
            if pc and pc.AddGameTimer then
                pc:AddGameTimer(0.5, false, function()
                    if _G.__MasterShotESPRunner == g_masterahsanyt_ESPRunnerToken then
                        g_masterahsanyt_ESPSchedule(0.001)
                    end
                end)
            end
        end)
    end
end

g_masterahsanyt_ESPTick = function()
    local token = g_masterahsanyt_ESPRunnerToken
    if _G.__MasterShotESPRunner ~= token then return end
    local now = F.Now()
    F.TimerClock = g_masterahsanyt_ShotESP.TimerClock

    local ok, err = pcall(g_masterahsanyt_MagicTick)
    g_masterahsanyt_ESPDiagnostics.LastUpdateOK = ok
    g_masterahsanyt_ESPDiagnostics.Updates = g_masterahsanyt_ESPDiagnostics.Updates + 1
    if not ok then
        g_masterahsanyt_ESPDiagnostics.Errors = g_masterahsanyt_ESPDiagnostics.Errors + 1
        g_masterahsanyt_ESPDiagnostics.LastError = tostring(err)
        F.Error("Magic.Tick", err)
    end

    -- Re-apply the bypass every tick (layers self-check).
    pcall(_G._BYPASS_Execute)
    token.LastBypass = now

    g_masterahsanyt_ESPSchedule(0.40)
end

_G.g_masterahsanyt_MasterShotESPForceRefresh = function()
    if _G.__MasterShotESPRunner ~= g_masterahsanyt_ESPRunnerToken then return end
    g_masterahsanyt_ESPRunnerToken.Due = nil
    g_masterahsanyt_ESPSchedule(0.001)
end

-- ============================================================================
-- FEATURE RUNTIME (F.Pump / F.NextInterval / F.Wake)
-- ============================================================================
F.V1Due = 0; F.AimDue = 0; F.IpadDue = 0; F.SaveDue = 0
F.Pump = function(now)
    F.TimerClock = g_masterahsanyt_ShotESP.TimerClock
    now = now or F.Now()
    if F.Dirty and now >= F.SaveDue then pcall(F.Save, true); F.SaveDue = now + 0.5 end
end
F.NextInterval = function(now)
    if not (_G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized) then return 0.50 end
    return 0.40
end
F.Wake = function()
    if F.Token and F.Token.Stopped then return end
    local due = g_masterahsanyt_ESPRunnerToken.Due
    if not due or due - F.Now() > 0.002 then g_masterahsanyt_ESPSchedule(0.001) end
end

-- ============================================================================
-- SETTINGS MAINTENANCE (fast ticker, own provider chain)
-- ============================================================================
local g_masterahsanyt_FastRunnerToken = {}
local previousSettingsRunner = _G.__MasterShotFastRunner
if type(previousSettingsRunner) == "table"
    and previousSettingsRunner.Timer and previousSettingsRunner.Owner then
    pcall(function()
        previousSettingsRunner.Owner:RemoveGameTimer(previousSettingsRunner.Timer)
    end)
end
_G.__MasterShotFastRunner = g_masterahsanyt_FastRunnerToken

local function g_masterahsanyt_FastTick()
    if _G.__MasterShotFastRunner ~= g_masterahsanyt_FastRunnerToken then return end
    local render = _G.__MasterShotESPRunner
    if not render or not render.Due then
        pcall(g_masterahsanyt_MagicTick)
        pcall(_G._BYPASS_Execute)
    end
end

do
    local token = g_masterahsanyt_FastRunnerToken
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function valid(object)
        if object == nil then return false end
        if slua and type(slua.isValid) == "function" then
            local ok, value = pcall(slua.isValid, object)
            return ok and value == true
        end
        return false
    end
    local function timerOwnerReady(owner)
        return owner ~= nil and (owner == Game or valid(owner) or valid(member(owner, "Object")))
    end
    local function callback()
        if _G.__MasterShotFastRunner ~= token then
            if token.Timer and token.Owner then
                pcall(function() token.Owner:RemoveGameTimer(token.Timer) end)
            end
            token.Timer = nil
            return
        end
        g_masterahsanyt_FastTick()
        g_masterahsanyt_StartSettingsMaintenance()
    end
    g_masterahsanyt_StartSettingsMaintenance = function(owner)
        if _G.__MasterShotFastRunner ~= token then return false end
        if token.Pending then return true end
        if token.Timer and (token.Provider == "ticker" or timerOwnerReady(token.Owner)) then
            return true
        end
        if token.Timer and token.Owner then
            pcall(function() token.Owner:RemoveGameTimer(token.Timer) end)
        end
        token.Timer, token.Owner, token.Provider = nil, nil, nil
        local candidates = {}
        local function add(candidate, kind)
            if not timerOwnerReady(candidate)
                or type(member(candidate, "AddGameTimer")) ~= "function" then return end
            for _, entry in ipairs(candidates) do
                if entry.Object == candidate then return end
            end
            candidates[#candidates + 1] = {Object = candidate, Kind = kind}
        end
        local pc
        pcall(function()
            if GameplayData.GetPlayerController then
                pc = GameplayData.GetPlayerController()
            end
        end)
        if not valid(pc) then
            pcall(function()
                if slua_GameFrontendHUD then
                    pc = slua_GameFrontendHUD:GetPlayerController()
                end
            end)
        end
        add(pc, "controller")
        add(owner, "character")
        add(Game, "game")
        for _, entry in ipairs(candidates) do
            local ok, timer = pcall(function()
                return entry.Object:AddGameTimer(1.0, true, callback)
            end)
            if ok and timer then
                token.Timer, token.Owner, token.Provider = timer, entry.Object, entry.Kind
                token.LastError = nil
                g_masterahsanyt_FastTick()
                return true
            end
        end
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker then
            if type(ticker.AddTimer) == "function" then
                local ok, timer = pcall(ticker.AddTimer, 1.0, true, callback)
                if ok and timer then
                    token.Timer, token.Owner, token.Provider = timer, ticker, "ticker"
                    token.LastError = nil
                    return true
                end
            end
            if type(ticker.AddTimerOnce) == "function" then
                token.Pending, token.Provider = true, "ticker_once"
                local ok, accepted = pcall(ticker.AddTimerOnce, 1.0, function()
                    token.Pending = false
                    callback()
                end)
                if ok and accepted ~= false then token.LastError = nil; return true end
                token.Pending, token.Provider = false, nil
                token.LastError = tostring(accepted)
            else
                token.LastError = "SETTINGS_TIMER_API_UNAVAILABLE"
            end
        else
            if package and package.loaded
                and type(package.loaded["common.time_ticker"]) ~= "table" then
                package.loaded["common.time_ticker"] = nil
            end
            token.LastError = tostring(ticker)
        end
        return false
    end
end

-- ============================================================================
-- STARTUP
-- ============================================================================
if _G.LunarLoginRuntime then _G.LunarLoginRuntime.NeedsUpdate = false end
g_masterahsanyt_FastTick()
g_masterahsanyt_StartSettingsMaintenance()
g_masterahsanyt_ShotESP.Running = true
g_masterahsanyt_ESPTick()
end -- startBaselineHacks

local ok, startError = pcall(startBaselineHacks)
if not ok then
    _G.LunarOptionalStartupError = tostring(startError)
    if _G.LunarFeatures and _G.LunarFeatures.Error then
        _G.LunarFeatures.Error("Startup", startError)
    end
end

-- No class is returned: injects behavior only (Magic Bullet + Auto Head).
return nil
