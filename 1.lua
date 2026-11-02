local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
    self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
    self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:HandleOnAttachedToVehicle", Game:GetObjName(uVehicle)))
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
    self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:UpdatePlayerAttachToVehicle(uVehicle)
      end
    end)
    self.nFixMeshContainerTimer = self:AddGameTimer(3, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:FixMeshContainerOffsetIfNeeded(uVehicle)
      end
    end)
  end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(uLastVehicle) then
    return
  end
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnDetachedFromVehicle", uLastVehicle)
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.CapsuleComponent) or not slua.isValid(self.Mesh) or not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  if not self.nUpdatePlayerAttachToVehicleCount then
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  local ESTEPoseState = import("ESTEPoseState")
  local bStand = self.PoseState == ESTEPoseState.Stand
  local uActorRelativeLocation = self.CapsuleComponent:GetRelativeTransform():GetLocation()
  local uMeshRelativeLocation = self.Mesh:GetRelativeTransform():GetLocation()
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  local nCapsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
  local nCapsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local nExpectedCapsuleRadius = self.StandRadius
  local nExpectedCapsuleHalfHeight = self.StandHalfHeight
  local uMeshExpectedRL = FVector(0, 0, 0)
  local uActorExpectedRL = FVector(0, 0, self.StandHalfHeight)
  local nTolerance = 1.0
  local bCapsuleRLCorrect = uActorRelativeLocation:Equals(uActorExpectedRL, nTolerance)
  local bMeshRLCorrect = uMeshRelativeLocation:Equals(uMeshExpectedRL, nTolerance)
  local bMeshContainerRLCorrect = nTolerance > math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ)
  local bCapsuleRadiusCorrect = nTolerance > math.abs(nCapsuleRadius - nExpectedCapsuleRadius)
  local bCapsuleHalfHeightCorrect = nTolerance > math.abs(nCapsuleHalfHeight - nExpectedCapsuleHalfHeight)
  local bAllCorrect = bStand and bCapsuleRLCorrect and bMeshRLCorrect and bMeshContainerRLCorrect and bCapsuleRadiusCorrect and bCapsuleHalfHeightCorrect
  if not bAllCorrect then
    self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1
  else
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:UpdatePlayerAttachToVehicle PlayerKey:%s. bAllCorrect=%s Check Result:%d %d %d %d %d %d, Count:%d", tostring(self.PlayerKey), tostring(bAllCorrect), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, self.nUpdatePlayerAttachToVehicleCount))
  if self.nUpdatePlayerAttachToVehicleCount >= 3 and not bAllCorrect then
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local uPlayerController = GameplayData.GetPlayerController()
    if uPlayerController.ReportCrashKitFeature and uPlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
      local sReportInfo = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", tostring(uVehicle.VehicleShapeType), tostring(self.PlayerKey), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, uActorRelativeLocation:ToString(), tostring(nCapsuleRadius), tostring(nCapsuleHalfHeight), uMeshRelativeLocation:ToString(), tostring(uMeshContainerRelativeLocationZ))
      uPlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(sReportInfo)
    end
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  local nTolerance = 1.0
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if nTolerance <= math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ) then
    print(bWriteLog and string.format("BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded PlayerKey:%s. SetMeshContainerOffsetZ from:%s to:%s", tostring(uMeshContainerExpectedZ), tostring(uMeshContainerExpectedZ)))
    self:SetMeshContainerOffsetZ(uMeshContainerExpectedZ)
  end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
  if self.nUpdatePlayerAttachToVehicleTimer then
    self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
    self.nUpdatePlayerAttachToVehicleTimer = nil
  end
  if self.nFixMeshContainerTimer then
    self:RemoveGameTimer(self.nFixMeshContainerTimer)
    self.nFixMeshContainerTimer = nil
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  local EPawnState = import("EPawnState")
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
    self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local EGameModeType = import("EGameModeType")
    local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  local EParachuteState = import("EParachuteState")
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uGameState = GameplayData:GetGameState()
  local STExtraGameStateBase = import("STExtraGameStateBase")
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    local EGameModeType = import("EGameModeType")
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  local EMovementMode = import("EMovementMode")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local UKismetSystemLibrary = import("KismetSystemLibrary")
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.UInt32,
    UEnums.EPropertyClass.UInt32
  }
}

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  print(bWriteLog and string.format("BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment Type = %d, Param = %s", Type, Param))
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      local EStateType = import("EStateType")
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        local ESTEPoseState = import("ESTEPoseState")
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  local loadLater = function()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ==============================================================================
-- ============================ BẮT ĐẦU FULL LOGIC MOD ==========================
-- ==============================================================================


local function Notify(msg) local s = "[ABU RAHAF VIP] " .. tostring(msg)
pcall(function() if _G.LexusNotify then _G.LexusNotify(s) end end)
pcall(function() local sh = import("ScriptHelperClient") if sh and
sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,
G=1, B=0, A=1}, {X=1.2, Y=1.2}) end end) print(s) end

local _slua = rawget(_G, "slua")

local function Valid(obj) if not obj then return false end if _slua and
_slua.isValid then local ok, v = pcall(_slua.isValid, obj) if not ok or not v
then return false end end return true end

-- ========================================== 
-- STATIC VARIABLES & GLOBAL CACHE TỐI ƯU HÓA (CHỐNG LAG)
-- ========================================== 
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_SNAPLINE = {R=0, G=255, B=255, A=255} 
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}

local GLOBAL_BONE_LIST = {
    "head", "neck_01", "pelvis",
    "upperarm_r", "lowerarm_r", "hand_r",
    "upperarm_l", "lowerarm_l", "hand_l",
    "thigh_l", "calf_l", "foot_l",
    "thigh_r", "calf_r", "foot_r"
}

local GLOBAL_CONNECTIONS = {
    {"neck_01", "pelvis", C_YELLOW},
    {"neck_01", "upperarm_l", C_CYAN}, {"upperarm_l", "lowerarm_l", C_CYAN}, {"lowerarm_l", "hand_l", C_CYAN},
    {"neck_01", "upperarm_r", C_CYAN}, {"upperarm_r", "lowerarm_r", C_CYAN}, {"lowerarm_r", "hand_r", C_CYAN},
    {"pelvis", "thigh_l", C_CYAN}, {"thigh_l", "calf_l", C_CYAN}, {"calf_l", "foot_l", C_CYAN},
    {"pelvis", "thigh_r", C_CYAN}, {"thigh_r", "calf_r", C_CYAN}, {"calf_r", "foot_r", C_CYAN}
}

-- ========================================== 
-- CẤU HÌNH LEXUS CORE + FULL FEATURES VIP 
-- ========================================== 
_G.LexusConfig = _G.LexusConfig or { 
    FakeHWID = false,
    CustomMagicBullet = false,
    AutoHead = false, 
    EspVip = false, 
    EspDistance = false, 
    EspVipPro = false, 
    EspRadar = false, 
    EspLoai5 = false, 
    EspLoai6 = false, 
    EspLoai7 = false,
    Esp7_SoLuong = true, -- [THÊM MỚI] Bật tắt Số lượng địch
    Esp7_VuKhi = true,   -- [THÊM MỚI] Bật tắt Vũ khí địch
    Esp7_TuThe = true,   -- [THÊM MỚI] Bật tắt Tư thế địch
    EspLoai8 = false,
    EspBomMaster = false, 
    EspItemBom = false,   
    EspActiveBom = false, 
    EspVehicle = false,   
    EspVeh_Dacia = true,  
    EspVeh_UAZ = true,    
    EspVeh_Buggy = true,  
    EspVeh_Coupe = true,  
    EspVeh_Mirado = true, 
    EspVeh_Motor = true,  
    EspVeh_Other = true,  
    Esp3ShowName = true,
    Esp3ShowHP = true,
    EspAntenna = false, 
    EspSnaplines = false,
    EspOutline = false, 
    OutlineThickness = 10, 
    UnlockFPS = false, 
    IpadView = false, 
    CustomAimbot = false, 
    CustomAimbotClose = false, 
    CustomHRecoil = false,  
    CustomVRecoil = false,  
    LessShake = false, 
    RemoveGrass = false, 
    RemoveTrees = false,  
    RemoveFog = false, 
    WhiteBody = false, 
    ColorBodyV2 = false,    
    WallXuyenTuong = false, 
    Crosshair = false, 
    Accuracy = false,
    GodMode = false, 
    WallClimb = false,
    FastCar = false,
    BlackSky = false, -- Tích hợp BlackSky
    
    -- Config Mới Cho Aimbot V2 (Aim Touch)
    AimTouchEnable = false,
    AimTouchHipIgKnock = false,
    AimTouchHipIgBot = false,
    AimTouchSGIgKnock = false,
    AimTouchSGIgBot = false,
    AimTouchHipVisCheck = false,
    AimTouchSGVisCheck = false,
    AimTouchHipfire = false,
    AimTouchSG = true,
    AimTouchSGAutoFire = true,
    AimTouchScopeAll = true,
    AimTouchScopeIgKnock = false,
    AimTouchScopeIgBot = false,
    AimTouchScopeVisCheck = false,
    AimTouchScopeSniper = false,
    AimTouchSniperIgKnock = false,
    AimTouchSniperIgBot = false,
    AimTouchSniperVisCheck = false,
    
    -- Config Mod Skin VIP
    ModSkin = false,           
    SkinOptionOpen = false,
    
    -- Config Bug Màn
    BugManEnable = false
}

-- CHỨA STATE HỆ THỐNG ĐÃ ĐƯỢC TỐI ƯU HÓA HOÀN TOÀN RAM TRỐNG
_G.LexusState = _G.LexusState or { 
    LoopToken = 0, 
    NativeESPReady = false,
    GraphicsUnlocked = false, 
    MenuStep = 0, 
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0, 
    CustomTextData = nil,     
    LastAimbotConfigString = "",
    MagicUpdateVersion = 1,
    LastMagicConfigHash = "",
    PrevGraphicsState = {}
}

local limitTime = os.time({ year = 2026, month = 10, day = 20, hour = 17, min = 0, sec = 0 }) 
local currentTime = os.time(os.date("!*t"))
local isExpired = false 

pcall(function()
    local fileName = ".sys_time_cache" -- Tên file ẩn
    local paths = {
        -- ==========================================
        -- [ANDROID] THƯ MỤC SAVEGAMES (Tất cả phiên bản)
        -- ==========================================
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        
        -- ==========================================
        -- [ANDROID] THƯ MỤC GAMELET/LOGS (Giấu sâu chống xóa)
        -- ==========================================
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,

        -- ==========================================
        -- [IOS / FALLBACK] Đường dẫn Sandbox Engine UE4
        -- ==========================================
        "Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName
    }
    
    -- [IOS ĐẶC BIỆT] Dò tìm thư mục HOME thực tế
    if os and os.getenv then
        local homeDir = os.getenv("HOME")
        if homeDir and homeDir ~= "" then
            table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName)
            table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName)
        end
    end
    
    -- LỚP BẢO MẬT 1: Lấy thời gian thực từ Server Game (Anti-đổi giờ thiết bị)
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then 
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then 
            currentTime = serverTime -- Ưu tiên giờ Server
        end
    end

    -- LỚP BẢO MẬT 2: Đọc TẤT CẢ file ẩn tại SaveGames và Gamelet/logs (tìm mốc thời gian lớn nhất)
    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then
                lastSeenTime = savedTime
            end
            file:close()
        end
    end

    if currentTime < lastSeenTime then
        -- KHI BỊ LÙI NGÀY HOẶC ĐỔI GIỜ MÁY: Lấy lại mốc thời gian đã lưu lớn nhất
        currentTime = lastSeenTime
    else
        -- RẢI FILE ẨN: Lưu cập nhật thời gian mới nhất vào TẤT CẢ các thư mục có thể ghi được
        for _, path in ipairs(paths) do
            -- Hàm io.open("w") sẽ tự động bỏ qua nếu đường dẫn thư mục đó không tồn tại trên máy
            local file = io.open(path, "w")
            if file then
                file:write(tostring(currentTime))
                file:close()
            end
        end
    end
end)

isExpired = (currentTime > limitTime)

-- ==============================================================================
-- ================== KHỞI TẠO VÀ LOAD BYPASS ĐẦU TIÊN ==========================
-- ==============================================================================

-- ============================================================================
-- ULTIMATE MERGED BYPASS v3.0 - COMPLETE SECURITY DISABLEMENT
-- ============================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end
local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture = function() return "" end; SMTD.ReMTDePicture = function() return "" end; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.CheckCanBugglyPostException = retFalse; GRUtils.ReplayReportData = nop; GRUtils.ReportGameException = nop; GRUtils.PostException = nop end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]; if s then s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse; s.sendEvent = nop; s.report = nop end
        end
    end)
end

local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem", "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.ReportPingDelayTimer then sub:RemoveGameTimer(sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end; sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then AvaEx.CheckAvatarException = nop; AvaEx.CheckAvatarExceptionOnce = nop; AvaEx.ReportAvatarException = nop; AvaEx.CheckSlotMeshVisible = retFalse; AvaEx.CheckPawnVisible = retFalse; AvaEx.CheckCanBugglyPostException = retFalse end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            -- [FIX PING]: Thêm tham số 'true' vào hàm find để tìm kiếm chuỗi thuần túy, nhanh hơn hàng chục lần so với regex, chống giật ping
            TssSdk.OnRecvData = function(data) if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end; if origData then origData(data) end end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse; TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop end
    end)
end

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive", "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.GetCurWeaponSkinID = retZero; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; pc.HiggsBosonComponent:ControlMHActive(0) end
        end
    end)
end

local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop; _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then PlayerController.HiggsBosonComponent:ControlMHActive(0); PlayerController.HiggsBosonComponent.bMHActive = false end
        end
    end
end

local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient", "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then pcall(function() sub[k] = nop end) end end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

_G.StartBypass_VIP_v3 = function()
    pcall(function()
        print("[ULTIMATE BYPASS] Starting initialization...")
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeSkinBypass() -- Thêm dòng này
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReplayTelemetryBlocker()
        InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass()
        InitializeClientFlowBypass()
        InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass()
        InitializeModifierExceptionBypass()
        InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks()
        InitializeAntiReport()
        InitializeGameplayBypass()
        InitializeKillAllSubsystems()
        InitializeFinalProtection()
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end

-- ========================================== 
-- HÀM QUẢN LÝ DỌN RÁC MAP MARK (CHỐNG LAG/HIỂN THỊ ẢO KHI ĐỊCH CHẾT)
-- ========================================== 
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.LexusState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    _G.LexusState.TrackedMarks[mark] = nil
end

-- ========================================== 
-- TẠO ID DUY NHẤT VÀ VĨNH VIỄN CHO MỖI KẺ ĐỊCH (SỬA LỖI GIẬT LAG KHI SLUA TẠO WRAPPER MỚI)
-- ==========================================
local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

-- ========================================== 
-- KIỂM TRA PHÂN BIỆT AI (BOT) / REAL PLAYER - OPTIMIZED
-- ==========================================
local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true
                hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

-- ========================================== 
-- KHỞI TẠO HOOKS AUTO HEAD SÁT THƯƠNG
-- ==========================================
function _G.InitializeAutoHeadHooks()
    pcall(function()
        local EAvatarDamagePosition = import("EAvatarDamagePosition")
        if not EAvatarDamagePosition then return end

        local modulesToHook = {
            "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
            "GameLua.Logic.Weapon.ShootWeaponEntity"
        }
        
        for _, path in ipairs(modulesToHook) do
            local hitLogic = package.loaded[path]
            if hitLogic then
                local original_GetHitBodyType = hitLogic.GetHitBodyType
                hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                    if _G.LexusConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyType then return original_GetHitBodyType(self, ImpactResult, InImpactVec) end
                end

                local original_GetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
                hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                    if _G.LexusConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyTypeByHitPos then return original_GetHitBodyTypeByHitPos(self, InImpactVec) end
                end
            end
        end
    end)
end
-- ==============================================================================
-- ================= DATA & LOGIC MOD SKIN ======================================
-- ==============================================================================
_G.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
}

_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.VipAttachToIndex[attachId] = index
        end
    end
end

_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}

_G.OutfitSkins = {
    Suit = {403003,1407916,1406469,1405870,1407140,1407141,1407142,1407550,1406638,1406872,1406971,1407103,1407512,1407391,1407366,1407330,1407329,1407286,1407285,1407277,1407276,1407275,1407225,1407224,1407259,1407161,1407160,1407107,1407106,1407079,1407048,1406977,1406976,1406898,1400569,1404000,1404049,1400119,1400117,1406060,1406891,1400687,1405160,1405145,1405436,1405435,1405434,1405064,1405207,1406895,1400333,1400377,1405092,1405121,1406889,1407278,1407279,1407381,1407380,1407385,1406389,1406388,1406387,1406386,1406385,1406140,1400782,1407392,1407318,1407317,1407404,1407402,1407401,1407387,1404434,1404437,1404440,1404448,1400324,1400708,1404043,1404048,1405953,1400101,1404153,1407440,1407441},
    Bag = {
        {501001, 501002, 501003}, {1501001174, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
        {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
        {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
        {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
        {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
        {1501001346, 1501002346, 1501003346}
    },
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342}
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.skinIdMappings = {
    [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},                    
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},                    
    [102002]={102002,1102002136,1102002043,1102002061,1102002424},                                          
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},                    
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [102001]={102001, 1102001120}, -- UZI Băng Giá
    [101005]={101005, 1101005098}, -- Groza Godzilla Bốc Lửa
    [104003]={104003, 1104003037}, -- S12K Nguyên Tử
    [104004]={104004, 1104004035, 1104004041} -- DBS Quái Thú & Sandsinger
}

_G.VehicleSkins = { 
    [1961001] = { 1961007, 1961010, 1961012, 1961013, 1961014, 1961015, 1961016, 1961017, 1961018, 1961020, 1961021, 1961024, 1961025, 1961029, 1961030, 1961031, 1961032, 1961033, 1961034, 1961035, 1961036, 1961037, 1961038, 1961039, 1961040, 1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047, 1961048, 1961049, 1961050, 1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057, 1961058, 1961059, 1961060, 1961061, 1961062, 1961063, 1961064, 1961065, 1961066, 1961067, 1961068, 1961069, 1961136, 1961137, 1961138, 1961139, 1961140, 1961141, 1961142, 1961143, 1961144, 1961145, 1961147, 1961148, 1961149, 1961150, 1961151, 1961152, 1961153 },
    [1903001] = { 1903005, 1903006, 1903007, 1903008, 1903011, 1903012, 1903013, 1903014, 1903015, 1903016, 1903017, 1903018, 1903019, 1903020, 1903021, 1903022, 1903023, 1903024, 1903029, 1903030, 1903031, 1903032, 1903033, 1903034, 1903035, 1903036, 1903037, 1903039, 1903040, 1903041, 1903042, 1903043, 1903044, 1903045, 1903046, 1903051, 1903052, 1903053, 1903054, 1903055, 1903056, 1903057, 1903058, 1903059, 1903060, 1903061, 1903062, 1903063, 1903066, 1903067, 1903068, 1903069, 1903070, 1903071, 1903072, 1903073, 1903074, 1903075, 1903076, 1903079, 1903080, 1903081, 1903082, 1903084, 1903085, 1903086, 1903087, 1903088, 1903089, 1903090, 1903189, 1903190, 1903191, 1903192, 1903193, 1903194, 1903195, 1903196, 1903197, 1903198, 1903199, 1903200, 1903201, 1903202, 1903203, 1903204, 1903205, 1903206, 1903207, 1903208, 1903209, 1903210, 1903211, 1903212, 1903213, 1903214, 1903215, 1903216, 1903217, 1903218, 1903219, 1903220, 1903221, 1903222, 1903223, 1903225, 1903226, 1903227, 1903228 }, 
    [1915001] = { 1915002, 1915003, 1915004, 1915005, 1915006, 1915007, 1915008, 1915009, 1915010, 1915011, 1915012, 1915013, 1915014, 1915015, 1915016, 1915017, 1915018, 1915019, 1915020, 1915021, 1915022, 1915023, 1915024, 1915025, 1915026, 1915027, 1915099 },          
    [1908001] = { 1908002, 1908003, 1908005, 1908006, 1908007, 1908008, 1908009, 1908010, 1908011, 1908012, 1908013, 1908015, 1908016, 1908017, 1908018, 1908019, 1908021, 1908023, 1908030, 1908031, 1908032, 1908033, 1908034, 1908035, 1908036, 1908037, 1908039, 1908040, 1908041, 1908043, 1908047, 1908049, 1908050, 1908051, 1908052, 1908053, 1908054, 1908055, 1908056, 1908057, 1908059, 1908060, 1908061, 1908062, 1908063, 1908064, 1908066, 1908067, 1908068, 1908069, 1908070, 1908075, 1908076, 1908077, 1908078, 1908080, 1908081, 1908082, 1908083, 1908084, 1908085, 1908086, 1908087, 1908088, 1908089, 1908091, 1908094, 1908095, 1908096, 1908097, 1908098, 1908099, 1908100, 1908101, 1908102, 1908104, 1908105, 1908106, 1908107, 1908108, 1908109, 1908110, 1908111, 1908112, 1908188, 1908189 },   
    [1907001] = { 1907007, 1907008, 1907010, 1907011, 1907012, 1907013, 1907014, 1907016, 1907018, 1907019, 1907021, 1907022, 1907023, 1907025, 1907026, 1907027, 1907028, 1907029, 1907030, 1907032, 1907033, 1907034, 1907035, 1907036, 1907037, 1907038, 1907040, 1907041, 1907043, 1907044, 1907045, 1907046, 1907047, 1907048, 1907049, 1907050, 1907051, 1907052, 1907053, 1907054, 1907055, 1907056, 1907058, 1907059, 1907060, 1907061, 1907062, 1907063, 1907064, 1907065, 1907066, 1907067, 1907068, 1907069, 1907070, 1907071, 1907072, 1907073, 1907074 }
}
_G.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end
_G.download_item = DownloadGameItem

_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.skinIdCache2[targetSkinId] then
            if _G.download_item then pcall(_G.download_item, targetSkinId) end
            _G.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

_G.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end
    
    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = levelFunc(slotData.AdditionalItemID) or 1
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end

            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end

            if not _G.skinIdCache[applyItemId] then
                if _G.download_item then pcall(_G.download_item, applyItemId) end
                _G.skinIdCache[applyItemId] = true
            end

            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then 
            hasGliderSlot = true
            break 
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.OutfitMap.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.OutfitMap.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.OutfitMap.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.OutfitMap.Parachute or 0, _G.CustSlotType.ParachuteEquipemtSlot, false)
    end
end

_G.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end
        
        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local isModified = false
                
                local SkinData = Weapon.synData:Get(7) 
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.skinIdCache[SkinID] then 
                        _G.download_item(SkinID)
                        _G.skinIdCache[SkinID] = true 
                    end
                    isModified = true
                end
                
                if SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do 
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.skinIdCache2[targetAttachId] then 
                                                if _G.download_item then pcall(_G.download_item, targetAttachId) end
                                                _G.skinIdCache2[targetAttachId] = true 
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

_G.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = PlayerCharacter:GetCurrentVehicle()
        if not slua.isValid(Vehicle) then 
            _G.LastVehicleEntity = nil
            return 
        end
        
        -- [FIX TỤT FPS]: Khóa ngay nếu xe này đã được load Skin xong (tránh spam lệnh ChangeItemAvatar làm đơ game)
        if _G.LastVehicleEntity == Vehicle and _G.CurrentEquipVehicleID ~= nil then
            return
        end

        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
        if not slua.isValid(VehicleAvatar) then return end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = tostring(Vehicle:GetAvatarId() or "")
        local applySkinId = 0
        
        for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then 
                applySkinId = targetSkin
                break 
            end
        end

        if applySkinId and applySkinId > 0 then
            _G.skinIdCache = _G.skinIdCache or {}
            if not _G.skinIdCache[applySkinId] then 
                if _G.download_item then pcall(_G.download_item, applySkinId) end
                _G.skinIdCache[applySkinId] = true 
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(applySkinId, true) end
            
            _G.CurrentEquipVehicleID = applySkinId
            _G.LastVehicleEntity = Vehicle
        end
    end)
end

_G.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then return end
        
        _G.skinIdCache = _G.skinIdCache or {}
        if not _G.skinIdCache[petSkin] then 
            if _G.download_item then pcall(_G.download_item, petSkin) end
            _G.skinIdCache[petSkin] = true 
        end
        
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.LastAppliedPet = petSkin
    end)
end

_G.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.LexusState or not _G.LexusState.CustomTextData then return end
        local cData = _G.LexusState.CustomTextData

        if _G.OutfitSkins then
            if cData.SkinSuit and _G.OutfitSkins.Suit[cData.SkinSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.OutfitSkins.Bag[cData.SkinBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

        if _G.skinIdMappings then
            if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
            
            if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS] end
        end

        if _G.VehicleSkins then
            if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][cData.SkinBuggy] then _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][cData.SkinBuggy] end
            if cData.SkinMirado and _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][cData.SkinMirado] then _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][cData.SkinMirado] end
        end
    end)
end

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    -- [FIX LAG]: Giới hạn quét hòm xác 2 giây/lần bằng đồng hồ thực của máy (rất nhẹ CPU)
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    -- [FIX MEMORY LEAK]: Sinh mảng cache 1 lần duy nhất thay vì tạo lại liên tục
    if not _G.CachedActorArray then
        _G.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray)
    
    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) and currentWeapon.synData then
                            local weaponSkinData = currentWeapon.synData:Get(7)
                            if weaponSkinData and weaponSkinData.defineID then
                                currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                            end
                        end
                    end
                    
                    if currentBoxSkinId ~= 0 then
                        pcall(function()
                            DeadBoxAvatarComponent:ResetItemAvatar()
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                        end)
                    end
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager = nil

_G.ForceEnableKillCounterUI = function()
    pcall(function()
        local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
            local kcImpl = KillCounterUISubsystem.__inner_impl
            kcImpl.CheckSupportKCUI = function() return true end
            kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon, PlayerID)
                if slua.isValid(PlayerWeapon) then
                    local WeaponID = PlayerWeapon:GetWeaponID()
                    self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
                else self:UpdateMainKillCounterUI(false) end
            end
            local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
            kcImpl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                if bShow then AvatarID = _G.get_skin_id(WeaponID) or AvatarID end
                if originalUpdateMainKillCounterUI then originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID) end
            end
            _G.KCUISystemHacked2 = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager and not _G.KCLogicHacked2 then
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if LogicKillCounter then
                LogicKillCounter.CheckSupportKC = function() return true end
                LogicKillCounter.CheckSupportKillCounterAvatar = function() return true end
                LogicKillCounter.CheckHasWeaponKillCounter = function() return true end
                LogicKillCounter.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                LogicKillCounter.GetEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetMyEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetOneWeaponKillCountInBattle = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                LogicKillCounter.GetWeaponKillCountByUid = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                _G.KCLogicHacked2 = true
            end
        end

        local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
        local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
        
        if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
            local originalFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id(weaponID)
                            if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                            if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit end
                            
                            if CACHED_GoldColor then
                                DamageRecordData.IsUseColor, DamageRecordData.UseColor = true, CACHED_GoldColor
                            end
                            
                            if DamageRecordData.ResultHealthStatus == 2 then
                                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                _G.NeedCheckDeadBoxTimer = 50 
                                
                                if not CACHED_UI_Manager then CACHED_UI_Manager = require("client.slua_ui_framework.manager") end
                                local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                                
                                if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                    local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                                    uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                    local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                    local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                    uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                end
                            end
                        end
                    end
                end)
                if originalFileItem then return originalFileItem(self, DamageRecordData) end
            end
            _G.KillInfoCounterHacked = true
        end

        local SwitchWeaponSlotMode2 = package.loaded["GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2"] or require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SwitchWeaponSlotMode2 and SwitchWeaponSlotMode2.__inner_impl and not _G.SlotBaseHacked then
            SwitchWeaponSlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if slua.isValid(self.KillCounterImg) then 
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible) 
                end
            end
            _G.SlotBaseHacked = true
        end
    end)
end

function _G.InitializeSkinModSystem()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyBypassHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                        if vipAttachID and vipAttachID > 0 then
                            if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                            itemID = vipAttachID
                        end
                    end
                end
                if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
            end

            local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.LobbyBypassHacked = true
        end
    end)
    
    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.IconBaloHacked then
        local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil
                
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end
                
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end
                
                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.skinIdCache2[displayResId] then
                        if _G.download_item then pcall(_G.download_item, displayResId) end
                        _G.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.IconBaloHacked = true
        end
    end)
end
-- ========================================== 
-- HỆ THỐNG LƯU VÀ TẢI SETTING MENU VIP (TỰ ĐỘNG)
-- ========================================== 
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
            end
        end
    end)
    return paths
end

local ConfigFileName = "@a_9rk.txt"
_G.LastConfigSaveStr = ""

-- HÀM LƯU CONFIG
_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nLexusConfig = {\n"
        for k, v in pairs(_G.LexusConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.LexusState and _G.LexusState.CustomTextData then
            for k, v in pairs(_G.LexusState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        data = data .. "}\n}"
        
        -- Chống giật lag: Chỉ tiến hành ghi file nếu bạn có thay đổi cấu hình
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data

        local paths = GetConfigPaths(ConfigFileName)
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(data)
                file:close()
                break
            end
        end
    end)
end

-- HÀM TẢI (ĐỌC) CONFIG
_G.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end

        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.LexusConfig then
                        for k, v in pairs(savedData.LexusConfig) do
                            _G.LexusConfig[k] = v
                        end
                    end
                    if savedData.CustomTextData then
                        _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do
                            _G.LexusState.CustomTextData[k] = v
                        end
                    end
                end
            end
        end
        -- Ghi nhớ cấu hình vừa tải
        _G.SaveModSettings() 
    end)
end

-- VÒNG LẶP KIỂM TRA ĐỂ LƯU CHẠY NGẦM RẤT NHẸ
local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker") 
        if okTicker and ticker and ticker.AddTimerOnce then 
            ticker.AddTimerOnce(3.0, AutoSaveLoop) -- Cứ 3 giây check 1 lần
        end
    end)
end

-- KHỞI CHẠY LẦN ĐẦU TIÊN
if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

-- DƯ THỪA ĐỂ KHÔNG BỊ LỖI VÒNG LẶP CŨ CỦA BẠN
local MENU_VALID = function(o) return o and slua and slua.isValid and slua.isValid(o) end
local FLC = import("LinearColor")
local FV2 = import("Vector2D")
local FSC = import("SlateColor") or import("/Script/SlateCore.SlateColor")

local C = {
    bg        = FLC(0.015, 0.030, 0.070, 1.0),
    bg_dark   = FLC(0.006, 0.012, 0.030, 1.0),
    bg_header = FLC(0.008, 0.018, 0.045, 1.0),
    bg_side   = FLC(0.012, 0.028, 0.060, 1.0),
    bg_side_on= FLC(0.025, 0.16, 0.32, 1.0),
    bg_row    = FLC(0.018, 0.045, 0.090, 1.0),
    bg_row_z  = FLC(0.025, 0.065, 0.125, 1.0),
    bg_foot   = FLC(0.006, 0.014, 0.035, 1.0),
    accent    = FLC(0.00, 0.65, 1.0, 1.0),
    accent_br = FLC(0.35, 0.92, 1.0, 1.0),
    accent_dk = FLC(0.00, 0.25, 0.55, 1.0),
    accent_dp = FLC(0.00, 0.10, 0.24, 1.0),
    purple    = FLC(0.75, 0.40, 1.0, 1.0),
    purple_dk = FLC(0.35, 0.15, 0.55, 1.0),
    green     = FLC(0.30, 0.90, 0.55, 1.0),
    green_br  = FLC(0.55, 1.0, 0.75, 1.0),
    green_dk  = FLC(0.10, 0.45, 0.28, 1.0),
    red       = FLC(1.0, 0.45, 0.50, 1.0),
    red_dk    = FLC(0.55, 0.15, 0.20, 1.0),
    red_dp    = FLC(0.25, 0.06, 0.10, 1.0),
    white     = FLC(0.98, 0.98, 1.0, 1.0),
    text      = FLC(0.92, 0.94, 0.98, 1.0),
    text_dim  = FLC(0.50, 0.58, 0.70, 1.0),
    line      = FLC(0.15, 0.20, 0.30, 1.0),
    sh1       = FLC(0, 0, 0, 0.85),
    sh2       = FLC(0, 0, 0, 0.60),
    sh3       = FLC(0, 0, 0, 0.40),
    sh4       = FLC(0, 0, 0, 0.25),
    trans     = FLC(0, 0, 0, 0.01),
}

local W, H = 760, 480
local HDR = 56
local SIDE = 132
local ROW = 34
local FOOT = 22

local canvas, panel, panelSlot
local floats = {}
local open, built = false, false
local pos = { x = 0, y = 0 }
local drag = false
local dragStart = { x = 0, y = 0 }
local floatDrag = false
local floatMoved = false
local floatDragStart = { x = 0, y = 0 }
local floatPos = { x = 18, y = 180 }

local function GetPointerPosition()
    local p = nil
    pcall(function()
        local WLL = import("WidgetLayoutLibrary")
        if WLL then
            if WLL.GetMousePositionOnPlatform then p = WLL.GetMousePositionOnPlatform() end
            if not p and WLL.GetMousePositionOnViewport then p = WLL.GetMousePositionOnViewport() end
        end
    end)
    return p
end

local function GetCanvas()
    if canvas and Game:IsValid(canvas) then return canvas end
    canvas = nil
    pcall(function()
        local T = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        local M = T.GetMainControlBaseUI()
        if not M or not Game:IsValid(M) then return end
        if M.CanvasPanel_0 and Game:IsValid(M.CanvasPanel_0) then canvas = M.CanvasPanel_0
        elseif M.CanvasPanel_42 and Game:IsValid(M.CanvasPanel_42) then canvas = M.CanvasPanel_42 end
    end)
    return canvas
end

local function NewCanvas(p)
    local c = nil
    pcall(function() c = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", p) end)
    return c
end

local function NewBtn(p, x, y, w, h, z, cb)
    local b = nil
    pcall(function()
        b = CGame:NewObjectFromPath("/Script/UMG.Button", p)
        if b and slua.isValid(b) then
            pcall(function() b:SetColorAndOpacity(C.trans) end)
            pcall(function() b:SetBackgroundColor(C.trans) end)
            pcall(function() b:SetWidgetVisibility(UEnums.ESlateVisibility.Visible) end)
            local s = p:AddChildToCanvas(b)
            if s then
                s:SetAutoSize(false); s:SetPosition(FV2(x, y)); s:SetSize(FV2(w, h)); s:SetZOrder(z or 900)
            end
            if cb then pcall(function() if b.OnClicked then b.OnClicked:Add(function() pcall(cb) end) end end) end
        end
    end)
    return b
end

local function NewBtnRaw(p, x, y, w, h, z)
    local b = nil
    pcall(function()
        b = CGame:NewObjectFromPath("/Script/UMG.Button", p)
        if b and slua.isValid(b) then
            pcall(function() b:SetColorAndOpacity(C.trans) end)
            pcall(function() b:SetBackgroundColor(C.trans) end)
            pcall(function() b:SetWidgetVisibility(UEnums.ESlateVisibility.Visible) end)
            local s = p:AddChildToCanvas(b)
            if s then
                s:SetAutoSize(false); s:SetPosition(FV2(x, y)); s:SetSize(FV2(w, h)); s:SetZOrder(z or 900)
            end
        end
    end)
    return b
end

local function Box(p, x, y, w, h, c, z)
    local b = nil
    pcall(function()
        b = CGame:NewObjectFromPath("/Script/UMG.Border", p)
        if b and slua.isValid(b) then
            b:SetBrushColor(c)
            b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = p:AddChildToCanvas(b)
            if s then
                s:SetAutoSize(false); s:SetPosition(FV2(x, y)); s:SetSize(FV2(w, h)); s:SetZOrder(z or 0)
            end
        end
    end)
    return b
end

local function Txt(p, t, x, y, sz, c, z, ax, ay)
    local tb = nil
    pcall(function()
        tb = CGame:NewObjectFromPath("/Script/UMG.TextBlock", p)
        if tb and slua.isValid(tb) then
            tb:SetText(t)
            if FSC then tb:SetColorAndOpacity(FSC(c)) else tb:SetColorAndOpacity(c) end
            if tb.Font then local f = tb.Font f.Size = sz tb.Font = f end
            tb:SetRenderTransformPivot(FV2(ax or 0.5, ay or 0.5))
            tb:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = p:AddChildToCanvas(tb)
            if s then
                s:SetAutoSize(true); s:SetAlignment(FV2(ax or 0.5, ay or 0.5))
                s:SetPosition(FV2(x, y)); s:SetZOrder(z or 100)
            end
        end
    end)
    return tb
end

local function Show()
    if panel and MENU_VALID(panel) then
        pcall(function() panel:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    end
end

local function Hide()
    if panel and MENU_VALID(panel) then
        pcall(function() panel:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    end
end

local function Refresh(r)
    if not r then return end
    local on = r.g()
    local col = on and C.green_br or C.red
    if r.t and MENU_VALID(r.t) then
        pcall(function()
            r.t:SetText(on and "ON" or "OFF")
            if FSC then r.t:SetColorAndOpacity(FSC(col)) else r.t:SetColorAndOpacity(col) end
        end)
    end
    if r.k and MENU_VALID(r.k) and r.ks then
        pcall(function()
            local kx = on and (r.tx + r.tw - r.kz - 2) or (r.tx + 2)
            r.ks:SetPosition(FV2(kx, r.ty + 2))
        end)
    end
    if r.tr and MENU_VALID(r.tr) then
        pcall(function() r.tr:SetBrushColor(on and C.green or C.red_dp) end)
    end
    if r.gl and MENU_VALID(r.gl) then
        pcall(function() r.gl:SetWidgetVisibility(on and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed) end)
    end
    if r.ac and MENU_VALID(r.ac) then
        pcall(function() r.ac:SetBrushColor(on and C.accent or C.red_dk) end)
    end
end

local function MakeToggle(p, label, x, y, w, h, g, s, zebra)
    local on = g()
    local r = { g = g, s = s }
    r.gl = Box(p, x, y, w, h, C.accent_dp, 198)
    if not on then pcall(function() r.gl:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) end
    Box(p, x, y, w, h, zebra and C.bg_row_z or C.bg_row, 200)
    r.ac = Box(p, x, y, 3, h, on and C.accent or C.red_dk, 201)
    Box(p, x, y + h, w, 1, C.line, 203)
    Txt(p, label, x + 14, y + h * 0.5, 12, C.text, 300, 0, 0.5)

    local tw, th = 38, 18
    local tx = x + w - tw - 10
    local ty = y + h * 0.5 - th * 0.5
    local kz = th - 4
    r.tx, r.ty, r.tw, r.kz = tx, ty, tw, kz

    Box(p, tx - 1, ty - 1, tw + 2, th + 2, C.accent_dp, 298)
    r.tr = Box(p, tx, ty, tw, th, on and C.green or C.red_dp, 300)
    local kx = on and (tx + tw - kz - 2) or (tx + 2)
    local ky = ty + 2
    Box(p, kx, ky + 1, kz, kz, FLC(0, 0, 0, 0.55), 302)
    pcall(function()
        local k = CGame:NewObjectFromPath("/Script/UMG.Border", p)
        if k and slua.isValid(k) then
            k:SetBrushColor(C.white)
            k:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = p:AddChildToCanvas(k)
            if s then
                s:SetAutoSize(false); s:SetPosition(FV2(kx, ky)); s:SetSize(FV2(kz, kz)); s:SetZOrder(303)
            end
            r.k = k
            r.ks = s
        end
    end)
    r.t = Txt(p, on and "ON" or "OFF", tx - 22, y + h * 0.5, 10, on and C.green_br or C.red, 300, 1, 0.5)
    NewBtn(p, x, y, w, h, 900, function() s(not g()); Refresh(r) end)
    return r
end

local function MakeSlider(p, label, x, y, w, h, gt, om, op, zebra)
    Box(p, x, y, w, h, zebra and C.bg_row_z or C.bg_row, 200)
    Box(p, x, y, 3, h, C.purple, 201)
    Box(p, x, y + h, w, 1, C.line, 203)
    Txt(p, label, x + 14, y + h * 0.5, 12, C.text, 300, 0, 0.5)
    local txt = Txt(p, gt(), x + w - 68, y + h * 0.5, 11, C.accent_br, 300, 1, 0.5)
    local bw, bh = 20, 20
    local by = y + h * 0.5 - bh * 0.5
    local mx = x + w - 48
    local px = x + w - 24
    Box(p, mx - 1, by - 1, bw + 2, bh + 2, C.accent_dp, 298)
    Box(p, mx, by, bw, bh, C.bg_side, 299)
    Txt(p, "-", mx + bw * 0.5, by + bh * 0.5, 14, C.red, 400, 0.5, 0.5)
    NewBtn(p, mx, by, bw, bh, 900, function()
        om()
        if txt and MENU_VALID(txt) then pcall(function() txt:SetText(gt()) end) end
    end)
    Box(p, px - 1, by - 1, bw + 2, bh + 2, C.accent_dp, 298)
    Box(p, px, by, bw, bh, C.bg_side, 299)
    Txt(p, "+", px + bw * 0.5, by + bh * 0.5, 14, C.green, 400, 0.5, 0.5)
    NewBtn(p, px, by, bw, bh, 900, function()
        op()
        if txt and MENU_VALID(txt) then pcall(function() txt:SetText(gt()) end) end
    end)
end

local function Build()
    if built and panel and MENU_VALID(panel) then Show() return end
    local cvs = GetCanvas()
    if not cvs then return end

    pcall(function()
        panel = NewCanvas(cvs)
        if panel and slua.isValid(panel) then
            local s = cvs:AddChildToCanvas(panel)
            if s then
                s:SetAutoSize(false); s:SetZOrder(10000)
                s:SetAnchors(FAnchors(0.5, 0.5, 0.5, 0.5))
                s:SetAlignment(FV2(0.5, 0.5))
                s:SetPosition(FV2(pos.x, pos.y))
                s:SetSize(FV2(W, H))
                panelSlot = s
            end
        end
    end)
    if not panel or not slua.isValid(panel) then return end

    Box(panel, -8, -8, W + 16, H + 16, C.sh3, -4)
    Box(panel, -4, -4, W + 8, H + 8, C.sh2, -3)
    Box(panel, -2, -2, W + 4, H + 4, C.sh1, -2)
    Box(panel, -1, -1, W + 2, H + 2, C.accent, -1)
    Box(panel, 0, 0, W, H, C.bg, 1)
    Box(panel, 0, 0, W, HDR, C.bg_header, 2)
    Box(panel, 0, 0, W, 2, C.accent, 3)
    Box(panel, 0, HDR - 1, W, 1, C.accent_dk, 3)

    Box(panel, 12, 12, 22, 22, C.accent_dp, 4)
    Box(panel, 14, 14, 18, 18, C.accent, 5)
    Box(panel, 16, 16, 14, 14, C.bg, 6)
    Txt(panel, "A", 23, 23, 12, C.accent_br, 400, 0.5, 0.5)

    Txt(panel, "ABU RAHAF VIP", W * 0.5, HDR * 0.5 - 6, 13, C.white, 400, 0.5, 0.5)
    Txt(panel, "", W * 0.5, HDR * 0.5 + 8, 8, C.accent, 400, 0.5, 0.5)

    Txt(panel, "v1.0", W - 34, HDR * 0.5, 10, C.purple, 400, 0.5, 0.5)

    local cX = W - 26
    Box(panel, cX - 1, HDR * 0.5 - 10, 18, 18, C.red_dk, 4)
    Box(panel, cX, HDR * 0.5 - 9, 16, 16, C.red, 5)
    Txt(panel, "X", cX + 8, HDR * 0.5, 11, C.white, 400, 0.5, 0.5)
    NewBtn(panel, cX, HDR * 0.5 - 10, 18, 18, 900, function() open = false; Hide() end)

    local dragArea = NewBtnRaw(panel, 60, 4, W - 130, HDR - 8, 950)
    pcall(function()
        if dragArea and dragArea.OnPressed then
            dragArea.OnPressed:Add(function()
                drag = true
                local WLL = import("WidgetLayoutLibrary")
                if WLL then
                    local p = GetPointerPosition()
                    if p then dragStart.x = p.X; dragStart.y = p.Y end
                end
            end)
        end
        if dragArea and dragArea.OnReleased then
            dragArea.OnReleased:Add(function() drag = false end)
        end
    end)

    local sideY = HDR + 4
    Box(panel, 2, sideY, SIDE, H - sideY - FOOT - 2, C.bg_side, 2)
    Box(panel, SIDE + 1, sideY, 1, H - sideY - FOOT - 2, C.accent_dk, 3)
    Box(panel, SIDE + 4, sideY, 1, H - sideY - FOOT - 2, C.line, 3)

    local tabNames = {"ESP | كشف", "Aim | إيم", "System | نظام", "Skins | سكنات"}
    local tabs = {}
    local panels = {}

    local function SwitchTab(idx)
        for i, tw in ipairs(tabs) do
            if tw then
                if i == idx then
                    if tw.bg and MENU_VALID(tw.bg) then tw.bg:SetBrushColor(C.bg_side_on) end
                    if tw.bar and MENU_VALID(tw.bar) then tw.bar:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
                    if tw.tx and MENU_VALID(tw.tx) then
                        if FSC then tw.tx:SetColorAndOpacity(FSC(C.white)) else tw.tx:SetColorAndOpacity(C.white) end
                    end
                else
                    if tw.bg and MENU_VALID(tw.bg) then tw.bg:SetBrushColor(C.bg_side) end
                    if tw.bar and MENU_VALID(tw.bar) then tw.bar:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                    if tw.tx and MENU_VALID(tw.tx) then
                        if FSC then tw.tx:SetColorAndOpacity(FSC(C.text_dim)) else tw.tx:SetColorAndOpacity(C.text_dim) end
                    end
                end
            end
        end
        for i, pn in ipairs(panels) do
            if pn and MENU_VALID(pn) then
                if i == idx then pn:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                else pn:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            end
        end
    end

    for i, nm in ipairs(tabNames) do
        local ty = sideY + 8 + (i - 1) * 34
        local isOn = (i == 1)
        local bg = Box(panel, 6, ty, SIDE - 8, 30, isOn and C.bg_side_on or C.bg_side, 4)
        local bar = Box(panel, 6, ty, 3, 30, C.accent, 5)
        if not isOn then pcall(function() bar:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) end
        local tx = Txt(panel, nm, 16, ty + 15, 11, isOn and C.white or C.text_dim, 400, 0, 0.5)
        local idx = i
        NewBtn(panel, 6, ty, SIDE - 8, 30, 900, function() SwitchTab(idx) end)
        tabs[i] = { bg = bg, bar = bar, tx = tx }
    end

    local cx = SIDE + 12
    local cy = sideY + 8
    local cw = W - cx - 12
    local ch = H - sideY - FOOT - 12

    local function GetC() return _G.LexusState.CustomTextData or {} end

    local function BuildPanel(rows)
        local pn = NewCanvas(panel)
        if pn and slua.isValid(pn) then
            local s = panel:AddChildToCanvas(pn)
            if s then
                s:SetAutoSize(false); s:SetPosition(FV2(cx, cy)); s:SetSize(FV2(cw, ch)); s:SetZOrder(10)
            end
        end
        local yy = 0
        for i, r in ipairs(rows) do
            if r.t == "toggle" then
                MakeToggle(pn, r.l, 0, yy, cw, ROW, r.g, r.s, i % 2 == 0)
            elseif r.t == "slider" then
                MakeSlider(pn, r.l, 0, yy, cw, ROW, r.gt, r.om, r.op, i % 2 == 0)
            end
            yy = yy + ROW
        end
        return pn
    end

    local espRows = {
        {t="toggle", l="ESP | كشف محدث ViP", g=function() return _G.LexusConfig.File1ESP == true end, s=function(v)
            _G.LexusConfig.File1ESP = v
            local esp = _G.PlayerMapMarker
            if esp then
                if v and esp.Start then pcall(esp.Start)
                elseif not v and esp.Stop then pcall(esp.Stop) end
            end
        end},
        {t="toggle", l="ESP | تحذير 360 + HP", g=function() return _G.LexusConfig.EspVip end, s=function(v) _G.LexusConfig.EspVip = v end},
        {t="toggle", l="ESP | المسافة", g=function() return _G.LexusConfig.EspDistance end, s=function(v) _G.LexusConfig.EspDistance = v end},
        {t="toggle", l="ESP | الأسماء", g=function() return _G.LexusConfig.Esp3ShowName end, s=function(v) _G.LexusConfig.Esp3ShowName = v end},
        {t="toggle", l="ESP | HP عمودي", g=function() return _G.LexusConfig.Esp3ShowHP end, s=function(v) _G.LexusConfig.Esp3ShowHP = v end},
        {t="toggle", l="ESP | الرادار 360°", g=function() return _G.LexusConfig.EspRadar end, s=function(v) _G.LexusConfig.EspRadar = v end},
        {t="toggle", l="ESP | الإطار", g=function() return _G.LexusConfig.EspLoai5 end, s=function(v) _G.LexusConfig.EspLoai5 = v end},
        {t="toggle", l="ESP | الهيكل", g=function() return _G.LexusConfig.EspLoai6 end, s=function(v) _G.LexusConfig.EspLoai6 = v end},
        {t="toggle", l="ESP | معلومات", g=function() return _G.LexusConfig.EspLoai7 end, s=function(v) _G.LexusConfig.EspLoai7 = v end},
        {t="toggle", l="ESP | HP فوق الرأس", g=function() return _G.LexusConfig.EspLoai8 end, s=function(v) _G.LexusConfig.EspLoai8 = v end},
        {t="toggle", l="ESP | خط نحو العدو", g=function() return _G.LexusConfig.EspSnaplines end, s=function(v) _G.LexusConfig.EspSnaplines = v end},
    }

    local aimRows = {
    {t="toggle", l="إيمبوت", g=function() return _G.LexusConfig.CustomAimbot end, s=function(v) _G.LexusConfig.CustomAimbot = v end},
    {t="toggle", l="تصغير مؤشر", g=function() return _G.LexusConfig.Crosshair end, s=function(v) _G.LexusConfig.Crosshair = v end},
}

    local sysRows = {
        {t="toggle", l="System | منظور الآيباد", g=function() return _G.LexusConfig.IpadView end, s=function(v) _G.LexusConfig.IpadView = v end},
        {t="slider", l="System | قيمة FOV", gt=function() return tostring(math.floor(GetC().IpadViewFOV or 120)) end,
            om=function() GetC().IpadViewFOV = math.max(70, (GetC().IpadViewFOV or 120) - 5) end,
            op=function() GetC().IpadViewFOV = math.min(190, (GetC().IpadViewFOV or 120) + 5) end},
        {t="toggle", l="System | فتح 165 إطار", g=function() return _G.LexusConfig.UnlockFPS end, s=function(v) _G.LexusConfig.UnlockFPS = v end},
        {t="toggle", l="System | ويل هاك (رؤية بالجدران)", g=function() return _G.LexusConfig.WallXuyenTuong end, s=function(v) _G.LexusConfig.WallXuyenTuong = v end},
    }

    local skinRows = {
        {t="toggle", l="Skins | تفعيل التعديل", g=function() return _G.LexusConfig.ModSkin end, s=function(v) _G.LexusConfig.ModSkin = v end},
        {t="slider", l="Skins | طقم الملابس",
            gt=function() return tostring(math.floor(GetC().SkinSuit or 1)) .. "/" .. tostring(#(_G.OutfitSkins and _G.OutfitSkins.Suit or {})) end,
            om=function() local c = math.max(1, (GetC().SkinSuit or 1) - 1); GetC().SkinSuit = c; if _G.OutfitSkins.Suit[c] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[c] end end,
            op=function() local m = #(_G.OutfitSkins.Suit); local c = math.min(m, (GetC().SkinSuit or 1) + 1); GetC().SkinSuit = c; if _G.OutfitSkins.Suit[c] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[c] end end},
        {t="slider", l="Skins | الحقيبة",
            gt=function() return tostring(math.floor(GetC().SkinBag or 1)) .. "/" .. tostring(#(_G.OutfitSkins and _G.OutfitSkins.Bag or {})) end,
            om=function() local c = math.max(1, (GetC().SkinBag or 1) - 1); GetC().SkinBag = c; if _G.OutfitSkins.Bag[c] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[c] end end,
            op=function() local m = #(_G.OutfitSkins.Bag); local c = math.min(m, (GetC().SkinBag or 1) + 1); GetC().SkinBag = c; if _G.OutfitSkins.Bag[c] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[c] end end},
        {t="slider", l="Skins | الخوذة",
            gt=function() return tostring(math.floor(GetC().SkinHelmet or 1)) .. "/" .. tostring(#(_G.OutfitSkins and _G.OutfitSkins.Helmet or {})) end,
            om=function() local c = math.max(1, (GetC().SkinHelmet or 1) - 1); GetC().SkinHelmet = c; if _G.OutfitSkins.Helmet[c] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[c] end end,
            op=function() local m = #(_G.OutfitSkins.Helmet); local c = math.min(m, (GetC().SkinHelmet or 1) + 1); GetC().SkinHelmet = c; if _G.OutfitSkins.Helmet[c] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[c] end end},
        {t="slider", l="Skins | M416",
            gt=function() return tostring(math.floor(GetC().SkinM416 or 1)) .. "/" .. tostring(#(_G.skinIdMappings[101004])) end,
            om=function() local c = math.max(1, (GetC().SkinM416 or 1) - 1); GetC().SkinM416 = c; if _G.skinIdMappings[101004][c] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][c] end end,
            op=function() local m = #(_G.skinIdMappings[101004]); local c = math.min(m, (GetC().SkinM416 or 1) + 1); GetC().SkinM416 = c; if _G.skinIdMappings[101004][c] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][c] end end},
        {t="slider", l="Skins | AKM",
            gt=function() return tostring(math.floor(GetC().SkinAKM or 1)) .. "/" .. tostring(#(_G.skinIdMappings[101001])) end,
            om=function() local c = math.max(1, (GetC().SkinAKM or 1) - 1); GetC().SkinAKM = c; if _G.skinIdMappings[101001][c] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][c] end end,
            op=function() local m = #(_G.skinIdMappings[101001]); local c = math.min(m, (GetC().SkinAKM or 1) + 1); GetC().SkinAKM = c; if _G.skinIdMappings[101001][c] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][c] end end},
        {t="slider", l="Skins | SCAR-L",
            gt=function() return tostring(math.floor(GetC().SkinSCAR or 1)) .. "/" .. tostring(#(_G.skinIdMappings[101003])) end,
            om=function() local c = math.max(1, (GetC().SkinSCAR or 1) - 1); GetC().SkinSCAR = c; if _G.skinIdMappings[101003][c] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][c] end end,
            op=function() local m = #(_G.skinIdMappings[101003]); local c = math.min(m, (GetC().SkinSCAR or 1) + 1); GetC().SkinSCAR = c; if _G.skinIdMappings[101003][c] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][c] end end},
        {t="slider", l="Skins | M762",
            gt=function() return tostring(math.floor(GetC().SkinM762 or 1)) .. "/" .. tostring(#(_G.skinIdMappings[101008])) end,
            om=function() local c = math.max(1, (GetC().SkinM762 or 1) - 1); GetC().SkinM762 = c; if _G.skinIdMappings[101008][c] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][c] end end,
            op=function() local m = #(_G.skinIdMappings[101008]); local c = math.min(m, (GetC().SkinM762 or 1) + 1); GetC().SkinM762 = c; if _G.skinIdMappings[101008][c] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][c] end end},
        {t="slider", l="Skins | AUG",
            gt=function() return tostring(math.floor(GetC().SkinAUG or 1)) .. "/" .. tostring(#(_G.skinIdMappings[101006])) end,
            om=function() local c = math.max(1, (GetC().SkinAUG or 1) - 1); GetC().SkinAUG = c; if _G.skinIdMappings[101006][c] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][c] end end,
            op=function() local m = #(_G.skinIdMappings[101006]); local c = math.min(m, (GetC().SkinAUG or 1) + 1); GetC().SkinAUG = c; if _G.skinIdMappings[101006][c] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][c] end end},
        {t="slider", l="Skins | UMP45",
            gt=function() return tostring(math.floor(GetC().SkinUMP or 1)) .. "/" .. tostring(#(_G.skinIdMappings[102002])) end,
            om=function() local c = math.max(1, (GetC().SkinUMP or 1) - 1); GetC().SkinUMP = c; if _G.skinIdMappings[102002][c] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][c] end end,
            op=function() local m = #(_G.skinIdMappings[102002]); local c = math.min(m, (GetC().SkinUMP or 1) + 1); GetC().SkinUMP = c; if _G.skinIdMappings[102002][c] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][c] end end},
        {t="slider", l="Skins | داسيا",
            gt=function() return tostring(math.floor(GetC().SkinDacia or 1)) .. "/" .. tostring(#(_G.VehicleSkins[1903001])) end,
            om=function() local c = math.max(1, (GetC().SkinDacia or 1) - 1); GetC().SkinDacia = c; if _G.VehicleSkins[1903001][c] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][c] end end,
            op=function() local m = #(_G.VehicleSkins[1903001]); local c = math.min(m, (GetC().SkinDacia or 1) + 1); GetC().SkinDacia = c; if _G.VehicleSkins[1903001][c] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][c] end end},
        {t="slider", l="Skins | UAZ",
            gt=function() return tostring(math.floor(GetC().SkinUAZ or 1)) .. "/" .. tostring(#(_G.VehicleSkins[1908001])) end,
            om=function() local c = math.max(1, (GetC().SkinUAZ or 1) - 1); GetC().SkinUAZ = c; if _G.VehicleSkins[1908001][c] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][c] end end,
            op=function() local m = #(_G.VehicleSkins[1908001]); local c = math.min(m, (GetC().SkinUAZ or 1) + 1); GetC().SkinUAZ = c; if _G.VehicleSkins[1908001][c] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][c] end end},
        {t="slider", l="Skins | Coupe",
            gt=function() return tostring(math.floor(GetC().SkinCoupe or 1)) .. "/" .. tostring(#(_G.VehicleSkins[1961001])) end,
            om=function() local c = math.max(1, (GetC().SkinCoupe or 1) - 1); GetC().SkinCoupe = c; if _G.VehicleSkins[1961001][c] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][c] end end,
            op=function() local m = #(_G.VehicleSkins[1961001]); local c = math.min(m, (GetC().SkinCoupe or 1) + 1); GetC().SkinCoupe = c; if _G.VehicleSkins[1961001][c] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][c] end end},
    }

    panels[1] = BuildPanel(espRows)
    panels[2] = BuildPanel(aimRows)
    panels[3] = BuildPanel(sysRows)
    panels[4] = BuildPanel(skinRows)

    for i = 2, 4 do
        if panels[i] and MENU_VALID(panels[i]) then
            panels[i]:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
    end

    Box(panel, 0, H - FOOT - 1, W, 1, C.accent, 5)
    Box(panel, 0, H - FOOT, W, FOOT, C.bg_foot, 2)
    Box(panel, 8, H - FOOT * 0.5 - 2, 3, 3, C.accent, 5)
    Box(panel, W - 11, H - FOOT * 0.5 - 2, 3, 3, C.purple, 5)
    Txt(panel, "", W * 0.5, H - FOOT * 0.5, 8, C.text_dim, 400, 0.5, 0.5)

    built = true
    open = true
end

local function DoDrag()
    if not drag or not panelSlot then return end
    pcall(function()
        local WLL = import("WidgetLayoutLibrary")
        if not WLL then return end
        local p = GetPointerPosition()
        if not p then return end
        local dx = p.X - dragStart.x
        local dy = p.Y - dragStart.y
        if math.abs(dx) > 0.3 or math.abs(dy) > 0.3 then
            dragStart.x = p.X; dragStart.y = p.Y
            pos.x = pos.x + dx; pos.y = pos.y + dy
            if pos.x < -600 then pos.x = -600 end
            if pos.x > 600 then pos.x = 600 end
            if pos.y < -400 then pos.y = -400 end
            if pos.y > 400 then pos.y = 400 end
            panelSlot:SetPosition(FV2(pos.x, pos.y))
        end
    end)
end

local function PositionFloatTopCenter()
    if not floats or not floats.slot then return end
    pcall(function()
        local ui_util = require("client.common.ui_util")
        local vp = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize()
        if not vp then return end
        local fW = 128
        -- موضع زر المنيو حسب المكان المحدد في الصورة: أعلى الشاشة، جهة اليمين من المنتصف
        -- النسبة 0.63 تضع الزر أسفل منطقة الإعدادات مع إزاحة بسيطة إلى اليسار.
        local x = (vp.X * 0.63) - (fW * 0.5)
        local y = 12
        if x < 8 then x = 8 end
        if x > (vp.X - fW - 8) then x = vp.X - fW - 8 end
        floatPos.x = x
        floatPos.y = y
        floats.slot:SetPosition(FV2(x, y))
    end)
end

local function DoFloatDrag()
    -- الزر ثابت في أعلى الشاشة بجانب العداد.
    PositionFloatTopCenter()
end

local function CreateFloat()
    if floats.btn and MENU_VALID(floats.btn) then return end
    floats = {}
    pcall(function()
        local cvs = GetCanvas()
        if not cvs then return end
        local fW, fH = 128, 42

        -- حاوية حقيقية للزر: كل العناصر تتحرك معًا عند السحب
        local root = NewCanvas(cvs)
        if not root or not slua.isValid(root) then return end
        local slot = cvs:AddChildToCanvas(root)
        if not slot then return end
        slot:SetAutoSize(false)
        slot:SetPosition(FV2(floatPos.x, floatPos.y))
        slot:SetSize(FV2(fW, fH))
        slot:SetZOrder(15000)
        floats.root = root
        floats.slot = slot

        -- إطار Neon واضح
        Box(root, -8, -8, fW + 16, fH + 16, C.sh3, 11890)
        Box(root, -5, -5, fW + 10, fH + 10, C.sh2, 11891)
        Box(root, -2, -2, fW + 4, fH + 4, C.accent_dp, 11892)
        Box(root, 0, 0, fW, fH, C.bg_dark, 11893)
        Box(root, 2, 2, fW - 4, fH - 4, C.bg_header, 11894)
        Box(root, 2, 2, 4, fH - 4, C.accent, 11895)
        Box(root, fW - 6, 2, 4, fH - 4, C.purple, 11896)
        Box(root, 8, fH - 5, fW - 16, 2, C.accent_dk, 11897)

        Txt(root, "ABU RAHAF", fW * 0.5, 14, 12, C.white, 12001, 0.5, 0.5)
        Txt(root, "VIP  •  MENU", fW * 0.5, 29, 9, C.accent_br, 12002, 0.5, 0.5)

        floats.btn = NewBtnRaw(root, 0, 0, fW, fH, 12003)
        pcall(function()
            if floats.btn and floats.btn.OnClicked then
                floats.btn.OnClicked:Add(function()
                    pcall(function()
                        open = not open
                        if open then
                            if built and panel and MENU_VALID(panel) then Show()
                            else Build() end
                        else Hide() end
                    end)
                end)
            end
        end)
    end)
end

pcall(function()
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if pc and MENU_VALID(pc) then
        CreateFloat()
        PositionFloatTopCenter()
        -- تثبيت الزر أسفل زر الإعدادات مع إزاحة بسيطة إلى اليسار
        pc:AddGameTimer(0.016, true, function()
            if not floats.btn or not MENU_VALID(floats.btn) or not floats.slot then
                floats = {}
                CreateFloat()
            end
            PositionFloatTopCenter()
            DoDrag()
        end)
    end
end)
local function ShowLexusVIPMenu() 
    if _G.LexusMenuAlreadyShown then return end
    if _G.LexusState.MenuStep ~= 0 then return end

    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end

        local function Step_ScamAlert()
            Msg.Show(1, "انضم للقناة", function() local Web = require("client.slua.logic.url.logic_webview_sdk"); if Web and Web.OpenURL then Web:OpenURL("https://t.me/abu_rhofen") end end, function() end, "Join", "Joind")
            _G.LexusState.MenuStep = 99
            _G.LexusMenuAlreadyShown = true
        end

        local function Step_Welcome()
            Msg.Show(1, "Welcome To ABU", "لا تنسى اتباع تعليمات و عدم لعب ب وحشية ب تنجب البلاغات \n ارسل صور جلد ل استمرار ف تحديثات \n لا تجيب فوق 12 كل - لا تقتل لاعب بعيد بدون سكوب - لا تلعب مستودع او واو بحساب اساسي + خلي لعبك ذكي قناة المطور @abu_rhofen ", 
            function() 
                Notify("Open train To Show Menur ")
                Step_ScamAlert()
            end, 
            function() end, "لقد فهمت ", "تم")
        end

        _G.LexusState.MenuStep = 1
        Step_Welcome() 
    end)
end

-- ========================================== 
-- LOGIC MỞ KHÓA 165 FPS VÀ UI IPAD VIEW 
-- ========================================== 
local function InitializeGraphicsUnlock() 
    if isExpired then return end
    if _G.LexusState.GraphicsUnlocked or currentTime > limitTime then return end

    pcall(function()
        local SettingCfg = require("client.logic.setting.setting_config")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        if SettingCfg then
            if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
            if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
        end
        if GraphicSettingDB then
            if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
        end
    end)

    pcall(function()
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        
        local KismetMathLibrary = import("KismetMathLibrary") or _G.KismetMathLibrary
        local FLinearColor = import("LinearColor") or _G.FLinearColor

        if logic_setting_graphics then
            local old_SetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if old_SetFPS then old_SetFPS(gameInstance, FPSLevel) end
                if FPSLevel == 8 then 
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end

        if GSC_FPS and GSC_FPS.__inner_impl then
            local fps_impl = GSC_FPS.__inner_impl
            function fps_impl:GetMaxFPSLevel() return 8, 8 end
            function fps_impl:InitRealSupportFPS()
                local RealSupportFPS = {}
                for i = 1, 8 do RealSupportFPS[i] = {true, true} end
                if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, RealSupportFPS, false) end
                return RealSupportFPS
            end
            function fps_impl:UpdateSelectedFPSState(selectedLevel)
                if not slua.isValid(self.UIRoot) then return end
                for level = 2, 8 do
                    local name = "NodeFps" .. (({[2]=20,[3]=25,[4]=30,[5]=40,[6]=60,[7]=90,[8]=120})[level] or 120)
                    local widget = self.UIRoot[name]
                    if slua.isValid(widget) then
                        widget:SetIsEnabled(true) 
                        pcall(function() widget:SetRenderOpacity(1.0) end)
                        local switcher = self.UIRoot["WidgetSwitcher_" .. level]
                        if slua.isValid(switcher) then 
                            switcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) 
                        end
                    end
                end
            end
        end

        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            local ft_impl = GSC_FPSFT.__inner_impl
            local NMinFPS, NStep = 90, 5
            local function clamp(value, min, max)
                if value < min then return min end
                if max < value then return max end
                return value
            end
            local function lerp(a, b, t) return a + (b - a) * t end
            local function _getColorByPercent(start, finish, percent)
                if not FLinearColor then return nil end
                return FLinearColor(lerp(start.R, finish.R, percent), lerp(start.G, finish.G, percent), lerp(start.B, finish.B, percent), lerp(start.A, finish.A, percent))
            end
            
            ft_impl.ShowOrHide = function(self)
                self:SelfHitTestInvisible()
                if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end
            end

            ft_impl.InitFPSFTSwitch = function(self)
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(FPSFineTuneSwitch, true) end
                if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, FPSFineTuneSwitch) end
                if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
            end

            ft_impl.InitFPSFTValue165 = function(self)
                local itemRoot = self.UIRoot
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                local FPSFineTuneNum = 165
                if FPSFineTuneSwitch then
                    FPSFineTuneNum = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
                    itemRoot.Slider_screen3:SetLocked(false)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 1.0, 1.0, 1.0))
                    end
                else
                    itemRoot.Slider_screen3:SetLocked(true)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 0.625, 0.6, 1))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 0.625, 0.6, 1.0))
                    end
                end
                local FPSFineTunePer = (FPSFineTuneNum - NMinFPS) / (165 - NMinFPS)
                
                itemRoot.Veihclescreen3:SetText(tostring(FPSFineTuneNum))
                itemRoot.Slider_screen3:SetValue(FPSFineTunePer)
                itemRoot.ProgressBar_screen3:SetPercent(FPSFineTunePer)
                
                if FLinearColor then
                    local startColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                    local midColor = FLinearColor(1.0, 0.54, 0.11, 1.0)
                    local endColor = FLinearColor(1.0, 0.23, 0.15, 1.0)
                    local sliderColor = FPSFineTunePer < 0.4 and startColor or _getColorByPercent(midColor, endColor, (FPSFineTunePer - 0.4) / 0.6)
                    itemRoot.Slider_screen3:SetSliderHandleColor(sliderColor)
                end
            end

            ft_impl.OnFPSFTValueChange3 = function(self, FPSFineTuneNum)
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, FPSFineTuneNum)
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
                if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
                local gameInstance = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
                if gameInstance then
                    gameInstance:ExecuteCMD("t.MaxFPS", tostring(FPSFineTuneNum))
                    gameInstance:ExecuteCMD("r.FrameRateLimit", tostring(FPSFineTuneNum))
                end
            end

            ft_impl.OnFPSFTSliderValueChange3 = function(self, value)
                if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) and KismetMathLibrary then
                    local FPSFineTuneNum = KismetMathLibrary.FCeil(value * (165 - NMinFPS) / NStep) * NStep + NMinFPS
                    self:OnFPSFTValueChange3(clamp(FPSFineTuneNum, NMinFPS, 165))
                end
            end
            
            ft_impl.OnFPSFTAdd = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTAdd2 = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus2 = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTSliderValueChange = ft_impl.OnFPSFTSliderValueChange3
            ft_impl.OnFPSFTSliderValueChange2 = ft_impl.OnFPSFTSliderValueChange3
        end
    end)
    _G.LexusState.GraphicsUnlocked = true
    Notify("Graphics & FPS 165Hz Unlocked (Upgraded Version)")
end

-- ========================================== 
-- KHỞI TẠO HỆ THỐNG ESP (GỐC)
-- ========================================== 
local function InitializeNativeESP() 
    if _G.LexusState.NativeESPReady then return end
    pcall(function() 
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") 
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig") 
        local function ApplyCfg(cfg)
            if not cfg then return end 
            if cfg[1006] then 
                cfg[1006].bBindBlocked = true;
                cfg[1006].bBindOutScreen = true; 
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000; 
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root"; 
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30) 
            end 
            -- [FIX ESP LOẠI 4] Thay vì dùng 1003 dễ bị game xóa, ta tạo ID độc quyền 8888
            cfg[8888] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true,     -- Bắt buộc phải có để bám theo địch
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 30),
                bNeedPreLoad = true,        -- Bắt buộc có để load sẵn UI (chống lỗi)
                Priority = 2 
            } 
            cfg[9999] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true, 
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 50),
                bNeedPreLoad = true, 
                Priority = 2 
            } 
        end 
        ApplyCfg(currentMarkCfg) 
        for k, cfg in pairs(package.loaded) do 
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then 
                ApplyCfg(cfg) 
            end 
        end 
    end)
    _G.LexusState.NativeESPReady = true 
    Notify("Native ESP System Initialized") 
end

-- ========================================== 
-- LOCAL FUNCTIONS CHO LOGIC NEW ESP - OPTIMIZED
-- ========================================== 
local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 3.0) then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            if Valid(cachedMesh) then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then
                        table.insert(meshes, comp)
                    end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end

-- ========================================== 
-- ========================================================================
-- WALLHACK VISUALS: DrawDyeing + IdeaOutline (adapted from file #1)
-- Uses file #2's existing WallXuyenTuong menu toggle and enemy loop.
-- ========================================================================
local WH_LinearColor = nil
local WH_Colors = nil
local WH_ConsoleReady = false

pcall(function()
    WH_LinearColor = import("LinearColor")
    if WH_LinearColor then
        WH_Colors = {
            visible = WH_LinearColor(255, 255, 0, 100),
            occluded = WH_LinearColor(0, 255, 255, 100)
        }
    end
end)

local function SetupWallhackVisuals()
    if WH_ConsoleReady then return end
    pcall(function()
        local KismetSystemLibrary = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if not KismetSystemLibrary or not world then return end
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        WH_ConsoleReady = true
    end)
end

local function UndoWallXuyenTuong(enemy, markData)
    pcall(function()
        if not markData or not markData.WallhackApplied then return end
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetDrawDyeing) == "function" then mesh:SetDrawDyeing(false) end
                    if type(mesh.SetDrawHighlight) == "function" then mesh:SetDrawHighlight(false) end
                    if type(mesh.SetDrawIdeaOutline) == "function" then mesh:SetDrawIdeaOutline(false) end
                    if type(mesh.SetIdeaOverrideOutlineAndOcclusion) == "function" then
                        mesh:SetIdeaOverrideOutlineAndOcclusion(false)
                    end
                    if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then mesh:SetCustomDepthStencilValue(0) end
                end)
            end
        end
        markData.WallhackApplied = false
    end)
end

local function ApplyWallXuyenTuong(enemy, markData)
    pcall(function()
        SetupWallhackVisuals()
        if not WH_Colors then return end
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetDrawDyeing) == "function" then
                        mesh:SetDrawDyeing(true)
                    end
                    if type(mesh.SetDrawDyeingMode) == "function" then
                        mesh:SetDrawDyeingMode(1)
                    end
                    if type(mesh.SetVisibleDyeingColor) == "function" then
                        mesh:SetVisibleDyeingColor(WH_Colors.visible)
                    end
                    if type(mesh.SetOccludedDyeingColor) == "function" then
                        mesh:SetOccludedDyeingColor(WH_Colors.occluded)
                    end
                    if type(mesh.SetDyeingColorFadeDistance) == "function" then
                        mesh:SetDyeingColorFadeDistance(99999.0)
                    end
                    if type(mesh.SetDyeingColorMinMaxDistance) == "function" then
                        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
                    end
                    if type(mesh.SetDrawHighlight) == "function" then
                        mesh:SetDrawHighlight(true)
                    end
                    if type(mesh.OverrideHighlightColor) == "function" then
                        mesh:OverrideHighlightColor(WH_Colors.visible)
                    end
                    if type(mesh.SetHighlightCanBeOccluded) == "function" then
                        mesh:SetHighlightCanBeOccluded(false)
                    end
                    if type(mesh.SetDrawIdeaOutline) == "function" then
                        mesh:SetDrawIdeaOutline(true)
                    end
                    if type(mesh.SetIdeaOutlineNew) == "function" then
                        mesh:SetIdeaOutlineNew(true)
                    end
                    if type(mesh.SetIdeaOutlineOcclusionHighlight) == "function" then
                        mesh:SetIdeaOutlineOcclusionHighlight(true)
                    end
                    if type(mesh.OverrideIdeaOutlineColor) == "function" then
                        mesh:OverrideIdeaOutlineColor(WH_Colors.visible)
                    end
                    if type(mesh.SetIdeaOutlineOcclusionColor) == "function" then
                        mesh:SetIdeaOutlineOcclusionColor(WH_Colors.occluded)
                    end
                    if type(mesh.OverrideIdeaOutlineThickness) == "function" then
                        mesh:OverrideIdeaOutlineThickness(20.0)
                    end
                    if type(mesh.SetIdeaOverrideOutlineAndOcclusion) == "function" then
                        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
                    end
                    if type(mesh.SetRenderCustomDepth) == "function" then
                        mesh:SetRenderCustomDepth(true)
                    end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then
                        mesh:SetCustomDepthStencilValue(255)
                    end
                end)
            end
        end
    end)
end

local function ApplyColorBodyV2(enemy, pc, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        
        -- [FIX CHỐNG GIẬT LAG ĐÔNG NGƯỜI]: Giới hạn tia Raycast Check Tường 0.3s một lần
        -- Tránh việc bắn hàng nghìn tia vật lý mỗi giây làm cháy CPU
        local curTime = os.clock()
        if markData.LastVisCheckTime == nil or (curTime - markData.LastVisCheckTime) > 0.3 then
            markData.LastVisCheckTime = curTime
            local isHidden = true
            pcall(function()
                if Valid(pc) and type(pc.LineOfSightTo) == "function" then
                    if pc:LineOfSightTo(enemy) then isHidden = false else isHidden = true end
                end
            end)
            markData.CachedHiddenState = isHidden
        end
        
        local hidden = markData.CachedHiddenState
        if hidden == nil then hidden = true end
        
        local cData = _G.LexusState.CustomTextData or {}
        local hiddenColor = {R = cData.HiddenR or 150, G = cData.HiddenG or 0, B = cData.HiddenB or 0, A = cData.HiddenA or 25}
        local visibleColor = {R = cData.VisibleR or 0, G = cData.VisibleG or 150, B = cData.VisibleB or 0, A = cData.VisibleA or 25}
        
        local finalColor = hidden and hiddenColor or visibleColor
        local colorHash = string.format("%d_%d_%d_%d", finalColor.R, finalColor.G, finalColor.B, finalColor.A)
        local currentMeshCount = #meshes
        local isMeshChanged = (markData.LastMeshCount ~= currentMeshCount)
        
        -- Nếu chưa có sự đổi màu / đổi số lượng quần áo thì ngắt luôn, tiết kiệm CPU
        if not isMeshChanged and markData.LastHiddenState == hidden and markData.LastColorHash == colorHash then return end
        
        -- [FIX RAM]: Xóa Material rác cũ đi khi địch đổi vũ khí/áo giáp để tránh rác VRAM
        if isMeshChanged and markData.MIDs then
            markData.MIDs = {}
        end

        markData.LastHiddenState = hidden
        markData.LastMeshCount = currentMeshCount
        markData.LastColorHash = colorHash
        markData.ColorApplied = true
        
        for meshIndex, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    mesh.LDMaxDrawDistance = -99999
                    mesh.MaxDrawDistanceOffset = -99999
                    mesh.CachedMaxDrawDistance = -99999
                    mesh.UseScopeDistanceCulling = true
                    mesh.PrimitiveShadingStrategy = 1
                    mesh.ShadingRate = 6
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        local matName = tostring(baseMat)
                        if string.find(matName, "Master_Mask", 1, true) then
                            if not markData.MIDs then markData.MIDs = {} end
                            
                            -- [FIX RÁC RAM]: Thay vì dùng tostring(mesh) sinh rác chuỗi, dùng index cục bộ
                            local meshKey = "Mesh_" .. tostring(meshIndex)
                            
                            if not markData.MIDs[meshKey] then markData.MIDs[meshKey] = {} end
                            local mid = markData.MIDs[meshKey][i]
                            if not Valid(mid) then
                                mid = mesh:CreateAndSetMaterialInstanceDynamic(i)
                                markData.MIDs[meshKey][i] = mid
                            end
                            if Valid(mid) then
                                mid:SetVectorParameterValue("颜色", finalColor)
                                mid:SetVectorParameterValue("Extra Light Color", finalColor)
                                mid:SetVectorParameterValue("Para_Color", finalColor)
                                mid:SetVectorParameterValue("Para_ColorTint", finalColor)
                                mid:SetVectorParameterValue("Para_Color_1", finalColor)
                                mid:SetVectorParameterValue("Tint", finalColor)
                                mid:SetVectorParameterValue("Color", finalColor)
                                mid:SetVectorParameterValue("BaseColor", finalColor)
                                mid:SetVectorParameterValue("BodyColor", finalColor)
                                mid:SetVectorParameterValue("MainColor", finalColor)
                                mid:SetVectorParameterValue("DiffuseColor", finalColor)
                                mid:SetVectorParameterValue("EmissiveColor", finalColor)
                                mid:SetVectorParameterValue("ParaScaleOffset", SCALE_COLOR_V2)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function UndoColorBodyV2(enemy, markData)
    pcall(function()
        if markData.ColorApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for meshIndex, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        mesh.PrimitiveShadingStrategy = 0
                        mesh.ShadingRate = 1
                    end)
                    local meshKey = "Mesh_" .. tostring(meshIndex)
                    if markData.MIDs and markData.MIDs[meshKey] then
                        for i, mid in pairs(markData.MIDs[meshKey]) do
                            if Valid(mid) then
                                local defC = {R=1, G=1, B=1, A=1}
                                mid:SetVectorParameterValue("颜色", defC)
                                mid:SetVectorParameterValue("Extra Light Color", defC)
                                mid:SetVectorParameterValue("Para_Color", defC)
                                mid:SetVectorParameterValue("Para_ColorTint", defC)
                                mid:SetVectorParameterValue("Para_Color_1", defC)
                                mid:SetVectorParameterValue("Tint", defC)
                                mid:SetVectorParameterValue("Color", defC)
                                mid:SetVectorParameterValue("BaseColor", defC)
                                mid:SetVectorParameterValue("BodyColor", defC)
                                mid:SetVectorParameterValue("MainColor", defC)
                                mid:SetVectorParameterValue("DiffuseColor", defC)
                                mid:SetVectorParameterValue("EmissiveColor", defC)
                            end
                        end
                    end
                end
            end
            markData.ColorApplied = false
            markData.LastColorHash = ""
            markData.LastHiddenState = nil
        end
    end)
end

-- ========================================== 
-- HỆ THỐNG AIMBOT V2 TÍCH HỢP MỚI (UPDATE KISMET SMOOTH)
-- ========================================== 
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()

    if not slua.isValid(player) then
        return result
    end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        if not _G.LexusConfig.CustomAimbot then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end
        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        
        -- CHECK WEAPON & AMMO
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        local isShotgun = false
        local isSniper = false
        local currentAmmo = 1
        
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then 
                isShotgun = true 
            end
            
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end
            
            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        -- LOGIC NHẢ CÒ SÚNG NẾU MẤT MỤC TIÊU / ĐỊCH CHẾT HOẶC SHOTGUN HẾT ĐẠN
        if _G.LexusState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.LexusState.IsAutoFiring = false
        end

        -- SHOTGUN HẾT ĐẠN NGƯNG AIM ĐỂ GAME NẠP ĐẠN
        if isShotgun and currentAmmo <= 0 then
            return
        end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 50
        local fovVal = 30
        local maxDistMeters = 50
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        
        -- Logic thêm vào: Dự đoán và Bù giật
        local predVal = 0 
        local recoilCompVal = 0 

        -- PHÂN LOẠI CẤU HÌNH THEO TRẠNG THÁI HIỆN TẠI
        if isShotgun and _G.LexusConfig.AimTouchSG then
            cond = _G.LexusState.CustomTextData.AimTouchSGCond or 1
            if _G.LexusConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.LexusState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.LexusState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.LexusState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.LexusState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.LexusState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.LexusConfig.AimTouchSGVisCheck
            igKnock = _G.LexusConfig.AimTouchSGIgKnock
            igBot = _G.LexusConfig.AimTouchSGIgBot
            
        elseif isADS then
            if isSniper and _G.LexusConfig.AimTouchScopeSniper then
                cond = _G.LexusState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.LexusState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.LexusState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.LexusState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.LexusState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.LexusState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.LexusConfig.AimTouchSniperVisCheck
                igKnock = _G.LexusConfig.AimTouchSniperIgKnock
                igBot = _G.LexusConfig.AimTouchSniperIgBot
                predVal = _G.LexusState.CustomTextData.AimTouchSniperPred or 0 -- Lấy giá trị dự đoán Sniper
            elseif _G.LexusConfig.AimTouchScopeAll then
                cond = _G.LexusState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.LexusState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = _G.LexusState.CustomTextData.AimTouchScopeBone or 2
                speedVal = _G.LexusState.CustomTextData.AimTouchScopeSpeed or 40
                fovVal = _G.LexusState.CustomTextData.AimTouchScopeFOV or 20
                maxDistMeters = _G.LexusState.CustomTextData.AimTouchScopeDist or 300
                useVisCheck = _G.LexusConfig.AimTouchScopeVisCheck
                igKnock = _G.LexusConfig.AimTouchScopeIgKnock
                igBot = _G.LexusConfig.AimTouchScopeIgBot
                predVal = _G.LexusState.CustomTextData.AimTouchScopePred or 0 -- Lấy giá trị dự đoán Súng thường
                recoilCompVal = _G.LexusState.CustomTextData.AimTouchScopeRecoil or 0 -- Lấy giá trị bù giật
            else
                return
            end
        else
            if not _G.LexusConfig.AimTouchHipfire then return end
            cond = _G.LexusState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.LexusState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = _G.LexusState.CustomTextData.AimTouchHipBone or 1
            speedVal = _G.LexusState.CustomTextData.AimTouchHipSpeed or 50
            fovVal = _G.LexusState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.LexusState.CustomTextData.AimTouchHipDist or 250
            useVisCheck = _G.LexusConfig.AimTouchHipVisCheck
            igKnock = _G.LexusConfig.AimTouchHipIgKnock
            igBot = _G.LexusConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100 

        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end
        
        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = require("client.common.ui_util")
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999 
        
        local selBoneName = "head"
        if boneIdx == 1 then selBoneName = "head"
        elseif boneIdx == 2 then selBoneName = "spine_03"
        elseif boneIdx == 3 then selBoneName = "spine_01"
        elseif boneIdx == 4 then selBoneName = "pelvis" end

        for i, target in ipairs(enemies) do
            if not slua.isValid(target) then goto continue end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then goto continue end
            
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then goto continue end
            end
            
            -- [FIX TỤT FPS]: Khóa tia Raycast check tường, chỉ quét 0.2s một lần (Đủ mượt mà không cháy CPU)
            if useVisCheck then
                local curTime = os.clock()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then goto continue end
            end
            
            local tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then goto continue end
            
            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end
            
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            
            if distScreen > FOV_RADIUS then goto continue end
            
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            
            ::continue::
        end
        
        if not slua.isValid(bestTarget) then return end
        
        local finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end
        
        -- LOGIC 1: PREDICTION (DỰ ĐOÁN HƯỚNG CHẠY)
        if predVal > 0 then
            pcall(function()
                local tVelocity = nil
                -- Unreal Engine Lấy vector di chuyển của địch
                if type(bestTarget.GetVelocity) == "function" then
                    tVelocity = bestTarget:GetVelocity()
                end
                
                -- Nếu địch đang di chuyển
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0 -- Khoảng cách mét
                    
                    -- Tính toán thời gian đạn bay (Time-Of-Flight) tỉ lệ thuận với khoảng cách và biến truyền vào
                    -- Hệ số 800.0 đại diện cho tốc độ đạn rơi giả lập, 50.0 là mức trung bình slider
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0) 
                    
                    -- Dịch chuyển toạ độ Aim lên trước hướng chạy
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        
        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch
        
        -- [BẮT ĐẦU FIX] Bù trừ chênh lệch Camera khi mở ống ngắm (ADS) để không bị lệch tâm
        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end
        -- [KẾT THÚC FIX]

        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        local smoothFactor = 0.0
        if speedVal >= 100 then
            smoothFactor = 1.0
        else
            smoothFactor = (speedVal / 100.0) * 0.3
            if smoothFactor < 0.01 then smoothFactor = 0.01 end
        end
        
        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
        
        -- LOGIC 2: RECOIL COMPENSATION (ÉP TÂM / BÙ GIẬT TRÁNH BẮN QUÁ ĐẦU)
        -- Chỉ ép tâm khi súng đang bắn và giá trị Recoil > 0 (Dùng cho Súng thường)
        if recoilCompVal > 0 and isFiring then
            -- Trong UE4, kéo Pitch xuống (nhỏ đi) tương đương với việc ghìm tâm màn hình xuống
            -- Slider recoilCompVal (0-50), mỗi frame bù một lượng dựa trên độ giật
            local pullDownForce = (recoilCompVal / 50.0) * 1.5 -- Điều chỉnh nhân tố 1.5 tuỳ ý để ép gắt hơn
            finalPitch = finalPitch - pullDownForce
        end

        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
        
        if isShotgun and _G.LexusConfig.AimTouchSGAutoFire then
            pcall(function()
                local distToTarget = player:GetDistanceTo(bestTarget) / 100
                if distToTarget <= maxDistMeters then
                    player.bIsWeaponFiring = true
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = true end
                    
                    local currentWep = player:GetCurrentWeapon()
                    if slua.isValid(currentWep) and type(currentWep.StartFire) == "function" then 
                        currentWep:StartFire() 
                    end
                    _G.LexusState.IsAutoFiring = true
                end
            end)
        end

    end)
end

-- ========================================== 
-- VÒNG LẶP CHÍNH (MAIN LOOP) TỐI ƯU CỰC MẠNH
-- ========================================== 
-- ===================================================================================
-- ENEMY COUNTER SYSTEM
-- ===================================================================================
local BTN_BP = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"

local function GetVisibility()
    local UEnums = _G.UEnums or {}
    if UEnums.ESlateVisibility and UEnums.ESlateVisibility.SelfHitTestInvisible then
        return UEnums.ESlateVisibility.SelfHitTestInvisible
    end
    local ok, res = pcall(function() return import("ESlateVisibility").SelfHitTestInvisible end)
    return (ok and res) and res or 2
end

local function GetOrCreateWidget(globalName, posX, posY, sizeX, sizeY)
    local FAnchors = _G.FAnchors or import("FAnchors")
    local FVector2D = _G.FVector2D or import("Vector2D")
    local UIContainers = _G.UIContainers or { Top = 100 }

    if _G[globalName] and slua.isValid(_G[globalName]) then
        return _G[globalName]
    end

    local ok, btn = pcall(function()
        local ui = slua.loadUI(BTN_BP)
        if not ui or not slua.isValid(ui) then return nil end
        
        local hud = require("game_frontend_hud")
        if hud and hud.AddToContainer then
            hud.AddToContainer(UIContainers.Top, ui, 10500)
        end

        local WidgetLayoutLibrary = import("WidgetLayoutLibrary")
        local slot = WidgetLayoutLibrary.SlotAsCanvasSlot(ui)
        if slot then
            slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
            slot:SetAlignment(FVector2D(0.5, 0))
            slot:SetPosition(FVector2D(posX, posY))
            slot:SetSize(FVector2D(sizeX, sizeY))
        end

        ui:SetWidgetVisibility(GetVisibility())
        return ui
    end)

    if ok and btn then
        _G[globalName] = btn
        return btn
    end
    return nil
end

local function SetWidgetStyleAndColor(btn, text, fontSize, textR, textG, textB, bgR, bgG, bgB, bgA)
    if not btn or not slua.isValid(btn) then return end
    
    local FLinearColor = _G.FLinearColor or import("LinearColor")
    local FSlateColor = _G.FSlateColor or import("SlateColor")

    if btn.RichText_Content then
        btn.RichText_Content:SetText(text)
        local fontInfo = btn.RichText_Content.Font
        if fontInfo then
            fontInfo.Size = fontSize
            btn.RichText_Content:SetFont(fontInfo)
        end
        if FLinearColor and FSlateColor then
            btn.RichText_Content:SetColorAndOpacity(FSlateColor(FLinearColor(textR, textG, textB, 1.0)))
        end
    end

    pcall(function()
        local colorObj = FLinearColor(bgR, bgG, bgB, bgA)
        if btn.SetColorAndOpacity then
            btn:SetColorAndOpacity(colorObj)
        end
        if btn.SetBackgroundColor then
            btn:SetBackgroundColor(colorObj)
        end
    end)
end

local function RemoveWidget(globalName)
    if _G[globalName] and slua.isValid(_G[globalName]) then
        _G[globalName]:RemoveFromParent()
        _G[globalName] = nil
    end
end

local function IsRealBot(enemy)
    if not slua.isValid(enemy) then return false end
    
    if enemy.bIsAI or enemy.IsBot or enemy.bIsBot then return true end
    
    if enemy.PlayerState then
        local ps = enemy.PlayerState
        if ps.bIsABot or ps.bIsAIPlayer or ps.bIsAI then return true end
        if ps.Ping == 0 or ps.Ping == nil then
            if ps.PlayerID and ps.PlayerID < 100000 then return true end
        end
    end
    
    return false
end

local function _M_DrawCounter()
    local expired = false
    if type(isExpired) == "function" then expired = isExpired() else expired = isExpired end

    if expired then
        RemoveWidget("MainCounterWidget_Global")
        return
    end

    pcall(function()
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end

        local myTeamId = player.TeamID or 0
        local myPos = nil
        pcall(function()
            if type(player.K2_GetActorLocation) == "function" then
                myPos = player:K2_GetActorLocation()
            end
        end)
        if not myPos then return end

        local totalEnemies = 0
        local MAX_DIST_SQ = 900000000 -- same distance limit as file 2

        local allPawns = Game:GetAllPlayerPawns() or {}
        for _, pawn in pairs(allPawns) do
            if slua.isValid(pawn) and pawn ~= player then
                local pawnTeam = pawn.TeamID or 0
                if pawnTeam ~= myTeamId then
                    local pos = nil
                    pcall(function()
                        if type(pawn.K2_GetActorLocation) == "function" then
                            pos = pawn:K2_GetActorLocation()
                        end
                    end)

                    if pos then
                        local dx = pos.X - myPos.X
                        local dy = pos.Y - myPos.Y
                        local dz = pos.Z - myPos.Z
                        if dx*dx + dy*dy + dz*dz <= MAX_DIST_SQ then
                            totalEnemies = totalEnemies + 1
                        end
                    end
                end
            end
        end

        local mainWidget = GetOrCreateWidget("MainCounterWidget_Global", 0, 15, 140, 32)

        if totalEnemies > 0 then
            local txt = string.format("%d", totalEnemies)
            SetWidgetStyleAndColor(
                mainWidget, txt, 15,
                0.0, 0.0, 0.0, 1.0,
                0.686, 0.078, 1.0
            )
        else
            SetWidgetStyleAndColor(
                mainWidget, "امن", 14,
                0.0, 0.0, 0.0, 0.357,
                1.0, 0.310, 1.0
            )
        end
    end)
end

local function MainLoop() 
    if isExpired then return end

    pcall(function()
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and not _G.FakeHWID_Hooked then
            -- Lưu lại hàm lấy HWID gốc
            _G.Original_GetDeviceId = SystemLib.GetDeviceId

            -- Ghi đè hàm của game
            SystemLib.GetDeviceId = function(...)
                if _G.LexusConfig.FakeHWID then
                    if not _G.FakeHWID_String then
                        -- Tạo ngẫu nhiên một HWID ảo 32 ký tự
                        local chars = "0123456789abcdef"
                        local hwid = ""
                        for i = 1, 32 do 
                            hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) 
                        end
                        _G.FakeHWID_String = hwid
                    end
                    -- Trả về HWID ảo
                    return _G.FakeHWID_String
                end
                
                -- Nếu tắt Fake HWID thì trả về HWID thật
                if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                return "UNKNOWN"
            end
            _G.FakeHWID_Hooked = true
        end
    end)

    -- Hàm độc lập để bạn lấy HWID Gốc (nếu sau này cần hiển thị)
    _G.GetOriginalHWID = function()
        if _G.Original_GetDeviceId then
            return tostring(_G.Original_GetDeviceId())
        end
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and type(SystemLib.GetDeviceId) == "function" then
            return tostring(SystemLib.GetDeviceId())
        end
        return "UNKNOWN_DEVICE"
    end
    -- =====================================================================

    if _G.LexusState.CustomTextData == nil then 
        _G.LexusState.CustomTextData = {OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120, AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250, AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30, AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400}
    end

    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GameplayData then return end 
    local pc = GameplayData.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 

    -- XÓA SẠCH SÀNH SANH RÁC KHỎI RAM KHI BẠN CHẾT, ĐỔI MAP, VÀO SẢNH
    if not Valid(localPlayer) then 
        if _G.LexusState.TrackedMarks then
            for markId, _ in pairs(_G.LexusState.TrackedMarks) do
                SafeRemoveMark(markId)
            end
        end
        _G.LexusState.TrackedMarks = {} 
        
        -- Dọn sạch object UE4 MIDs để giải phóng RAM tối đa qua nhiều trận
        for key, data in pairs(_G.LexusState.EnemyMarks) do
            if data and data.MIDs then
                for meshStr, midTable in pairs(data.MIDs) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs = nil
            end
        end
        
        _G.LexusState.EnemyMarks = {}
        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.LexusState.PrevGraphicsState = {}
        return 
    end

    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_SecurityCommonUtils = nil
    pcall(function() Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.LexusConfig.UnlockFPS then InitializeGraphicsUnlock() end
    InitializeNativeESP()
    pcall(_M_DrawCounter)
    ShowLexusVIPMenu()
    
    -- HOÀN TRẢ GÓC NHÌN NGAY LẬP TỨC NẾU TẮT IPAD VIEW
    if _G.LexusConfig.IpadView and _G.LexusState.CustomTextData then
        pcall(function()
            local targetTPP = _G.LexusState.CustomTextData.IpadViewFOV or 120
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= targetTPP then uTPPCam.FieldOfView = targetTPP end
            end
        end)
    else
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= 90 then uTPPCam.FieldOfView = 90 end
            end
        end)
    end

-- ========================================================
-- LOGIC AIMBOT V2 ROYAL/CUSTOM - يعمل فقط عند تفعيل زر الإيمبوت
-- ========================================================
if _G.LexusConfig.CustomAimbot then
    _G.AimTouch()
end
    
    -- ========================================================
    -- LOGIC BÙ GIẬT (GHÌM TÂM) CHỈ DÀNH RIÊNG CHO AIMBOT GỐC (ĐÃ FIX LAG ĐÔNG NGƯỜI)
    -- ========================================================
    pcall(function()
        if _G.LexusConfig.CustomAimbot and localPlayer.bIsWeaponFiring and localPlayer.bIsGunADS then
            local outerRecoilVal = _G.LexusState.CustomTextData.OuterRecoil or 0
            if outerRecoilVal > 0 then
                local curTime = os.clock()
                
                -- [FIX CPU CỰC MẠNH]: Quét mục tiêu 0.2s/lần thay vì 100 lần/giây để tránh quá tải máy khi check FOV
                if not _G.RecoilTargetCacheTime or (curTime - _G.RecoilTargetCacheTime) > 0.2 then
                    _G.RecoilTargetCacheTime = curTime
                    _G.HasRecoilTargetCached = false
                    
                    local ui_util = require("client.common.ui_util")
                    if ui_util then
                        local viewportSize = ui_util.GetViewportSize()
                        if viewportSize then
                            local centerX = viewportSize.X * 0.5
                            local centerY = viewportSize.Y * 0.5
                            local FOV_RADIUS = (6 / 100.0) * (viewportSize.X / 2.0) 
                            
                            local enemies = _G.GetEnemyTargetsFromActors(40000) 
                            if enemies and #enemies > 0 then
                                local FVector2D = import("Vector2D")
                                for _, target in ipairs(enemies) do
                                    if slua.isValid(target) and target.HealthStatus ~= 1 then 
                                        local tPos = type(target.K2_GetActorLocation) == "function" and target:K2_GetActorLocation() or nil
                                        if tPos then
                                            local screen = FVector2D()
                                            if pc:ProjectWorldLocationToScreen(tPos, screen, false) and screen.X > 0 and screen.Y > 0 then
                                                local dx = screen.X - centerX
                                                local dy = screen.Y - centerY
                                                if math.sqrt(dx*dx + dy*dy) <= FOV_RADIUS then
                                                    _G.HasRecoilTargetCached = true
                                                    break 
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if _G.HasRecoilTargetCached then
                    local currentRot = pc:GetControlRotation()
                    if currentRot then
                        local pullDownForce = (outerRecoilVal / 50.0) * 1.5
                        currentRot.Pitch = currentRot.Pitch - pullDownForce
                        pc:SetControlRotation(currentRot, "CustomAimbotRecoil")
                    end
                end
            end
        else
            _G.HasRecoilTargetCached = false
        end
    end)
    
    -- ========================================================
    -- THỰC THI MOD SKIN ĐƯỢC TÍCH HỢP TRỰC TIẾP VÀO MAIN LOOP (TỐI ƯU TUYỆT ĐỐI)
    -- ========================================================
    if _G.LexusConfig.ModSkin then
        if not _G.TDSkinLoopStarted then
            if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
            if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
            _G.TDSkinLoopStarted = true
        end
        
        _G.LexusState.SkinWasApplied = true
        local curTime = os.clock()
        
        -- [FIX CHỐNG ĐƠ VÀ DROP FPS]: Chỉ thực thi logic Skin 1.5 giây một lần (nhưng skin vẫn đổi ngay lập tức nhờ Cache)
        if not _G.LastSkinUpdateTime or (curTime - _G.LastSkinUpdateTime) > 1.5 then
            _G.LastSkinUpdateTime = curTime
            
            pcall(function()
                -- Ngắt hoàn toàn Mod Skin khi bạn đã chết hoặc đang hiện TOP 1 (Chống đơ đứng máy cuối trận)
                local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                
                if isAlive then
                    if _G.ReadLiveConfig then _G.ReadLiveConfig() end
                    if not _G.KillInfoCounterHacked and _G.ForceEnableKillCounterUI then _G.ForceEnableKillCounterUI() end
                    if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
                    if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(localPlayer) end
                    if _G.ApplyVehicleSkins then _G.ApplyVehicleSkins(localPlayer) end
                    if _G.HandlePetLogic then _G.HandlePetLogic() end
                    if _G.DeadBox_TemperRequest and _G.NeedCheckDeadBoxTimer > 0 then _G.DeadBox_TemperRequest(pc) end
                end
            end)
        end
    else
        -- HOÀN TRẢ LẠI SKIN GỐC KHI TẮT
        if _G.LexusState.SkinWasApplied then
            _G.OutfitMap = {}
            _G.WeaponSkinMap = {}
            _G.VehicleSkinMap = {}
            
            pcall(function()
                local WeaponManager = localPlayer:GetWeaponManager()
                if Valid(WeaponManager) then
                    for slot = 1, 3 do
                        local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
                        if Valid(Weapon) and Valid(Weapon.synData) then
                            local WeaponID = Weapon:GetWeaponID()
                            local SkinData = Weapon.synData:Get(7)
                            if SkinData and SkinData.defineID then
                                SkinData.defineID.TypeSpecificID = WeaponID
                                Weapon.synData:Set(7, SkinData)
                                if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(WeaponID) end) end
                                if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                            end
                        end
                    end
                end
                
                local Vehicle = localPlayer:GetCurrentVehicle()
                if Valid(Vehicle) then
                    local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
                    if Valid(VehicleAvatar) and type(VehicleAvatar.GetDefaultAvatarID) == "function" then
                        local defId = VehicleAvatar:GetDefaultAvatarID()
                        if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(defId, true) end
                    end
                end
                
                if localPlayer.AvatarComponent2 and type(localPlayer.AvatarComponent2.OnRep_BodySlotStateChanged) == "function" then
                    localPlayer.AvatarComponent2:OnRep_BodySlotStateChanged()
                end
            end)
            
            _G.LexusState.SkinWasApplied = false
        end
        _G.TDSkinLoopStarted = false
    end

    -- CHẶN HIGGSBOSON THEO THỜI GIAN THỰC LÀM AN TOÀN TUYỆT ĐỐI MÀ KHÔNG GÂY VĂNG GAME
    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    -- HOÀN TRẢ VÀ THIẾT LẬP AIMBOT HEAD COMPONENT BẬT/TẮT TỨC THÌ
    pcall(function()
        local autoComp = localPlayer.AutoAimComp
        if Valid(autoComp) then
            if not _G.LexusState.OrigAutoAimCompCached then
                _G.LexusState.OrigAutoAimCompCached = {
                    bOnlyHitHead = autoComp.bOnlyHitHead,
                    HeadBoneName = autoComp.HeadBoneName,
                    Bones = autoComp.Bones,
                    ChestBoneName = autoComp.ChestBoneName,
                    PelvisBoneName = autoComp.PelvisBoneName,
                    HeadPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.HeadPriority,
                    ChestPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.ChestPriority,
                    PelvisPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.PelvisPriority
                }
            end
            
            if _G.LexusConfig.AutoHead then
                autoComp.bOnlyHitHead = true
                autoComp.HeadBoneName = "Head"
                pcall(function() autoComp.Bones = {"Head"} end)
                autoComp.ChestBoneName = "Head"
                autoComp.PelvisBoneName = "Head"
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = 100
                    autoComp.AimAssistConfig.ChestPriority = 100
                    autoComp.AimAssistConfig.PelvisPriority = 100
                end
            else
                local orig = _G.LexusState.OrigAutoAimCompCached
                autoComp.bOnlyHitHead = orig.bOnlyHitHead
                autoComp.HeadBoneName = orig.HeadBoneName
                pcall(function() autoComp.Bones = orig.Bones or {"Spine_01", "Pelvis", "Head"} end)
                autoComp.ChestBoneName = orig.ChestBoneName
                autoComp.PelvisBoneName = orig.PelvisBoneName
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = orig.HeadPriority or 1
                    autoComp.AimAssistConfig.ChestPriority = orig.ChestPriority or 1
                    autoComp.AimAssistConfig.PelvisPriority = orig.PelvisPriority or 1
                end
            end
        end
    end)

    if _G.LexusConfig.WallClimb then
        pcall(function()
            local charMove = localPlayer.CharacterMovement
            if Valid(charMove) then
                if not _G.LexusState.WallClimbOriginals then
                    _G.LexusState.WallClimbOriginals = { WalkableFloorAngle = charMove.WalkableFloorAngle, MaxStepHeight = charMove.MaxStepHeight }
                end
                charMove.WalkableFloorAngle = 199.0
                charMove.MaxStepHeight = 999.0
                _G.LexusState.WallClimbApplied = true
            end
        end)
    elseif _G.LexusState.WallClimbApplied then
        pcall(function()
            local charMove = localPlayer.CharacterMovement
            if Valid(charMove) and _G.LexusState.WallClimbOriginals then
                charMove.WalkableFloorAngle = _G.LexusState.WallClimbOriginals.WalkableFloorAngle or 50.0
                charMove.MaxStepHeight = _G.LexusState.WallClimbOriginals.MaxStepHeight or 45.0
            end
        end)
        _G.LexusState.WallClimbApplied = false
    end

    if _G.LexusConfig.FastCar then
        pcall(function()
            local currentVehicle = localPlayer.CurrentVehicle or (type(localPlayer.GetVehicle) == "function" and localPlayer:GetVehicle())
            if Valid(currentVehicle) then
                local rootComp = currentVehicle.RootComponent or (type(currentVehicle.K2_GetRootComponent) == "function" and currentVehicle:K2_GetRootComponent())
                
                if Valid(rootComp) and type(rootComp.SetAllPhysicsLinearVelocity) == "function" then
                    local isAccelerating = false
                    local moveComp = currentVehicle.VehicleMovement or currentVehicle.MovementComponent
                    if Valid(moveComp) then
                        local throttle = moveComp.ThrottleInput or 0
                        if type(moveComp.GetThrottleInput) == "function" then
                            throttle = moveComp:GetThrottleInput()
                        end
                        if throttle > 0.05 or throttle < -0.05 then 
                            isAccelerating = true
                        end
                    end
                    if currentVehicle.bIsPressingGas or (currentVehicle.Throttle and currentVehicle.Throttle ~= 0) then
                        isAccelerating = true
                    end

                    local currentVel = nil
                    if type(currentVehicle.GetVelocity) == "function" then
                        currentVel = currentVehicle:GetVelocity()
                    elseif type(rootComp.GetPhysicsLinearVelocity) == "function" then
                        currentVel = rootComp:GetPhysicsLinearVelocity()
                    elseif rootComp.ComponentVelocity then
                        currentVel = rootComp.ComponentVelocity
                    end

                    if currentVel then
                        local currentSpeed = math.sqrt(currentVel.X^2 + currentVel.Y^2)
                        local minSpeedToBoost = 50.0   
                        local maxSpeed = 4444.0        
                        local accelFactor = 1.5        
                        local brakeFactor = 0.85       
                        
                        if currentSpeed > minSpeedToBoost then
                            local dirX = currentVel.X / currentSpeed
                            local dirY = currentVel.Y / currentSpeed
                            
                            if isAccelerating then
                                local targetSpeed = currentSpeed * accelFactor
                                if targetSpeed > maxSpeed then targetSpeed = maxSpeed end
                                local newX = dirX * targetSpeed
                                local newY = dirY * targetSpeed
                                local newZ = currentVel.Z 
                                rootComp:SetAllPhysicsLinearVelocity(FVector(newX, newY, newZ), false)
                            else
                                local targetSpeed = currentSpeed * brakeFactor
                                if targetSpeed > minSpeedToBoost then
                                    local newX = dirX * targetSpeed
                                    local newY = dirY * targetSpeed
                                    local newZ = currentVel.Z 
                                    rootComp:SetAllPhysicsLinearVelocity(FVector(newX, newY, newZ), false)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    -- HOÀN TRẢ ĐỒ HỌA NGAY LẬP TỨC NẾU TẮT (TẮT LÀ TẮT LIỀN)
    local now = os.clock()
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if _G.LexusConfig.RemoveGrass and not _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "0")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
                _G.LexusState.PrevGraphicsState.RemoveGrass = true
            elseif not _G.LexusConfig.RemoveGrass and _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "1")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
                _G.LexusState.PrevGraphicsState.RemoveGrass = false
            end

            -- LOGIC XÓA CÂY
            if _G.LexusConfig.RemoveTrees and not _G.LexusState.PrevGraphicsState.RemoveTrees then
                gi:ExecuteCMD("foliage.DensityScale", "0")
                gi:ExecuteCMD("r.Foliage.DensityScale", "0")
                gi:ExecuteCMD("foliage.MinimumScreenSize", "10000")
                gi:ExecuteCMD("r.DisableTreeRender", "1")
                _G.LexusState.PrevGraphicsState.RemoveTrees = true
            elseif not _G.LexusConfig.RemoveTrees and _G.LexusState.PrevGraphicsState.RemoveTrees then
                gi:ExecuteCMD("foliage.DensityScale", "1")
                gi:ExecuteCMD("r.Foliage.DensityScale", "1")
                gi:ExecuteCMD("foliage.MinimumScreenSize", "0.0001")
                gi:ExecuteCMD("r.DisableTreeRender", "0")
                _G.LexusState.PrevGraphicsState.RemoveTrees = false
            end
            
            if _G.LexusConfig.RemoveFog and not _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "0")           
                gi:ExecuteCMD("r.VolumetricFog", "0") 
                _G.LexusState.PrevGraphicsState.RemoveFog = true
            elseif not _G.LexusConfig.RemoveFog and _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "1")           
                gi:ExecuteCMD("r.VolumetricFog", "1") 
                _G.LexusState.PrevGraphicsState.RemoveFog = false
            end
            
            if _G.LexusConfig.WhiteBody and not _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "2")
                gi:ExecuteCMD("r.CharacterDiffusePower", "5")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "100")
                _G.LexusState.PrevGraphicsState.WhiteBody = true
            elseif not _G.LexusConfig.WhiteBody and _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                _G.LexusState.PrevGraphicsState.WhiteBody = false
            end
            
            if _G.LexusConfig.ColorBodyV2 and not _G.LexusState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "4")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "200")
                gi:ExecuteCMD("r.CharacterDiffusePower", "200")
                _G.LexusState.PrevGraphicsState.ColorBodyV2 = true
            elseif not _G.LexusConfig.ColorBodyV2 and _G.LexusState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                _G.LexusState.PrevGraphicsState.ColorBodyV2 = false
            end
            
            -- LOGIC BLACKSKY
            if _G.LexusConfig.BlackSky and not _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.LexusState.PrevGraphicsState.BlackSky = true
            elseif not _G.LexusConfig.BlackSky and _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.LexusState.PrevGraphicsState.BlackSky = false
            end
        end
    end)

    pcall(function()
        local weapon = nil
        pcall(function()
            local weaponManager = localPlayer.WeaponManagerComponent
            if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
                weapon = weaponManager:GetCurrentWeapon()
            end
        end)
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
            elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
        end

        if Valid(weapon) then
            local entities = {}
            if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
            if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
            if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then 
                table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent) 
            end

            for _, entity in ipairs(entities) do
                local anyWeaponModOn = _G.LexusConfig.CustomHRecoil or _G.LexusConfig.CustomVRecoil or _G.LexusConfig.LessShake or _G.LexusConfig.Accuracy or _G.LexusConfig.Crosshair or _G.LexusConfig.GodMode or _G.LexusConfig.AutoHead or _G.LexusConfig.CustomAimbot or _G.LexusConfig.CustomAimbotClose or _G.LexusConfig.AimbotMode ~= "None" or _G.LexusConfig.LessRecoil or _G.LexusConfig.VerticalRecoil

                if anyWeaponModOn then
                    if not entity.OriginalStatsCached then
                        entity.OriginalStatsCached = {
                            GameDeviationFactor = entity.GameDeviationFactor,
                            GameDeviationAccuracy = entity.GameDeviationAccuracy,
                            BulletFireSpeed = entity.BulletFireSpeed,
                            ShootInterval = entity.ShootInterval,
                            BaseDamage = entity.BaseDamage,
                            AccessoriesHRecoilFactor = entity.AccessoriesHRecoilFactor,
                            AccessoriesVRecoilFactor = entity.AccessoriesVRecoilFactor,
                            RecoilKick = entity.RecoilKick,
                            RecoilKickADS = entity.RecoilKickADS,
                            AnimationKick = entity.AnimationKick
                        }
                    end
                    
                    if _G.LexusConfig.CustomHRecoil then entity.AccessoriesHRecoilFactor = _G.LexusState.CustomTextData.HRecoil or 0.3 
                    elseif _G.LexusConfig.LessRecoil then entity.AccessoriesHRecoilFactor = 0.3 end
                    
                    if _G.LexusConfig.CustomVRecoil then entity.AccessoriesVRecoilFactor = _G.LexusState.CustomTextData.VRecoil or 0.3
                    elseif _G.LexusConfig.VerticalRecoil then entity.AccessoriesVRecoilFactor = 0.3 end
                    
                    if _G.LexusConfig.LessShake then entity.RecoilKick = 0.0; entity.RecoilKickADS = 0.0; entity.AnimationKick = 0.0 end
                    if _G.LexusConfig.Accuracy then entity.GameDeviationAccuracy = 0.0 end
                    if _G.LexusConfig.Crosshair then entity.GameDeviationFactor = 0.0 end
                    if _G.LexusConfig.GodMode then entity.BulletFireSpeed = 500000.0; entity.ShootInterval = 0.001; entity.BaseDamage = 60000.0 end
                    
                    if entity.AutoAimingConfig then
                        if not entity.OriginalAutoAimCached then
                            entity.OriginalAutoAimCached = {
                                OuterSpeed = entity.AutoAimingConfig.OuterRange and entity.AutoAimingConfig.OuterRange.Speed,
                                InnerSpeed = entity.AutoAimingConfig.InnerRange and entity.AutoAimingConfig.InnerRange.Speed
                            }
                        end
                        
                        if _G.LexusConfig.AutoHead then
                            pcall(function() entity.AutoAimingConfig.Bones = { "Head", "Head", "Head" } end)
                        end
                        
                        if _G.LexusConfig.CustomAimbot then
                            local speed = _G.LexusState.CustomTextData.OuterSpeed or 10
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.RangeRate = 4.5
                                entity.AutoAimingConfig.OuterRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.OuterRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.OuterRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.OuterRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.OuterRange.ProneRate = 1.0
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.RangeRate = 4.5
                                entity.AutoAimingConfig.InnerRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.InnerRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.InnerRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.InnerRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.InnerRange.ProneRate = 1.0
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        elseif _G.LexusConfig.CustomAimbotClose or _G.LexusConfig.AimbotMode == "Close" then
                            local speed = _G.LexusState.CustomTextData.InnerSpeed or 10
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        elseif _G.LexusConfig.AimbotMode == "Far" then
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = 5
                                entity.AutoAimingConfig.OuterRange.RangeRate = 0.7
                                entity.AutoAimingConfig.OuterRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.OuterRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.OuterRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.OuterRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.OuterRange.ProneRate = 1
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = 5
                                entity.AutoAimingConfig.InnerRange.RangeRate = 0.7
                                entity.AutoAimingConfig.InnerRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.InnerRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.InnerRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.InnerRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.InnerRange.ProneRate = 1
                            end
                        end
                    end
                    
                    entity.LexusWeaponModsActive = true

                elseif entity.LexusWeaponModsActive then
                    if entity.OriginalStatsCached then
                        local orig = entity.OriginalStatsCached
                        entity.GameDeviationFactor = orig.GameDeviationFactor
                        entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
                        entity.BulletFireSpeed = orig.BulletFireSpeed
                        entity.ShootInterval = orig.ShootInterval
                        entity.BaseDamage = orig.BaseDamage
                        entity.AccessoriesHRecoilFactor = orig.AccessoriesHRecoilFactor
                        entity.AccessoriesVRecoilFactor = orig.AccessoriesVRecoilFactor
                        entity.RecoilKick = orig.RecoilKick
                        entity.RecoilKickADS = orig.RecoilKickADS
                        entity.AnimationKick = orig.AnimationKick
                    end
                    if entity.AutoAimingConfig and entity.OriginalAutoAimCached then
                        pcall(function() entity.AutoAimingConfig.Bones = { "Spine_01", "Pelvis", "Head" } end)
                        if entity.AutoAimingConfig.OuterRange and entity.OriginalAutoAimCached.OuterSpeed then
                            entity.AutoAimingConfig.OuterRange.Speed = entity.OriginalAutoAimCached.OuterSpeed
                        end
                        if entity.AutoAimingConfig.InnerRange and entity.OriginalAutoAimCached.InnerSpeed then
                            entity.AutoAimingConfig.InnerRange.Speed = entity.OriginalAutoAimCached.InnerSpeed
                        end
                    end
                    entity.LexusWeaponModsActive = false
                end
            end
        end
    end)

    local mHead_Global, mBody_Global, mLegs_Global = 1.0, 1.0, 1.0
    local runInject_Global = false
    
    pcall(function()
        if _G.LexusConfig.CustomMagicBullet then
            runInject_Global = true
            mHead_Global = 1.0; mBody_Global = 1.0; mLegs_Global = 1.0
            if _G.LexusState.CustomTextData then
                local cData = _G.LexusState.CustomTextData
                if cData.MagicHead ~= nil then mHead_Global = tonumber(cData.MagicHead) or mHead_Global end
                if cData.MagicBody ~= nil then mBody_Global = tonumber(cData.MagicBody) or mBody_Global end
                if cData.MagicLegs ~= nil then mLegs_Global = tonumber(cData.MagicLegs) or mLegs_Global end
            end
        elseif _G.LexusConfig.MagicBullet then
            runInject_Global = true
            mHead_Global = 1.05; mBody_Global = 1.0; mLegs_Global = 1.0
        end

        if runInject_Global then
            local currentMagicHash = "M_"..tostring(mHead_Global).."_"..tostring(mBody_Global).."_"..tostring(mLegs_Global)
            if _G.LexusState.LastMagicConfigHash ~= currentMagicHash then
                _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
                _G.LexusState.LastMagicConfigHash = currentMagicHash
            end
        else
            -- KHI MAGIC BULLET BỊ TẮT, RESTORE LẠI HASH VỀ 0
            if _G.LexusState.LastMagicConfigHash ~= "OFF" then
                _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
                _G.LexusState.LastMagicConfigHash = "OFF"
            end
        end
    end)

    pcall(function()
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end
        
        local currentValidKeys = {}
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer then
                currentValidKeys[GetSafeEnemyKey(enemy)] = true
            end
        end
        
        for key, data in pairs(_G.LexusState.EnemyMarks) do
            if not currentValidKeys[key] then
                SafeRemoveMark(data.radarMark)
                SafeRemoveMark(data.hpMark)
                SafeRemoveMark(data.distMark)
                
                -- [FIX RAM]: Dọn rác AimTouch VisCheck của địch đã chết hoặc văng quá xa
                if _G.AimTouchVisCache and _G.AimTouchVisCache[key] then
                    _G.AimTouchVisCache[key] = nil
                end
                
                if data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs = nil
                end
                
                data.enemy = nil
                data.CachedMeshes = nil
                _G.LexusState.EnemyMarks[key] = nil
            end
        end

        local realCount = 0
        local aiCount = 0

        local function GetFirstElemSafe(elemArray)
            if elemArray and type(elemArray.Num) == "function" and elemArray:Num() > 0 then
                if type(elemArray.Get) == "function" then return elemArray:Get(0) end
            elseif elemArray and type(elemArray) == "table" and #elemArray > 0 then
                return elemArray[1]
            end
            return nil
        end

        local BoneScaleMap = {
            ["head"] = mHead_Global, ["neck_01"] = mHead_Global,
            ["pelvis"] = mBody_Global, ["spine_01"] = mBody_Global, ["spine_02"] = mBody_Global, ["spine_03"] = mBody_Global,
            ["thigh_l"] = mLegs_Global, ["thigh_r"] = mLegs_Global, 
            ["calf_l"] = mLegs_Global, ["calf_r"] = mLegs_Global,   
            ["foot_l"] = mLegs_Global, ["foot_r"] = mLegs_Global    
        }
        
        local mLoc = nil
        pcall(function() if type(localPlayer.K2_GetActorLocation) == "function" then mLoc = localPlayer:K2_GetActorLocation() end end)

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local bIsReallyDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
                end)

                local eKey = GetSafeEnemyKey(enemy)
                _G.LexusState.EnemyMarks[eKey] = _G.LexusState.EnemyMarks[eKey] or { enemy = enemy }
                local markData = _G.LexusState.EnemyMarks[eKey]
                markData.enemy = enemy 

                if not bIsReallyDead then
                    -- [FIX LỖI MẤT MÁU KHI NHẢY DÙ/HỒI SINH]: Kiểm tra xem địch có bị đổi Actor (nhân vật mới) không.
                    -- Nếu có, xóa toàn bộ Marker (UI) bị kẹt ở xác cũ để code bên dưới vẽ lại lên nhân vật mới.
                    if markData.lastEnemyActor ~= enemy then
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end -- Xóa luôn rác của ESP 8
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                        if markData.radarMark then SafeRemoveMark(markData.radarMark); markData.radarMark = nil end
                        
                        markData.lastEnemyActor = enemy
                        markData.LastUIComp = nil
                        markData.LastFrameUIState = nil
                    end
                    
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    
                    -- إضافة كود Snaplines (الخط) باستخدام منطق AddDebugText المضمون
                    if _G.LexusConfig.EspSnaplines then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) and distM <= 400 then
                                -- رسم خط عمودي ممتد للسماء يربط اللاعب بالنظر
                                local loopCount = 10
                                local zStep = 1500
                                local baseZ = 100
                                for i = 1, loopCount do
                                    local zOffset = baseZ + (i * zStep)
                                    MyHUD:AddDebugText("|", enemy, 0.06, {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset}, C_SNAPLINE, true, false, true, nil, 1.5, true)
                                end
                            end
                        end)
                    end

                    local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
                    local isBot = markData.AK_IS_BOT or false

                    local currentMeshCount = 0
                    if Valid(eMesh) then
                        local tempMeshes = GetAllSkeletalMeshes(enemy, markData)
                        currentMeshCount = #tempMeshes
                    end
                    local isMeshChanged = (markData.LastMeshCountWall ~= currentMeshCount)

                    -- ĐÃ TỐI ƯU CỰC KỲ: Chỉ Apply khi thật sự cần
                    if _G.LexusConfig.WallXuyenTuong then
                        if isMeshChanged or not markData.WallhackApplied then
                            ApplyWallXuyenTuong(enemy, markData)
                            markData.WallhackApplied = true
                            markData.LastMeshCountWall = currentMeshCount
                        end
                    else
                        UndoWallXuyenTuong(enemy, markData)
                    end

                    -- ĐÃ TỐI ƯU CỰC KỲ
                    if _G.LexusConfig.ColorBodyV2 then 
                        -- TRONG HÀM NÀY TÔI ĐÃ GIỚI HẠN PC:LINEOFSIGHTTO LẠI ĐỂ TRÁNH QUÁ TẢI CPU
                        ApplyColorBodyV2(enemy, pc, markData) 
                    else
                        UndoColorBodyV2(enemy, markData)
                    end

                    -- BUG MÀN: KÉO DÃN KẺ ĐỊCH LÀM HITBOX TO RA (FAT BODY) - ĐÃ TỐI ƯU
                    pcall(function()
                        if Valid(eMesh) then
                            local targetScale = 1.0
                            if _G.LexusConfig.BugManEnable and _G.LexusState.CustomTextData then
                                targetScale = 177.0 / (_G.LexusState.CustomTextData.BugManRatio or 133)
                                if targetScale < 1.0 then targetScale = 1.0 end
                                if targetScale > 2.0 then targetScale = 2.0 end -- Chống lỗi đồ họa nếu kéo quá mức
                            end
                            
                            -- [FIX RÁC RAM]: Chỉ giãn xương khi có sự thay đổi (Bật/tắt hoặc kéo thanh trượt)
                            if markData.LastFatScale ~= targetScale then
                                eMesh:SetRelativeScale3D(FVector(targetScale, targetScale, 1.0))
                                markData.LastFatScale = targetScale
                            end
                        end
                    end)

                    -- LOGIC MAGIC BULLET (ĐÃ FIX LAG ĐÔNG NGƯỜI BẰNG UNIQUE ID)
                    pcall(function()
                        local EnemyMesh = eMesh
                        if slua.isValid(EnemyMesh) then
                            -- [FIX CPU CỰC MẠNH]: Dùng ID thật của nhân vật. Không dùng tostring() vì SLUA tự xóa/tạo lại chuỗi liên tục
                            -- gây lỗi tính toán lại 50 khung xương lặp đi lặp lại khi đông người.
                            local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
                            
                            -- Chỉ tính toán xương ĐÚNG 1 LẦN DUY NHẤT cho mỗi kẻ địch (trừ khi bạn kéo thanh chỉnh size)
                            if markData.MagicBulletHash == _G.LexusState.LastMagicConfigHash and markData.MagicTargetID == uniqueID then
                                return 
                            end

                            local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
                            if not slua.isValid(PhysicsAsset) and EnemyMesh.SkeletalMesh then PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset end

                            if slua.isValid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                                if not _G.AK_ModdedPhysAssets then _G.AK_ModdedPhysAssets = {} end
                                local PhysAssetName = "DefaultPhys"
                                pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                                
                                -- Tối ưu cấp 2: Nếu bộ xương này đã từng được phóng to bởi một kẻ địch khác, dùng luôn, không chạy vòng lặp
                                if _G.AK_ModdedPhysAssets[PhysAssetName] ~= _G.LexusState.LastMagicConfigHash then
                                    
                                    if not _G.AK_OrigHitboxes then _G.AK_OrigHitboxes = {} end
                                    if not _G.AK_OrigHitboxes[PhysAssetName] then _G.AK_OrigHitboxes[PhysAssetName] = {} end
                                    local OrigHitboxData = _G.AK_OrigHitboxes[PhysAssetName]

                                    local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                                    local numSetups = type(SkeletalBodySetups.Num) == "function" and SkeletalBodySetups:Num() or #SkeletalBodySetups
                                    local limit = numSetups > 50 and 50 or numSetups

                                    for i = 1, limit do 
                                        local BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i-1) or SkeletalBodySetups[i]
                                        if slua.isValid(BodySetup) then
                                            local LowerBoneName = string.lower(tostring(BodySetup.BoneName))
                                            local MatchedBoneKey = nil
                                            for k, _ in pairs(BoneScaleMap) do
                                                if string.find(LowerBoneName, k, 1, true) then MatchedBoneKey = k break end
                                            end

                                            if MatchedBoneKey then
                                                local TargetScale = 1.0 
                                                if runInject_Global then TargetScale = BoneScaleMap[MatchedBoneKey] end
                                                
                                                local AggGeom = BodySetup.AggGeom
                                                
                                                local BoxElems = AggGeom and AggGeom.BoxElems or BodySetup.BoxElems
                                                local SphereElems = AggGeom and AggGeom.SphereElems or BodySetup.SphereElems
                                                local SphylElems = AggGeom and AggGeom.SphylElems or BodySetup.SphylElems

                                                local BoxElem = GetFirstElemSafe(BoxElems)
                                                local SphereElem = GetFirstElemSafe(SphereElems)
                                                local SphylElem = GetFirstElemSafe(SphylElems)

                                                if not OrigHitboxData[MatchedBoneKey] then
                                                    OrigHitboxData[MatchedBoneKey] = { Box = nil, Sphere = nil, Sphyl = nil }
                                                    if BoxElem then OrigHitboxData[MatchedBoneKey].Box = { X = BoxElem.X, Y = BoxElem.Y, Z = BoxElem.Z } end
                                                    if SphereElem then OrigHitboxData[MatchedBoneKey].Sphere = { Radius = SphereElem.Radius } end
                                                    if SphylElem then OrigHitboxData[MatchedBoneKey].Sphyl = { Radius = SphylElem.Radius, Length = SphylElem.Length } end
                                                end

                                                local OrigElemData = OrigHitboxData[MatchedBoneKey]

                                                if OrigElemData.Box and BoxElem then
                                                    BoxElem.X = OrigElemData.Box.X * TargetScale
                                                    BoxElem.Y = OrigElemData.Box.Y * TargetScale
                                                    BoxElem.Z = OrigElemData.Box.Z * TargetScale
                                                    if type(BoxElems.Set) == "function" then BoxElems:Set(0, BoxElem) else BoxElems[1] = BoxElem end
                                                    if AggGeom then AggGeom.BoxElems = BoxElems; BodySetup.AggGeom = AggGeom else BodySetup.BoxElems = BoxElems end
                                                end

                                                if OrigElemData.Sphere and SphereElem then
                                                    SphereElem.Radius = OrigElemData.Sphere.Radius * TargetScale
                                                    if type(SphereElems.Set) == "function" then SphereElems:Set(0, SphereElem) else SphereElems[1] = SphereElem end
                                                    if AggGeom then AggGeom.SphereElems = SphereElems; BodySetup.AggGeom = AggGeom else BodySetup.SphereElems = SphereElems end
                                                end

                                                if OrigElemData.Sphyl and SphylElem then
                                                    SphylElem.Radius = OrigElemData.Sphyl.Radius * TargetScale
                                                    SphylElem.Length = OrigElemData.Sphyl.Length * TargetScale
                                                    if type(SphylElems.Set) == "function" then SphylElems:Set(0, SphylElem) else SphylElems[1] = SphylElem end
                                                    if AggGeom then AggGeom.SphylElems = SphylElems; BodySetup.AggGeom = AggGeom else BodySetup.SphylElems = SphylElems end
                                                end
                                            end
                                        end
                                    end
                                    _G.AK_ModdedPhysAssets[PhysAssetName] = _G.LexusState.LastMagicConfigHash
                                end
                                
                                if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
                                EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                                
                                markData.MagicBulletHash = _G.LexusState.LastMagicConfigHash
                                markData.MagicTargetID = uniqueID -- Lưu ID tĩnh
                            end
                        end
                    end)

                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local currentHp, maxHp = 0, 120
                    local showFrameUI = _G.LexusConfig.EspLoai5 or _G.LexusConfig.EspVipPro or _G.LexusConfig.EspVip

                    if showFrameUI then
                        pcall(function()
                            -- Health source aligned with file 2's ESP:
                            -- Character.Health / Character.MaxHealth.
                            currentHp = tonumber(enemy.Health) or 0
                            maxHp = tonumber(enemy.MaxHealth) or 120
                        end)
                        if maxHp <= 0 then maxHp = 120 end
                    end

                    local hpRatio = 0
                    if currentHp > 0 and maxHp > 0 then
                        hpRatio = currentHp / maxHp
                        if hpRatio > 1 then hpRatio = 1 end
                        if hpRatio < 0 then hpRatio = 0 end
                    end

                    if _G.LexusConfig.EspAntenna then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) and distM <= 400 then
                                local loopCount = 8  
                                local zStep = 1000     
                                local baseZ = 105     
                                local topZ = baseZ + (loopCount * zStep)
                                for i = 1, loopCount do
                                    local zOffset = baseZ + (i * zStep)
                                    MyHUD:AddDebugText("|", enemy, 0.06,
                                        {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset},
                                        C_GREEN, true, false, true, nil, 1.2, true)
                                end
                                MyHUD:AddDebugText("I", enemy, 0.06,
                                        {X=0, Y=0, Z=topZ + 60}, {X=0, Y=0, Z=topZ + 60},
                                        C_GREEN, true, false, true, nil, 1.5, true)
                            end
                        end)
                    end

                    if _G.LexusConfig.EspLoai6 then
                        pcall(function()
                            local curTime = os.clock()
                            -- TỐI ƯU CỰC ĐỘ 1: Khoá nhịp vẽ HUD 20 FPS (0.05s/lần) thay vì 100 FPS
                            -- Game vẫn mượt, nhưng CPU không bị cháy vì spam lệnh AddDebugText
                            if markData.LastEsp6Time == nil or (curTime - markData.LastEsp6Time) >= 0.05 then
                                markData.LastEsp6Time = curTime
                                
                                local MyHUD = Cached_MyHUD
                                if Valid(MyHUD) and Valid(eMesh) and aLoc then
                                    if distM <= 250 then
                                        -- Lấy toạ độ Đầu tiên quyết, nếu không có hàm này thì bỏ qua
                                        if type(eMesh.GetSocketLocation) == "function" then
                                            for _, bName in ipairs(GLOBAL_BONE_LIST) do
                                                
                                                -- TỐI ƯU CỰC ĐỘ 2: Địch xa hơn 50m chỉ vẽ Đầu, Cổ, Hông. Bỏ qua tay chân đỡ rác
                                                if distM > 50 and (bName ~= "head" and bName ~= "pelvis" and bName ~= "neck_01") then
                                                    -- Skip không vẽ tay chân ở xa
                                                else
                                                    local wLoc = eMesh:GetSocketLocation(bName)
                                                    if wLoc then
                                                        -- Tính Offset chuẩn cho HUD
                                                        local offset = {X = wLoc.X - aLoc.X, Y = wLoc.Y - aLoc.Y, Z = wLoc.Z - aLoc.Z}
                                                        
                                                        local mark = "▪"
                                                        local fixedSize = 0.25 
                                                        local color = C_CYAN
                                                        
                                                        if bName == "head" then 
                                                            mark = "●"
                                                            fixedSize = 0.45
                                                            color = C_RED
                                                        elseif bName == "pelvis" or bName == "neck_01" then 
                                                            mark = "▪"
                                                            fixedSize = 0.35
                                                            color = C_YELLOW 
                                                        end
                                                        
                                                        -- Vẽ điểm neo của khớp xương (Thời gian sống 0.06s để nối mượt với frame 0.05s)
                                                        MyHUD:AddDebugText(mark, enemy, 0.06, offset, offset, color, true, false, true, nil, fixedSize, true)
                                                    end
                                                end
                                            end
                                        end
                                        -- LƯU Ý: ĐÃ XOÁ BỎ HOÀN TOÀN TÍNH NĂNG VẼ DÂY NỐI (GLOBAL_CONNECTIONS)
                                        -- Vì dùng dấu chấm "." xếp thành dây là nguyên nhân chính gây drop FPS 
                                    end
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspLoai7 then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) then
                                if distM <= 600 then if isBot then aiCount = aiCount + 1 else realCount = realCount + 1 end end
                                
                                if distM <= 400 then
                                    local stateText = ""
                                    
                                    -- 1. Xử lý Tư Thế
                                    if _G.LexusConfig.Esp7_TuThe then
                                        local pose = nil
                                        if enemy.PoseState then pose = enemy.PoseState
                                        elseif type(enemy.GetPoseState) == "function" then pose = enemy:GetPoseState() end
                                        
                                        if pose == 0 or pose == "Stand" then stateText = "Đứng"
                                        elseif pose == 1 or pose == "Crouch" then stateText = "Ngồi"
                                        elseif pose == 2 or pose == "Prone" then stateText = "Nằm"
                                        else stateText = "Đứng" end
                                    end
                                    
                                    -- 2. Xử lý Vũ Khí
                                    if _G.LexusConfig.Esp7_VuKhi then
                                        local curTime = os.clock()
                                        if markData.AK_LAST_WEP_TIME == nil or curTime > markData.AK_LAST_WEP_TIME + 1.5 then
                                            local eWeapon = nil
                                            if enemy.CurrentWeapon then eWeapon = enemy.CurrentWeapon
                                            elseif type(enemy.GetCurrentWeapon) == "function" then eWeapon = enemy:GetCurrentWeapon()
                                            elseif enemy.WeaponManagerComponent then eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated end
                                            
                                            local weaponName = "Tay Không"
                                            if Valid(eWeapon) then if type(eWeapon.GetWeaponName) == "function" then weaponName = eWeapon:GetWeaponName() end end
                                            markData.AK_CACHED_WEP_NAME = tostring(weaponName)
                                            markData.AK_LAST_WEP_TIME = curTime
                                        end

                                        if stateText ~= "" then
                                            stateText = stateText .. " - " .. (markData.AK_CACHED_WEP_NAME or "Tay Không")
                                        else
                                            stateText = (markData.AK_CACHED_WEP_NAME or "Tay Không")
                                        end
                                    end

                                    -- 3. Vẽ lên màn hình nếu có bật 1 trong 2
                                    if stateText ~= "" then
                                        local textColor = isBot and C_CYAN or C_YELLOW
                                        local dynamicScale = math.max(0.5, 0.8 - (distM / 400))
                                        MyHUD:AddDebugText(stateText, enemy, 0.06, {X=0, Y=0, Z=100}, {X=0, Y=0, Z=100}, textColor, true, false, true, nil, dynamicScale, true)
                                    end
                                end
                            end
                        end)
                    end

                    -- ĐÃ TỐI ƯU CỰC KỲ: Chỉ SetVisibility cho UI khung máu khi thật sự cần
                    if showFrameUI then
                        pcall(function()
                            local SecurityCommonUtils = Cached_SecurityCommonUtils
                            local show = true
                            if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                            end
                            if show and mLoc then
                                if aLoc and SecurityCommonUtils and SecurityCommonUtils.IsVector then
                                    if SecurityCommonUtils.IsVector(aLoc) and SecurityCommonUtils.IsVector(mLoc) then
                                        if aLoc.Z >= 150000 or FVector.Dist2D(mLoc, aLoc) > 50000 then show = false end
                                    end
                                end
                            end
                            if show then
                                if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if markData.LastFrameUIState ~= "VISIBLE" then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                        markData.LastFrameUIState = "VISIBLE"
                                    end
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if markData.LastFrameUIState ~= "HIDDEN" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    markData.LastFrameUIState = "HIDDEN"
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspVipPro then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if Valid(hud) and hud.AddDebugText then
                                if distM <= 400 then
                                    local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                                    local hpPercent = hpRatio
                                    local isKnock = (currentHp <= 0 and enemy.HealthStatus == 1)
                                    
                                    local hpColor = C_GREEN
                                    if hpPercent < 0.3 then hpColor = C_RED
                                    elseif hpPercent < 0.7 then hpColor = C_YELLOW end
                                    if isKnock then hpColor = C_RED end
                                    
                                    -- VẼ TÊN NGƯỜI CHƠI
                                    if _G.LexusConfig.Esp3ShowName then
                                        local enemyName = "Enemy"
                                        pcall(function() if enemy.PlayerName then enemyName = enemy.PlayerName elseif type(enemy.GetPlayerName) == "function" then enemyName = enemy:GetPlayerName() end end)
                                        if enemyName == "" then enemyName = "Enemy" end
                                        if isKnock then enemyName = "KNOCK: " .. enemyName end
                                        hud:AddDebugText(enemyName, enemy, 0.06, {X=0, Y=0, Z=-370}, {X=0, Y=0, Z=-370}, C_WHITE, true, false, true, nil, dynamicScale * 1.1, true)
                                    end
                                    
                                    -- VẼ THANH MÁU
                                    if _G.LexusConfig.Esp3ShowHP then
                                        if not isKnock then
                                            local segments = 6
                                            local filled = math.floor(hpPercent * segments)
                                            local startZ = 20
                                            local spacing = 10.0 * dynamicScale 
                                            for j = 1, segments do
                                                local color = (j <= filled) and hpColor or {R=30,G=30,B=30,A=180}
                                                hud:AddDebugText("█", enemy, 0.06, {X=0, Y=-115, Z=startZ + (j * spacing)}, {X=0, Y=-115, Z=startZ + (j * spacing)}, color, true, false, true, nil, dynamicScale * 1.2, true)
                                            end
                                            hud:AddDebugText(string.format("%d%%", math.floor(hpPercent * 100)), enemy, 0.06, {X=0, Y=-60, Z=startZ - 12}, {X=0, Y=-60, Z=startZ - 12}, hpColor, true, false, true, nil, dynamicScale * 0.8, true)
                                        else
                                            hud:AddDebugText("DOWN", enemy, 0.06, {X=0, Y=-115, Z=50}, {X=0, Y=-115, Z=50}, C_RED, true, false, true, nil, dynamicScale * 1.0, true)
                                        end
                                    end
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspDistance then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if Valid(hud) and hud.AddDebugText then
                                if distM <= 400 then
                                    local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                                    hud:AddDebugText(string.format("[%dm]", math.floor(distM)), enemy, 0.06, {X=0, Y=115, Z=20}, {X=0, Y=115, Z=20}, C_BLUE_TEXT, true, false, true, nil, dynamicScale * 1.5, true)
                                end
                            end
                        end)
                    end

                    -- [ESP LOẠI 1 (Đã Fix Lỗi)]: Giữ nguyên thanh máu (hpMark) và khoảng cách (distMark)
                    if _G.LexusConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                    end

                    -- [ESP LOẠI 8 ĐỘC LẬP (Đã Fix Lỗi)]: Copy logic thanh máu ESP 1, nhưng chạy biến hpMark8 riêng biệt
                    if _G.LexusConfig.EspLoai8 then
                        if markData.hpMark8 == nil then markData.hpMark8 = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                    end
                    
                    if _G.LexusConfig.EspRadar then
                        -- Sửa lỗi kẹt biến (nil/false/0) và gọi ID 8888 độc quyền
                        if not markData.radarMark or markData.radarMark == 0 then 
                            markData.radarMark = SafeAddMark(8888, FVector(0,0,0), 0, "", 4, enemy) 
                        end
                    else
                        if markData.radarMark and markData.radarMark ~= 0 then
                            SafeRemoveMark(markData.radarMark)
                            markData.radarMark = nil
                        end
                    end
                    
                    -- [FIX NÓNG MÁY/DROP FPS]: Ghi nhớ trạng thái, chỉ truyền lệnh Outline vào GPU khi có sự thay đổi
                    if _G.LexusConfig.EspOutline then
                        pcall(function()
                            local outlineHash = tostring(_G.LexusConfig.OutlineThickness)
                            if markData.OutlineState ~= outlineHash then
                                local PPM = Cached_PPM
                                local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                                if Valid(avatarComp) and Valid(PPM) then
                                    PPM.OutlineThickness = _G.LexusConfig.OutlineThickness
                                    if PPM.OutlineColor then PPM.OutlineColor = {r = 1, g = 0, b = 0, a = 1} end
                                    PPM:EnableAvatarOutline(avatarComp, true)
                                    markData.OutlineState = outlineHash
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if markData.OutlineState ~= "OFF" then
                                local PPM = Cached_PPM
                                local avatarComp = (type(enemy.getAvatarComponent2) == "function") and enemy:getAvatarComponent2() or nil
                                if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                                markData.OutlineState = "OFF"
                            end
                        end)
                    end

                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark)
                        markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark)
                        markData.hpMark = nil
                        SafeRemoveMark(markData.hpMark8) -- Dọn dẹp ESP 8
                        markData.hpMark8 = nil
                        SafeRemoveMark(markData.distMark)
                        markData.distMark = nil
                        
                        if markData.MIDs then
                            for meshStr, midTable in pairs(markData.MIDs) do
                                for k, _ in pairs(midTable) do midTable[k] = nil end
                            end
                            markData.MIDs = nil
                        end
                        
                        pcall(function()
                            local eObj = markData.enemy
                            if Valid(eObj) then 
                                if eObj.Replay_SetVisiableOfFrameUI then eObj:Replay_SetVisiableOfFrameUI(false) end
                                local uiComp = eObj.EnemyFrameUI or (type(eObj.GetEnemyFrameUI) == "function" and eObj:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end 
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                end
                            end
                            
                            local PPM = Cached_PPM
                            local avatarComp = Valid(eObj) and (type(eObj.getAvatarComponent2) == "function") and eObj:getAvatarComponent2() or nil
                            if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                        end)

                        markData.IsCleanedUp = true
                    end
                end
            end
        end

        if _G.LexusConfig.EspLoai7 and _G.LexusConfig.Esp7_SoLuong then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    local totalEnemies = realCount + aiCount
                    local text = string.format("Kẻ Địch Xung Quanh: %d", totalEnemies)
                    MyHUD:AddDebugText(text, localPlayer, 0.06, {X=0, Y=0, Z=0}, {X=0, Y=0, Z=0}, C_RED, true, false, true, nil, 0.8, true)
                end
            end)
        end

        -- ==========================================================
        -- [LOGIC ESP BOM VVIP] - OPTIMIZED (KHÔNG DROP FPS)
        -- ==========================================================
        if _G.LexusConfig.EspBomMaster and (_G.LexusConfig.EspItemBom or _G.LexusConfig.EspActiveBom) then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                    if not _G.CachedActorClass_ForBomb then _G.CachedActorClass_ForBomb = import("Actor") end 
                    if not _G.CachedProjArray then _G.CachedProjArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForBomb) end
                    
                    local ui_util = require("client.common.ui_util")
                    local gameInstance = ui_util and ui_util.GetGameInstance()
                    
                    if gameInstance and _G.CachedGameplayStatics then
                        local curTime = os.clock()
                        
                        -- LUỒNG QUÉT DỮ LIỆU NẶNG: Chạy 0.5s/lần thay vì mỗi frame
                        if not _G.LastBombScanTime or (curTime - _G.LastBombScanTime) > 0.5 then
                            _G.LastBombScanTime = curTime
                            local allActors = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForBomb, _G.CachedProjArray)
                            
                            local activeBombs = {}
                            local itemBombs = {}
                            
                            if allActors then
                                for _, actor in pairs(allActors) do
                                    if slua.isValid(actor) and not actor.bHidden and not actor.bTearOff then
                                        local isPendingKill = false
                                        pcall(function() if type(actor.IsPendingKill) == "function" then isPendingKill = actor:IsPendingKill() end end)
                                        
                                        if not isPendingKill then
                                            local nameLower = string.lower(tostring(actor))
                                            local bType = 0
                                            if string.find(nameLower, "m79") or string.find(nameLower, "launcher") then bType = 5
                                            elseif string.find(nameLower, "smoke") then bType = 2
                                            elseif string.find(nameLower, "burn") or string.find(nameLower, "molotov") then bType = 3
                                            elseif string.find(nameLower, "flash") or string.find(nameLower, "stun") then bType = 4
                                            elseif string.find(nameLower, "grenade") then bType = 1 end
                                            
                                            if bType > 0 then
                                                if string.find(nameLower, "projectile") or string.find(nameLower, "thrown") then
                                                    table.insert(activeBombs, {act = actor, type = bType})
                                                else
                                                    local shouldAdd = true
                                                    
                                                    if bType == 3 and not (string.find(nameLower, "pickup") or string.find(nameLower, "wrapper") or string.find(nameLower, "weapon")) then
                                                        shouldAdd = false
                                                    elseif bType == 5 then
                                                        local attachParent = nil
                                                        pcall(function() if type(actor.GetAttachParentActor) == "function" then attachParent = actor:GetAttachParentActor() end end)
                                                        if slua.isValid(attachParent) then
                                                            local isHolding = false
                                                            pcall(function()
                                                                local curWeapon = type(attachParent.GetCurrentWeapon) == "function" and attachParent:GetCurrentWeapon() or attachParent.CurrentWeapon
                                                                if curWeapon == actor then isHolding = true end
                                                            end)
                                                            if not isHolding then shouldAdd = false end
                                                        end
                                                    end
                                                    
                                                    if shouldAdd then table.insert(itemBombs, {act = actor, type = bType}) end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            _G.CachedActiveBombs = activeBombs
                            _G.CachedItemBombs = itemBombs
                        end

                        local curGameTime = 0
                        pcall(function() curGameTime = _G.CachedGameplayStatics.GetTimeSeconds(gameInstance) end)

                        local function DrawBombs(bombList, isItem, maxDist)
                            if not bombList then return end
                            for _, item in ipairs(bombList) do
                                local bomb = item.act
                                local bType = item.type
                                
                                if slua.isValid(bomb) and not bomb.bHidden then
                                    local distM = 0
                                    pcall(function() distM = localPlayer:GetDistanceTo(bomb) / 100 end)
                                    
                                    if distM > 0 and distM <= maxDist then
                                        local displayName = ""
                                        local bombColor = C_WHITE
                                        local zOffset = isItem and 15 or 25
                                        
                                        if bType == 1 then displayName = "Boom"; bombColor = isItem and {R=255, G=100, B=100, A=255} or C_RED
                                        elseif bType == 2 then displayName = "KHÓI"; bombColor = isItem and {R=200, G=200, B=200, A=255} or C_WHITE
                                        elseif bType == 3 then displayName = "LỬA"; bombColor = isItem and {R=255, G=160, B=50, A=255} or {R=255, G=100, B=0, A=255}
                                        elseif bType == 4 then displayName = "MÙ"; bombColor = isItem and {R=150, G=255, B=255, A=255} or C_CYAN
                                        elseif bType == 5 then displayName = "ĐẠN KHÓI"; bombColor = isItem and {R=150, G=255, B=150, A=255} or {R=100, G=255, B=100, A=255} end
                                        
                                        local text = string.format("%s [%dm]", displayName, math.floor(distM))
                                        local shouldTimerRun = not isItem 
                                        
                                        if isItem then pcall(function() if bomb.bIsPinPulled or bomb.bPinPulled or (type(bomb.IsPinPulled) == "function" and bomb:IsPinPulled()) then shouldTimerRun = true end end) end

                                        if shouldTimerRun and curGameTime > 0 then
                                            local timeLeft = -1
                                            pcall(function() if bomb.ExplosionTime then timeLeft = bomb.ExplosionTime - curGameTime elseif bomb.ExplodeTime then timeLeft = bomb.ExplodeTime - curGameTime end end)
                                            
                                            if timeLeft == -1 or timeLeft > 100 then
                                                _G.ActiveBombTimers = _G.ActiveBombTimers or {}
                                                local bombId = tostring(bomb)
                                                if not _G.ActiveBombTimers[bombId] then _G.ActiveBombTimers[bombId] = curGameTime end
                                                local elapsed = curGameTime - _G.ActiveBombTimers[bombId]
                                                local maxTime = (bType == 1 and 7.0) or (bType == 2 and 45.0) or (bType == 3 and 12.0) or (bType == 4 and 5.0) or 45.0
                                                timeLeft = maxTime - elapsed
                                            end
                                            
                                            if timeLeft < 0 then timeLeft = 0 end
                                            if timeLeft > 0.1 then text = string.format("%s (%.1fs)", text, timeLeft) end
                                        end
                                        
                                        local dynamicScale = math.max(0.6, 1.1 - (distM / maxDist))
                                        MyHUD:AddDebugText(text, bomb, 0.06, {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset}, bombColor, true, false, true, nil, dynamicScale, true)
                                    end
                                end
                            end
                        end
                        
                        if not _G.LastClearTimer or (curTime - _G.LastClearTimer) > 1.0 then
                            _G.LastClearTimer = curTime
                            pcall(function() if _G.ActiveBombTimers then for k, v in pairs(_G.ActiveBombTimers) do if (curGameTime - v) > 60.0 then _G.ActiveBombTimers[k] = nil end end end end)
                        end

                        if _G.LexusConfig.EspItemBom then DrawBombs(_G.CachedItemBombs, true, 50) end
                        if _G.LexusConfig.EspActiveBom then DrawBombs(_G.CachedActiveBombs, false, 150) end
                    end
                end
            end)
        end

        -- ==========================================================
        -- [LOGIC ESP XE - VEHICLE ESP VVIP] - OPTIMIZED
        -- ==========================================================
        if _G.LexusConfig.EspVehicle then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                    if not _G.CachedActorClass_ForVehicle then _G.CachedActorClass_ForVehicle = import("STExtraVehicleBase") end 
                    if not _G.CachedVehicleArray then _G.CachedVehicleArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForVehicle) end
                    
                    local ui_util = require("client.common.ui_util")
                    local gameInstance = ui_util and ui_util.GetGameInstance()
                    
                    if gameInstance and _G.CachedGameplayStatics then
                        local curTime = os.clock()

                        -- LUỒNG QUÉT CHÍNH: 1.0s quét 1 lần.
                        if not _G.LastVehicleScanTime or (curTime - _G.LastVehicleScanTime) > 1.0 then
                            _G.LastVehicleScanTime = curTime
                            local allVehicles = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForVehicle, _G.CachedVehicleArray)
                            
                            local activeVehicles = {}
                            if allVehicles then
                                for _, veh in pairs(allVehicles) do
                                    if slua.isValid(veh) and not veh.bHidden and not veh.bTearOff then
                                        local isPendingKill = false
                                        pcall(function() if type(veh.IsPendingKill) == "function" then isPendingKill = veh:IsPendingKill() end end)
                                        
                                        if not isPendingKill then
                                            local vehName = "Xe"
                                            local hasDriver = false
                                            local hpStr = ""
                                            
                                            pcall(function()
                                                if type(veh.GetVehicleName) == "function" then vehName = veh:GetVehicleName() elseif veh.VehicleName then vehName = veh.VehicleName end
                                                local driver = type(veh.GetDriver) == "function" and veh:GetDriver() or nil
                                                if slua.isValid(driver) then hasDriver = true end
                                                local hp = veh.HP or (type(veh.GetHP) == "function" and veh:GetHP()) or 100
                                                local maxHp = veh.HPMax or (type(veh.GetHPMax) == "function" and veh:GetHPMax()) or 100
                                                if maxHp > 0 then hpStr = string.format(" [%d%%]", math.floor((hp/maxHp)*100)) end
                                            end)
                                            
                                            local nameLower = string.lower(tostring(vehName) .. tostring(veh))
                                            local displayName = "Xe"
                                            if string.find(nameLower, "uaz") then displayName = "UAZ"
                                            elseif string.find(nameLower, "dacia") then displayName = "Dacia"
                                            elseif string.find(nameLower, "buggy") then displayName = "Buggy"
                                            elseif string.find(nameLower, "mirado") then displayName = "Mirado"
                                            elseif string.find(nameLower, "bike") or string.find(nameLower, "motor") then displayName = "Motor"
                                            elseif string.find(nameLower, "scooter") then displayName = "Scooter"
                                            elseif string.find(nameLower, "coupe") then displayName = "Coupe RB"
                                            elseif string.find(nameLower, "brdm") then displayName = "BRDM"
                                            elseif string.find(nameLower, "boat") or string.find(nameLower, "aquarail") then displayName = "Thuyền"
                                            elseif string.find(nameLower, "glider") then displayName = "Tàu lượn"
                                            else displayName = "Xe (" .. string.sub(vehName, 1, 8) .. ")" end

                                            table.insert(activeVehicles, {act = veh, name = displayName, hasDriver = hasDriver, hpStr = hpStr})
                                        end
                                    end
                                end
                            end
                            _G.CachedVehicles = activeVehicles
                        end

                        if _G.CachedVehicles then
                            for _, item in ipairs(_G.CachedVehicles) do
                                local veh = item.act
                                if slua.isValid(veh) and not veh.bHidden then
                                    local isShow = false
                                    if item.name == "Dacia" then isShow = _G.LexusConfig.EspVeh_Dacia
                                    elseif item.name == "UAZ" then isShow = _G.LexusConfig.EspVeh_UAZ
                                    elseif item.name == "Buggy" then isShow = _G.LexusConfig.EspVeh_Buggy
                                    elseif item.name == "Coupe RB" then isShow = _G.LexusConfig.EspVeh_Coupe
                                    elseif item.name == "Mirado" then isShow = _G.LexusConfig.EspVeh_Mirado
                                    elseif item.name == "Motor" or item.name == "Scooter" then isShow = _G.LexusConfig.EspVeh_Motor
                                    else isShow = _G.LexusConfig.EspVeh_Other end

                                    if isShow then
                                        local distM = 0
                                        pcall(function() distM = localPlayer:GetDistanceTo(veh) / 100 end)
                                        
                                        if distM > 0 and distM <= 300 then
                                            local text = string.format("%s%s [%dm]", item.name, item.hpStr, math.floor(distM))
                                            local vehColor = item.hasDriver and {R=255, G=50, B=50, A=255} or {R=0, G=255, B=150, A=255}
                                            local dynamicScale = math.max(0.6, 1.1 - (distM / 500))
                                            
                                            MyHUD:AddDebugText(text, veh, 0.06, {X=0, Y=0, Z=50}, {X=0, Y=0, Z=50}, vehColor, true, false, true, nil, dynamicScale, true)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end

    end)
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1 
local myToken = _G.LexusState.LoopToken

local function ExpiredTick()
    if not _G.LexusNotifiedPopup then
        pcall(function()
            local Msg = require("client.slua.logic.common.logic_common_msg_box")
            if Msg and Msg.Show then
                Msg.Show(1, "ABU RAHAF", "@abu_rhofen", 
                function() 
                    local Web = require("client.slua.logic.url.logic_webview_sdk")
                    if Web and Web.OpenURL then Web:OpenURL("https://t.me/abu_rhofen") end 
                end, 
                function() end, "INBOX CHỦ MOD", "ĐÓNG")
                _G.LexusNotifiedPopup = true 
            end
        end)
        
        if not _G.LexusNotifiedPopup then
            local okTicker, ticker = pcall(require, "common.time_ticker") 
            if okTicker and ticker and ticker.AddTimerOnce then 
                ticker.AddTimerOnce(2.0, ExpiredTick) 
            end
        end
    end
end

local function FastTick() 
    if isExpired then 
        if not _G.LexusNotifiedExpire then
            Notify("ABU RAHAF VIP")
            _G.LexusNotifiedExpire = true
            ExpiredTick() 
        end
        return 
    end

    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(MainLoop) 

    if _G.LunarLoginRuntime and _G.LunarLoginRuntime.NeedsUpdate then
        pcall(_G.LunarLoginRuntime.Update)
    end
    local okTicker, ticker = pcall(require, "common.time_ticker") 
    if okTicker and ticker and ticker.AddTimerOnce then 
        ticker.AddTimerOnce(0.05, FastTick) 
    end 
end

if not isExpired then
    FastTick() 
    Notify("ABU RAHAF VIP")
else
    FastTick() 
end

-- ===================================================================================
-- SYSTEM HOOKS TỪ BYPASS MỚI
-- ===================================================================================
local function InitAllModSystems()
    if isExpired then return end 

    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
        if _G.InitializeAutoHeadHooks then _G.InitializeAutoHeadHooks() end
    end)

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return end

    pcall(function()
        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false 
                LocalPlayer.bHasShownExpiredNotice = false 
                LocalPlayer.bIsDeadFlag = false
            end
        end
    end)
end

if not isExpired then
    pcall(function() 
        require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) 
    end)
end
local function _WinnerGetOfficialTeams()
    local teams = nil
    pcall(function()
        local gd = require("GameLua.GameCore.Data.GameplayData")
        local gs = gd.GetGameState()
        if not gs then gs = CGameState end
        if gs then
            if gs.GetAliveTeamNum then teams = tonumber(gs:GetAliveTeamNum()) end
            if not teams then teams = tonumber(gs.AliveTeamNum) end
            if not teams then teams = tonumber(gs.AliveTeams) end
        end
    end)
    return teams
end

local function _WinnerShowMessage()
    if _G.WinnerMessageShown then return end

    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(
                1,
                "Winner Winner by ABU RAHAF",
                "مبروك! لقد حققت الفوز",
                function() end,
                nil,
                "موافق"
            )

            _G.WinnerMessageShown = true
        end
    end)
end

local function _WinnerTeamsUpdate(localPlayer)
    local teams = _WinnerGetOfficialTeams()
    if not teams then return end

    if teams > 1 then
        _G.WinnerMessageState = 0
        _G.WinnerMessageShown = false

        if _G.WinnerMessageTimer then
            pcall(function()
                if localPlayer and localPlayer.RemoveGameTimer then
                    localPlayer:RemoveGameTimer(_G.WinnerMessageTimer)
                end
            end)
            _G.WinnerMessageTimer = nil
        end

        return
    end

    if teams == 1 and (_G.WinnerMessageState or 0) == 0 then
        _G.WinnerMessageState = 1

        if localPlayer and localPlayer.AddGameTimer then
            _G.WinnerMessageTimer = localPlayer:AddGameTimer(3, false, function()
                if (_G.WinnerMessageState or 0) == 1 then
                    _WinnerShowMessage()
                    _G.WinnerMessageState = 2
                end
                _G.WinnerMessageTimer = nil
            end)
        else
            _G.WinnerMessageState = 2
            _WinnerShowMessage()
        end
    end
end
-- ==============================================================================
-- ============ ABU RAHAF VIP - Auto Screenshot System [FIXED - WIN ONLY] ======
-- ==============================================================================

-- ربط الإشعارات بالدالة الأصلية
_G.NTHMODNotify = _G.NTHMODNotify or function(msg)
    pcall(function() if _G.LexusNotify then _G.LexusNotify(msg) end end)
    pcall(function() print("[ABU RAHAF] " .. tostring(msg)) end)
end

local AutoFeedback = {
    Config = {
        ServerURL = "https://ahmediqh.x10.mx/uploads/rahaf.php",
        TestMode = false,
        MinRank = 1000,
        MinKills = 3
    },
    Hooked = false,
    -- قفل يمنع إرسال أكثر من صورة واحدة في المباراة الواحدة
    _SessionLock = false,
    _LastMatchId = nil
}

local function AF_Log(message)
    print(string.format("[ABU RAHAF FEEDBACK] [%s] %s", os.date and os.date("%H:%M:%S") or "??", tostring(message)))
end

local function AF_Notify(message)
    if _G.NTHMODNotify then pcall(_G.NTHMODNotify, message) end
end

local function AF_GetModule(name, allowRequire)
    local loaded = package and package.loaded and package.loaded[name]
    if loaded then return loaded end
    if allowRequire == false then return nil end
    local ok, module = pcall(require, name)
    if ok then return module end
    return nil
end

local function AF_AddTimerOnce(delay, callback)
    local ticker = AF_GetModule("common.time_ticker")
    if ticker and type(ticker.AddTimerOnce) == "function" then
        ticker.AddTimerOnce(delay, callback)
        return true
    end
    return false
end

local function AF_Base64Encode(data)
    if type(data) ~= "string" or #data == 0 then return "" end
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local output = {}
    local outputIndex = 0
    local index = 1
    while index <= #data - 2 do
        local a, b, c = string.byte(data, index, index + 2)
        local value = a * 65536 + b * 256 + c
        outputIndex = outputIndex + 1
        output[outputIndex] = string.char(
            string.byte(alphabet, math.floor(value / 262144) + 1),
            string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
            string.byte(alphabet, math.floor(value / 64) % 64 + 1),
            string.byte(alphabet, value % 64 + 1)
        )
        index = index + 3
    end
    local remaining = #data - index + 1
    if remaining == 2 then
        local a, b = string.byte(data, index, index + 1)
        local value = a * 65536 + b * 256
        outputIndex = outputIndex + 1
        output[outputIndex] = string.char(
            string.byte(alphabet, math.floor(value / 262144) + 1),
            string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
            string.byte(alphabet, math.floor(value / 64) % 64 + 1),
            string.byte("=")
        )
    elseif remaining == 1 then
        local value = string.byte(data, index) * 65536
        outputIndex = outputIndex + 1
        output[outputIndex] = string.char(
            string.byte(alphabet, math.floor(value / 262144) + 1),
            string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
            string.byte("="),
            string.byte("=")
        )
    end
    return table.concat(output)
end

local function AF_UrlEncode(value)
    if value == nil then return nil end
    value = tostring(value):gsub("\n", "\r\n")
    value = value:gsub("([^A-Za-z0-9 %-%_%.%~])", function(character)
        return string.format("%%%02X", string.byte(character))
    end)
    value = value:gsub(" ", "+")
    return value
end

local function AF_ReadFile(path)
    local file = io.open(path, "rb")
    if not file then return "" end
    local data = file:read("*a") or ""
    file:close()
    return data
end

local function AF_RemoveFile(path)
    pcall(os.remove, path)
end

local function AF_GetRankName(rank)
    if rank < 1700 then return "برونزي"
    elseif rank < 2200 then return "فضي"
    elseif rank < 2700 then return "ذهبي"
    elseif rank < 3200 then return "بلاتيني"
    elseif rank < 3700 then return "ماسي"
    elseif rank < 4200 then return "آيس"
    elseif rank < 4700 then return "المتفوق"
    elseif rank < 5200 then return "المتفوق البارع"
    elseif rank < 5600 then return "المتفوق المسيطر"
    end
    return "الكونكر"
end

local AF_CaptionTemplate = "• فوز محقق بواسطة ابو رهف\n• الوقت: %s\n• اسم اللاعب: %s\n• المعرف: %s\n• الكلات: %d\n• الرتبة: %s\n• الدولة: AT"

function AutoFeedback.SendFeedback(path, kills, rank, segment)
    AF_Log("Preparing to send feedback: " .. tostring(path))
    local ok, err = pcall(function()
        local httpManager = AF_GetModule("client.slua.logic.http.http_manager")
        if not httpManager or type(httpManager.Post) ~= "function" then
            AF_Log("HTTP manager unavailable - cannot send image")
            return
        end
        
        local attempts = 0
        local function TrySend()
            local imageData = AF_ReadFile(path)
            if #imageData > 0 then
                local uid = "unknown"
                if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then
                    uid = tostring(_G.DataMgr.roleData.uid)
                elseif _G._NTH_UK then
                    uid = tostring(_G._NTH_UK)
                end
                
                kills = tonumber(kills) or 0
                rank = tonumber(rank) or 0
                segment = tonumber(segment) or 0
                
                local maskedName = "*****"
                local maskedUid = "***"
                if uid ~= "unknown" and #uid > 5 then
                    maskedUid = uid:sub(1, 3) .. "***" .. uid:sub(-2)
                end
                
                local timeStr = "??:??:??"
                pcall(function()
                    if os.date then timeStr = os.date("%H:%M:%S %d/%m/%Y") end
                end)
                
                local caption = string.format(AF_CaptionTemplate,
                    timeStr,
                    maskedName, 
                    maskedUid, 
                    kills, 
                    AF_GetRankName(rank)
                )
                
                local encodedImage = AF_Base64Encode(imageData)
                encodedImage = encodedImage:gsub("%+", "%%2B")
                encodedImage = encodedImage:gsub("/", "%%2F")
                encodedImage = encodedImage:gsub("=", "%%3D")
                
                AF_Notify("[ABU RAHAF] جاري إرسال صورة الفوز...")
                
                local body = "base64_image=" .. encodedImage .. "&caption=" .. AF_UrlEncode(caption)
                
                httpManager:Post(
                    AutoFeedback.Config.ServerURL,
                    {["Content-Type"] = "application/x-www-form-urlencoded"},
                    body, nil,
                    function(success, _, response, errorMessage)
                        if success and response and tostring(response):find('"status":%s*true') then
                            AF_Notify("[ABU RAHAF] ✅ تم إرسال الصورة بنجاح! (Kills: " .. tostring(kills) .. ")")
                        else
                            AF_Notify("[ABU RAHAF] ❌ فشل: " .. tostring(response or errorMessage):sub(1, 40))
                        end
                        AF_RemoveFile(path)
                    end, 60)
                return
            end
            attempts = attempts + 1
            if attempts < 5 and AF_AddTimerOnce(1.0, TrySend) then return end
            AF_Notify("[ABU RAHAF] ❌ فشل قراءة الصورة!")
            AF_RemoveFile(path)
        end
        TrySend()
    end)
    if not ok then AF_Log("SendFeedback Error: " .. tostring(err)) end
end

local AF_HudNames = {
    "BattleChat_UIBP","Chat_UIBP","ChatMsg_UIBP","TeamAvatar_UIBP","Team_UIBP",
    "VoiceChat_UIBP","MiniMap_UIBP","Bag_UIBP","PickUp_UIBP","PickUpList_UIBP",
    "SystemChat_UIBP","InGameChat_UIBP","InGameChatPanel_UIBP","KillFeed_UIBP",
    "Elimination_UIBP","ChatHUD_UIBP","ChatPanel_UIBP","MainHUD_UIBP","BattleHUD_UIBP"
}

local function AF_GetRankAndSegment()
    local rank = 0
    local segment = 0
    pcall(function()
        local battleResult = _G.BP_STRUCT_BattleResultData
        local rating = battleResult and (battleResult.rating or battleResult.BP_STRUCT_BTRating)
        if rating then
            rank = tonumber(rating.rank_rating) or 0
            segment = tonumber(rating.new_segment) or 0
        end
        if rank == 0 then
            local funcUtil = AF_GetModule("common.func_util")
            local roleData = _G.DataMgr and _G.DataMgr.roleData
            if funcUtil and type(funcUtil.GetCurMaxSegementLevel) == "function" and roleData and roleData.allzoneSegment then
                segment = tonumber(funcUtil.GetCurMaxSegementLevel(roleData.allzoneSegment)) or 0
            end
            if roleData and roleData.segment_rating then
                for _, value in pairs(roleData.segment_rating) do
                    if type(value) == "table" then
                        for _, nv in pairs(value) do
                            if type(nv) == "number" and nv > rank then rank = nv end
                        end
                    elseif type(value) == "number" and value > rank then rank = value end
                end
            end
        end
    end)
    return rank, segment
end

local function AF_CreateHudController()
    local hidden = {}
    local function SetHidden(hide)
        local UIManager = _G.UIManager
        if not UIManager then return end
        if hide then
            hidden = {}  -- تنظيف قبل الإضافة (إصلاح تسريب الذاكرة)
            for _, name in ipairs(AF_HudNames) do
                local config
                if UIManager.UI_Config_InGame and UIManager.UI_Config_InGame[name] then
                    config = UIManager.UI_Config_InGame[name]
                elseif UIManager.UI_Config and UIManager.UI_Config[name] then
                    config = UIManager.UI_Config[name]
                end
                if config then
                    local view = type(UIManager.GetUI) == "function" and UIManager.GetUI(config) or nil
                    if view then
                        pcall(function()
                            if type(view.SetVisibility) == "function" then view:SetVisibility(2)
                            elseif view.UIRoot and type(view.UIRoot.SetVisibility) == "function" then view.UIRoot:SetVisibility(2)
                            elseif type(UIManager.HideUI) == "function" then UIManager.HideUI(config) end
                        end)
                        table.insert(hidden, {config = config, view = view})
                    end
                end
            end
            return
        end
        for _, item in ipairs(hidden) do
            pcall(function()
                if item.view and type(item.view.SetVisibility) == "function" then item.view:SetVisibility(0)
                elseif item.view and item.view.UIRoot and type(item.view.UIRoot.SetVisibility) == "function" then item.view.UIRoot:SetVisibility(0)
                elseif type(UIManager.ShowUI) == "function" then UIManager.ShowUI(item.config) end
            end)
        end
        hidden = {}
    end
    return SetHidden
end

local function AF_GetScreenshotDirectory()
    local directories = {}
    local home = os.getenv("HOME")
    if home and home ~= "" then table.insert(directories, home .. "/Documents/ShadowTrackerExtra/Saved/") end
    local packages = {"com.tencent.ig","com.vng.pubgmobile","com.pubg.krmobile","com.rekoo.pubgm","com.pubg.imobile"}
    for _, pkg in ipairs(packages) do
        table.insert(directories, "/storage/emulated/0/Android/data/" .. pkg .. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/")
    end
    local selected = directories[1]
    for _, dir in ipairs(directories) do
        local tp = dir .. "t.tmp"
        local f = io.open(tp, "w")
        if f then f:close() os.remove(tp) selected = dir break end
    end
    return selected
end

local function AF_CaptureAndSend(kills, rank, segment, restoreHud)
    local restored = false
    local function RestoreOnce() if not restored then restored = true restoreHud(false) end end
    
    local ScreenshotMaker = import("ScreenshotMaker")
    if not ScreenshotMaker then RestoreOnce() return end
    
    local directory = AF_GetScreenshotDirectory()
    if not directory then RestoreOnce() return end
    
    -- اسم فريد للصورة (إصلاح iOS)
    local uniqueId = 1000 + math.random(1, 8999)
    local timeVal = 0
    pcall(function() timeVal = os.time() or 0 end)
    if timeVal == 0 then timeVal = os.clock() * 1000 end
    local path = directory .. string.format("nthwin_%d_%d.jpg", math.floor(timeVal), uniqueId)
    
    local uiUtil = AF_GetModule("client.common.ui_util")
    local gameInstance = uiUtil and uiUtil.GetGameInstance and uiUtil.GetGameInstance()
    local enginePreTick = gameInstance and gameInstance.EnginePreTick
    
    if not enginePreTick or type(enginePreTick.Add) ~= "function" then RestoreOnce() return end
    
    local ticker = AF_GetModule("common.time_ticker")
    if not ticker or type(ticker.AddTimerOnce) ~= "function" then RestoreOnce() return end
    
    enginePreTick:Add(function()
        local actualPath = ScreenshotMaker.MakePictureByName(path, true)
        if type(enginePreTick.Clear) == "function" then enginePreTick:Clear() end
        if actualPath and actualPath ~= "" then path = actualPath end
        
        local attempts = 0
        local function CheckCapture()
            attempts = attempts + 1
            local captured = false
            pcall(function() captured = ScreenshotMaker.HasCaptured(path) end)
            if captured then
                RestoreOnce()
                pcall(ScreenshotMaker.ResizePicture, path, 0.6, path)
                ticker.AddTimerOnce(2.0, function()
                    if #AF_ReadFile(path) > 0 then
                        AutoFeedback.SendFeedback(path, kills, rank, segment)
                    else 
                        AF_Notify("[ABU RAHAF] ❌ خطأ في قراءة الصورة!")
                    end
                end)
            elseif attempts < 15 then 
                ticker.AddTimerOnce(1, CheckCapture)
            else 
                RestoreOnce() 
                AF_Notify("[ABU RAHAF] ❌ فشل التقاط الصورة!")
            end
        end
        ticker.AddTimerOnce(1, CheckCapture)
    end)
end

function AutoFeedback.ProcessWin(kills)
    -- حماية: لا ترسل لو القفل مفعل (منع التكرار في نفس المباراة)
    if AutoFeedback._SessionLock then
        AF_Log("تم التخطي: صورة هذه المباراة أُرسلت مسبقاً")
        return
    end
    
    kills = tonumber(kills) or 0
    local rank, segment = AF_GetRankAndSegment()
    
    if rank < AutoFeedback.Config.MinRank or kills < AutoFeedback.Config.MinKills then
        AF_Log(string.format("تم التخطي: الرتبة %d، القتلات %d", rank, kills))
        return
    end
    
    -- تفعيل القفل قبل البدء
    AutoFeedback._SessionLock = true
    
    AF_Notify("[ABU RAHAF] 🏆 مبروك! جاري تصوير الشاشة...")
    local setHudHidden = AF_CreateHudController()
    setHudHidden(true)
    local ok, err = pcall(AF_CaptureAndSend, kills, rank, segment, setHudHidden)
    if not ok then 
        setHudHidden(false) 
        AutoFeedback._SessionLock = false  -- إلغاء القفل عند الخطأ
        AF_Log("ProcessWin Error: " .. tostring(err)) 
    end
end

local function AF_GetWinnerKills()
    local kills = 0
    pcall(function()
        local likeUtil = AF_GetModule("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
        if likeUtil and type(likeUtil.GetMyPlayerState) == "function" then
            local ps = likeUtil.GetMyPlayerState()
            if ps and ps.Kills then kills = tonumber(ps.Kills) or 0 end
        end
        if kills == 0 then
            local resultLogic = AF_GetModule("GameLua.Mod.BaseMod.Client.BattleResult.BattleResultData.BattleResultDataLogic", false)
            if resultLogic and type(resultLogic.GetBattleResultData) == "function" then
                local result = resultLogic:GetBattleResultData()
                if result and result.BP_mykill then kills = tonumber(result.BP_mykill) or 0 end
            end
        end
    end)
    return kills
end

local function AF_TryInstallHook()
    pcall(function()
        local UIManager = _G.UIManager
        if not UIManager or not UIManager.ShowUI or UIManager.__NTHMODHooked then return end
        
        AF_Log("Installing Hook on UIManager.ShowUI...")
        local originalShowUI = UIManager.ShowUI
        
        UIManager.ShowUI = function(config, params, ...)
            local result = originalShowUI(config, params, ...)
            pcall(function()
                local inGameConfig = UIManager.UI_Config_InGame
                local winnerConfig = inGameConfig and inGameConfig.GameOverCountDown_UIBP
                
                -- ⚠️ شرط صارم: فقط عند الفوز الحقيقي
                -- Reason يجب أن يكون "win" أو ShowedWinLogo يجب أن يكون true
                if not winnerConfig or config ~= winnerConfig then return end
                
                -- فلترة صارمة: لازم يكون في params دليل واضح على الفوز
                if not params then return end
                
                local isRealWin = false
                if params.Reason == "win" then isRealWin = true end
                if params.ShowedWinLogo == true then isRealWin = true end
                if params.Winner == true then isRealWin = true end
                
                -- ⛔ رفض أي حالة أخرى (الدخول، الخروج، إلخ)
                if not isRealWin then
                    AF_Log("تم التخطي: ليس فوزاً حقيقياً")
                    return
                end
                
                AF_Log("🏆 تم اكتشاف الفوز! جاري التحضير للتصوير...")
                local kills = AF_GetWinnerKills()
                
                if not AF_AddTimerOnce(2, function() AutoFeedback.ProcessWin(kills) end) then
                    AutoFeedback.ProcessWin(kills)
                end
            end)
            return result
        end
        
        UIManager.__NTHMODHooked = true
        AutoFeedback.Hooked = true
        AF_Log("✅ تم تثبيت Hook بنجاح!")
    end)
end

function AutoFeedback.Install()
    AF_Log("=================================================")
    AF_Log("ABU RAHAF VIP - Auto Screenshot System v1.1")
    AF_Log("★ وضع الإرسال: عند الفوز فقط")
    AF_Log("MinRank: " .. AutoFeedback.Config.MinRank)
    AF_Log("MinKills: " .. AutoFeedback.Config.MinKills)
    AF_Log("=================================================")
    
    -- إعادة تعيين القفل عند كل تسجيل دخول جديد
    AutoFeedback._SessionLock = false
    
    if AutoFeedback.Config.TestMode then
        pcall(function()
            AF_AddTimerOnce(5.0, function() 
                AF_Log("TEST MODE: sending test image...")
                AutoFeedback.ProcessWin(10) 
            end)
        end)
    end
    
    pcall(function()
        local ticker = AF_GetModule("common.time_ticker")
        if ticker and type(ticker.AddTimer) == "function" then
            ticker.AddTimer(3.0, AF_TryInstallHook)
        else 
            AF_TryInstallHook() 
        end
    end)
end

-- إعادة تعيين القفل عند بداية مباراة جديدة
pcall(function()
    local ticker = AF_GetModule("common.time_ticker")
    if ticker and ticker.AddTimer then
        ticker.AddTimer(5.0, function()
            -- عند تغيير حالة اللعبة = مباراة جديدة
            pcall(function()
                local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
                if gs then
                    local currentMatchId = tostring(gs.GameModeID or "") .. "_" .. tostring(gs.MatchID or "")
                    if AutoFeedback._LastMatchId ~= currentMatchId then
                        AutoFeedback._LastMatchId = currentMatchId
                        AutoFeedback._SessionLock = false
                        AF_Log("🔄 مباراة جديدة - إعادة تعيين القفل")
                    end
                end
            end)
        end)
    end
end)

AutoFeedback.Base64Encode = AF_Base64Encode
AutoFeedback.UrlEncode = AF_UrlEncode
AutoFeedback.GetRankName = AF_GetRankName
_G.ABU_RAHAF_AutoFeedback = AutoFeedback

-- 🚀 التشغيل التلقائي
AutoFeedback.Install()

-- ==============================================================================
-- ========================== نهاية نظام الصور التلقائي =========================
-- ==============================================================================

-- ==================== INTEGRATED FILE 1: TOGGLE-CONTROLLED ESP ====================
local ESP_Enabled = false

local FVector2D = _G.FVector2D or import("Vector2D")
local FLinearColor = _G.FLinearColor or import("LinearColor")
local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
local SlateColor = nil
local GameplayStaticsESP = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)
pcall(function() SlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor") end)
pcall(function() GameplayStaticsESP = import("GameplayStatics") end)
local KismetSystemLibraryESP = nil
local HitResultClassESP = nil
pcall(function() KismetSystemLibraryESP = import("KismetSystemLibrary") end)
pcall(function() HitResultClassESP = import("HitResult") end)
local TraceStartPos = { X = 0, Y = 0, Z = 0 }
local CachedHitResult = nil
pcall(function()
  if HitResultClassESP then CachedHitResult = HitResultClassESP()
  else CachedHitResult = {} end
end)

local function ESPValid(obj)
  if obj == nil then return false end
  local ok, v = pcall(function() return slua.isValid(obj) end)
  return ok and v == true
end

local function ESPV2(x, y)
  if FVector2D then return FVector2D(x, y) end
  return { X = x, Y = y }
end

local function ESPMKC(r, g, b, a)
  if FLinearColor then return FLinearColor(r, g, b, a) end
  return { R = r, G = g, B = b, A = a }
end

local CFG = {
  MaxDistance = 40000,      -- cm (400 m)
  MaxTracked = 16,
  ScreenMargin = 220,
  TopTextY = 6.0,           -- canvas px, bilkul upar center
  SnapOriginY = 0.0,        -- top edge se start (esplook jaisa)
  SnapThickness = 1.8,
  CornerThickness = 2.2,
  CornerLen = 0.28,
  CornerMin = 6,
  CornerMax = 28,
  BoxMinWidth = 22,
  BoxMaxWidth = 320,
  BoxMinHeight = 14,
  BoxWidthFactor = 0.62,
  WidthScale = 1.22,
  HeadExtra = 0.06,
  FootExtra = 0.02,
  SideBarWidth = 3.5,
  SideBarGap = 5.0,
  SideBgAlpha = 0.55,
  MarkGap = 8.0,            -- box top se chevron tak gap
  MarkW = 15.0,             -- ek V ki aadhi chaudai
  MarkH = 10.0,             -- ek V ki unchai
  MarkGapV = 6.0,           -- do V ke beech gap
  MarkThickness = 2.4,
  NameFontSize = 15,
  DistFontSize = 13,
  StateFontSize = 13,
  TextGap = 1.0,
  CounterFontSize = 17,
  CounterW = 300.0,
  CounterH = 28.0,
  DeadZone = 0.5,           -- px, isse kam harkat = slate ko chhuna nahi (flicker fix)
  VisInterval = 0.15,       -- sec, LineTrace itni der me ek bar per target (lag fix)
  SizeHyst = 2.0,           -- px, viewport me itna farq ignore
}

-- esplook.png colors
local C_WHITE  = ESPMKC(1.0, 1.0, 1.0, 1.0)
local C_BLACK  = ESPMKC(0.0, 0.0, 0.0, 1.0)
local C_GREEN  = ESPMKC(0.12, 1.0, 0.25, 1.0)   -- snap line + "Open"
local C_RED    = ESPMKC(1.0, 0.15, 0.15, 1.0)   -- low health + "Close"
local C_YELLOW = ESPMKC(1.0, 0.90, 0.30, 1.0)   -- double chevron
local C_BLUE   = ESPMKC(0.38, 0.72, 1.0, 1.0)   -- "Bot" name

local function RND(v)
  if v ~= v then return 0 end
  return math.floor(v + 0.5)
end

local function Lerp(a, b, t) return a + (b - a) * t end

-- Health color: 100% green | 70% green+halka yellow | 40% red+halka white | 20% red
local function HealthColor(pct)
  pct = tonumber(pct) or 1.0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  local r, g, b
  if pct >= 0.7 then
    local t = (pct - 0.7) / 0.3
    r = Lerp(0.75, 0.12, t)
    g = 1.0
    b = Lerp(0.15, 0.25, t)
  elseif pct >= 0.4 then
    local t = (pct - 0.4) / 0.3
    r = 1.0
    g = Lerp(0.45, 0.95, t)
    b = Lerp(0.45, 0.20, t)
  else
    local t = pct / 0.4
    r = 1.0
    g = Lerp(0.15, 0.45, t)
    b = Lerp(0.15, 0.45, t)
  end
  return ESPMKC(r, g, b, 1.0)
end

local ESP = {}
ESP.Canvas = nil
ESP.Lines = {}      -- snap lines : key -> {Widget, Slot}
ESP.Corners = {}    -- corner boxes: key -> {w1..w8 Widget/Slot}
ESP.HealthBg = {}   -- health bg (dark) : key -> {Widget, Slot}
ESP.HealthFill = {} -- health fill (pct + color) : key -> {Widget, Slot}
ESP.Marks = {}      -- yellow chevron: key -> {4 x Widget/Slot}
ESP.Infos = {}      -- bottom texts: key -> {Container, Name, Dist, State, slots}
ESP.Counter = nil   -- top "Players: X | Bots: Y"
ESP.EnemyCache = {}
ESP.VisCache = {}   -- visibility cache: key -> {b, t}
ESP.ScaleX = 1.0
ESP.ScaleY = 1.0
ESP.OffsetX = 0.0
ESP.OffsetY = 0.0
ESP.ViewW = 1920
ESP.ViewH = 1080
ESP.ScanInterval = 0.35
ESP.LightInterval = 0.033
ESP.TransformInterval = 0.50
ESP.LastScan = -999.0
ESP.LastTransform = -999.0
ESP.LastWorld = nil
ESP.bActive = false

function ESP.GetGameplayData()
  if ESP._GDP then return ESP._GDP end
  local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
  if ok and GDP then ESP._GDP = GDP return GDP end
  return nil
end

function ESP.GetController()
  local pc = nil
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP and GDP.GetPlayerController then pc = GDP.GetPlayerController() end
  end)
  if not ESPValid(pc) then
    pcall(function()
      if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
    end)
  end
  return ESPValid(pc) and pc or nil
end

function ESP.GetLocalCharacter()
  local c = nil
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP then
      if GDP.GetPlayerCharacter then c = GDP.GetPlayerCharacter() end
      if not ESPValid(c) and GDP.GetLocalCharacter then c = GDP.GetLocalCharacter() end
    end
  end)
  if not ESPValid(c) then
    local pc = ESP.GetController()
    pcall(function() if pc and pc.GetPawn then c = pc:GetPawn() end end)
  end
  return ESPValid(c) and c or nil
end

function ESP.GetAllCharacters()
  local AllChars = {}
  pcall(function()
    local Pawns = Game:GetAllPlayerPawns()
    if Pawns then
      for _, Pawn in pairs(Pawns) do
        if Pawn and slua.isValid(Pawn) then
          local pKey = nil
          if Pawn.GetPlayerKey then pcall(function() pKey = Pawn:GetPlayerKey() end) end
          if not pKey and Pawn.PlayerKey then pKey = Pawn.PlayerKey end
          if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then pKey = Pawn.PlayerState.PlayerKey end
          if pKey then AllChars[pKey] = Pawn end
        end
      end
    end
  end)
  if not next(AllChars) then
    pcall(function()
      local GS = require("GameLua.GameCore.Data.CGameState")
      if GS and GS.GetAllCharacters then AllChars = GS:GetAllCharacters() end
    end)
  end
  return AllChars
end

function ESP.GetMyPlayerKey()
  local pc = ESP.GetController()
  if not ESPValid(pc) then return nil end
  local k = nil
  pcall(function()
    if pc.GetPlayerKey then k = pc:GetPlayerKey()
    elseif pc.PlayerState and pc.PlayerState.PlayerKey then k = pc.PlayerState.PlayerKey end
  end)
  return k
end

function ESP.IsMe(Character, PlayerKey, MyKey)
  local me = false
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP and GDP.GetLocalCharacter then
      local mc = GDP.GetLocalCharacter()
      if mc and Character == mc then me = true return end
    end
    local pc = ESP.GetController()
    if pc and pc.GetPawn then
      local p = pc:GetPawn()
      if p and Character == p then me = true return end
    end
  end)
  if not me and MyKey ~= nil and PlayerKey ~= nil then
    me = (tostring(PlayerKey) == tostring(MyKey))
  end
  return me
end

function ESP.GetTeamID(Character)
  if not ESPValid(Character) then return nil end
  local id = nil
  pcall(function() if Character.GetTeamID then id = Character:GetTeamID() end end)
  if id == nil then pcall(function() id = Character.TeamID end) end
  if id == nil then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then ps = Character:GetPlayerState() end
    end)
    if not ESPValid(ps) then pcall(function() ps = Character.PlayerState end) end
    if ESPValid(ps) then
      pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
      if id == nil then pcall(function() id = ps.TeamID end) end
    end
  end
  return id
end

function ESP.IsAlive(Character)
  if not ESPValid(Character) then return false end
  local alive = nil
  pcall(function() if Character.IsAlive then alive = Character:IsAlive() end end)
  if type(alive) == "boolean" then return alive end
  local hp = nil
  pcall(function() hp = Character.Health end)
  if type(hp) ~= "number" then pcall(function() hp = Character.HP end) end
  if type(hp) == "number" then return hp > 0 end
  return true
end

function ESP.IsKnocked(Character)
  if not ESPValid(Character) then return false end
  local k = false
  pcall(function()
    if Character.HealthStatus == 1 then k = true end
  end)
  if not k then pcall(function()
    if Character.IsNearDeath and Character:IsNearDeath() then k = true end
  end) end
  return k
end

function ESP.IsBot(Character)
  if not ESPValid(Character) then return false end
  local bAI = false
  pcall(function()
    if Game and Game.IsAI then bAI = Game:IsAI(Character) end
    if not bAI and Character then
      if Character.bEnsure == true or Character.bMEnsure == true then bAI = true
      elseif Character.PlayerState and Character.PlayerState.bPSEnsure == true then bAI = true
      elseif Character.Controller then
        if Character.Controller.IsMLAI == true or Character.Controller.FakePlayerBornType == 1 then bAI = true end
      end
    end
  end)
  if not bAI then
    pcall(function()
      if Character.bIsAI == true then bAI = true end
    end)
  end
  if not bAI then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety() end
    end)
    if ESPValid(ps) then
      pcall(function()
        if ps.bIsABot == true or ps.bIsBot == true or ps.bIsAI == true then bAI = true end
      end)
    end
  end
  return bAI
end

function ESP.GetPlayerKey(Character)
  local key = nil
  pcall(function() if Character.GetPlayerKey then key = Character:GetPlayerKey() end end)
  if key == nil then pcall(function() key = Character.PlayerKey end) end
  return tostring(key or Character)
end

function ESP.GetHealthPct(Character)
  if not ESPValid(Character) then return 1.0 end
  local hp, maxhp = nil, nil
  pcall(function() hp = Character.Health end)
  if type(hp) ~= "number" then pcall(function() hp = Character.HP end) end
  pcall(function() maxhp = Character.MaxHealth end)
  if type(maxhp) ~= "number" then pcall(function() maxhp = Character.MaxHP end) end
  if type(hp) ~= "number" then return 1.0 end
  if type(maxhp) ~= "number" or maxhp <= 0 then maxhp = 100 end
  local pct = hp / maxhp
  if pct ~= pct then return 1.0 end
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  return pct
end

local function NormalizeName(v)
  if v == nil or v == false then return nil end
  local ok, t = pcall(tostring, v)
  if not ok or not t then return nil end
  t = t:gsub("^%s+", ""):gsub("%s+$", "")
  if t == "" or t == "nil" or t == "None" or t == "NULL" or t == "Unknown" then return nil end
  return t
end

function ESP.ResolveName(Character, isBot)
  if isBot then return "Bot" end
  local name = nil
  local function take(v)
    if not name then name = NormalizeName(v) end
  end
  pcall(function() if Character.GetPlayerNameSafety then take(Character:GetPlayerNameSafety()) end end)
  pcall(function() if not name and Character.GetPlayerName then take(Character:GetPlayerName()) end end)
  pcall(function() if not name then take(Character.PlayerName) end end)
  pcall(function() if not name then take(Character.NickName) end end)
  if not name then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then ps = Character:GetPlayerState() end
    end)
    if not ESPValid(ps) then pcall(function() ps = Character.PlayerState end) end
    if ESPValid(ps) then
      pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
      pcall(function() if not name then take(ps.PlayerName) end end)
      pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
      pcall(function() if not name then take(ps.NickName) end end)
    end
  end
  return name or "Player"
end

function ESP.GetBonePos(Character, boneName)
  if not ESPValid(Character) or not boneName then return nil end
  local pos = nil
  pcall(function()
    if type(Character.GetBonePos) == "function" then
      pos = Character:GetBonePos(boneName, { X = 0, Y = 0, Z = 0 })
    end
    if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
      if type(Character.GetSocketLocation) == "function" then
        pos = Character:GetSocketLocation(boneName)
      end
    end
    if (not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0)) and ESPValid(Character.Mesh) then
      local mesh = Character.Mesh
      if mesh and mesh.GetSocketLocation then
        local mp = mesh:GetSocketLocation(boneName)
        if mp and not (mp.X == 0 and mp.Y == 0 and mp.Z == 0) then pos = mp end
      end
    end
  end)
  return pos
end

function ESP.GetCamLoc(pc)
  local loc = nil
  pcall(function()
    if GameplayStaticsESP and GameplayStaticsESP.GetPlayerCameraManager then
      local mgr = GameplayStaticsESP.GetPlayerCameraManager(pc, 0)
      if ESPValid(mgr) and mgr.GetCameraLocation then loc = mgr:GetCameraLocation() end
    end
  end)
  if not loc then
    pcall(function()
      if pc and pc.GetPawn then
        local p = pc:GetPawn()
        if ESPValid(p) and p.K2_GetActorLocation then loc = p:K2_GetActorLocation() end
      end
    end)
  end
  return loc
end

function ESP.IsBoneVisible(pc, camLoc, target, bonePos)
  if not ESPValid(pc) or not ESPValid(target) or not bonePos or not camLoc then return false end
  if not KismetSystemLibraryESP or not KismetSystemLibraryESP.LineTraceSingle then return true end
  local dx = bonePos.X - camLoc.X
  local dy = bonePos.Y - camLoc.Y
  local dz = bonePos.Z - camLoc.Z
  local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
  if dist < 50 then return true end
  TraceStartPos.X = camLoc.X + (dx / dist) * 60
  TraceStartPos.Y = camLoc.Y + (dy / dist) * 60
  TraceStartPos.Z = camLoc.Z + (dz / dist) * 60
  local bVis = false
  pcall(function()
    local bHit = KismetSystemLibraryESP.LineTraceSingle(
      pc, TraceStartPos, bonePos, 0, false, nil, 0, CachedHitResult, true)
    if bHit then
      local hitActor = nil
      if CachedHitResult then
        if type(CachedHitResult.GetActor) == "function" then
          hitActor = CachedHitResult:GetActor()
        elseif CachedHitResult.Actor then
          hitActor = CachedHitResult.Actor
        end
      end
      if ESPValid(hitActor) then
        if hitActor == target then bVis = true end
      end
    else
      bVis = true
    end
  end)
  return bVis
end

function ESP.IsVisible(key, pc, camLoc, Character)
  local now = ESP.Now()
  local cached = ESP.VisCache[key]
  if cached and (now - (cached.t or 0)) < (CFG.VisInterval or 0.15) then
    return cached.b
  end
  local bVis = false
  if ESPValid(Character) and ESPValid(pc) and camLoc then
    local bones = { "head", "spine_03", "pelvis" }
    for _, bn in ipairs(bones) do
      local bp = ESP.GetBonePos(Character, bn)
      if bp and (bp.X ~= 0 or bp.Y ~= 0 or bp.Z ~= 0) then
        if ESP.IsBoneVisible(pc, camLoc, Character, bp) then bVis = true break end
      end
    end
  else
    bVis = true
  end
  ESP.VisCache[key] = { b = bVis, t = now }
  return bVis
end

function ESP.ActorLocation(Character)
  local loc = nil
  if not ESPValid(Character) then return nil end
  pcall(function()
    if Character.K2_GetActorLocation then loc = Character:K2_GetActorLocation()
    elseif Game and Game.GetActorLocation then loc = Game:GetActorLocation(Character) end
  end)
  return loc
end

function ESP.DistMeters(a, b)
  if not a or not b then return math.huge end
  local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
  return math.sqrt(dx * dx + dy * dy + dz * dz) / 100.0
end

function ESP.GetVerticalBounds(Character)
  if not ESPValid(Character) then return nil, nil end
  local center, halfHeight = nil, nil
  local capsule = nil
  pcall(function()
    if Character.GetCapsuleComponent then capsule = Character:GetCapsuleComponent()
    elseif Character.CapsuleComponent then capsule = Character.CapsuleComponent end
  end)
  if capsule and ESPValid(capsule) then
    pcall(function()
      if capsule.K2_GetComponentLocation then center = capsule:K2_GetComponentLocation()
      elseif capsule.GetComponentLocation then center = capsule:GetComponentLocation() end
      if capsule.GetScaledCapsuleHalfHeight then halfHeight = capsule:GetScaledCapsuleHalfHeight()
      elseif capsule.GetUnscaledCapsuleHalfHeight then halfHeight = capsule:GetUnscaledCapsuleHalfHeight()
      elseif capsule.CapsuleHalfHeight then halfHeight = capsule.CapsuleHalfHeight end
    end)
  end
  if not center then
    pcall(function() if Character.K2_GetActorLocation then center = Character:K2_GetActorLocation() end end)
  end
  if not center then
    pcall(function() if Game and Game.GetActorLocation then center = Game:GetActorLocation(Character) end end)
  end
  if not center then return nil, nil end
  if not halfHeight or halfHeight < 10 or halfHeight > 200 then
    halfHeight = 85
    pcall(function()
      if Character.bIsCrouched then halfHeight = 60 end
      if Character.IsProne and Character:IsProne() then halfHeight = 25 end
    end)
  end
  return center, halfHeight
end

function ESP.GetHeadFeet(Character)
  local center, half = ESP.GetVerticalBounds(Character)
  if not center or not half then return nil, nil end
  local head = { X = center.X, Y = center.Y, Z = center.Z + half }
  local feet = { X = center.X, Y = center.Y, Z = center.Z - half }
  return head, feet
end

function ESP.Now()
  local t = nil
  pcall(function()
    local w = (slua and slua.getWorld and slua.getWorld()) or nil
    if GameplayStaticsESP and w and GameplayStaticsESP.GetRealTimeSeconds then
      t = GameplayStaticsESP.GetRealTimeSeconds(w)
    end
  end)
  if tonumber(t) then return tonumber(t) end
  pcall(function() if os and os.clock then t = os.clock() end end)
  return tonumber(t) or 0.0
end

function ESP.World()
  local w = nil
  pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
  return w
end

-- ---------- canvas ----------
function ESP.GetCanvas()
  if ESPValid(ESP.Canvas) then return ESP.Canvas end
  local root = nil
  pcall(function()
    local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
    if InGameUITools and InGameUITools.GetMainControlBaseUI then root = InGameUITools.GetMainControlBaseUI() end
  end)
  if not ESPValid(root) then return nil end
  local canvas = nil
  pcall(function()
    if ESPValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
    elseif ESPValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
  end)
  if ESPValid(canvas) then ESP.Canvas = canvas return canvas end
  return nil
end

function ESP.UpdateCanvasTransform(pc)
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return false end
  local calibrated = false
  pcall(function()
    if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
      local geo = canvas:GetCachedGeometry()
      if geo then
        local p0 = SlateBlueprintLibrary.AbsoluteToLocal(geo, ESPV2(0, 0))
        local p1 = SlateBlueprintLibrary.AbsoluteToLocal(geo, ESPV2(100, 100))
        if p0 and p1 and tonumber(p0.X) and tonumber(p1.X) and p1.X ~= p0.X and p1.Y ~= p0.Y then
          ESP.ScaleX = (p1.X - p0.X) / 100.0
          ESP.ScaleY = (p1.Y - p0.Y) / 100.0
          ESP.OffsetX = p0.X
          ESP.OffsetY = p0.Y
          calibrated = true
        end
      end
    end
  end)
  if not calibrated then
    local scale = 1.0
    pcall(function()
      if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
        local s = WidgetLayoutLibrary.GetViewportScale(pc)
        if tonumber(s) and s > 0 then scale = s end
      end
    end)
    ESP.ScaleX = 1.0 / scale
    ESP.ScaleY = 1.0 / scale
    ESP.OffsetX = 0.0
    ESP.OffsetY = 0.0
  end
  return true
end

function ESP.Viewport(pc)
  local w, h = 1920.0, 1080.0
  pcall(function()
    if pc and pc.GetViewportSize then
      local v = ESPV2(0, 0)
      pc:GetViewportSize(v)
      if v and tonumber(v.X) and v.X > 200 then w, h = v.X, v.Y end
    end
  end)
  return w, h
end

function ESP.Project(pc, worldLoc)
  if not pc or not worldLoc then return nil end
  local pix = ESPV2(0, 0)
  local ok = false
  pcall(function()
    local res = pc:ProjectWorldLocationToScreen(worldLoc, pix, true)
    ok = (res == true or res == 1 or (pix and (pix.X ~= 0 or pix.Y ~= 0)))
  end)
  if not ok then return nil end
  return ESPV2(pix.X * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0),
               pix.Y * (ESP.ScaleY or 1.0) + (ESP.OffsetY or 0.0)), pix
end

function ESP.SnapOrigin(pc, viewW)
  -- esplook: origin bilkul top-center
  local cw = nil
  pcall(function()
    local canvas = ESP.GetCanvas()
    if ESPValid(canvas) then
      local geo = canvas:GetCachedGeometry()
      if geo and geo.GetLocalSize then
        local s = geo:GetLocalSize()
        if s and tonumber(s.X) and s.X > 1 then cw = tonumber(s.X) end
      end
    end
  end)
  local cx = nil
  if tonumber(cw) and cw > 1 then cx = cw * 0.5
  else cx = (viewW * 0.5) * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0) end
  return ESPV2(cx, (CFG.SnapOriginY or 0.0))
end

-- ---------- widget helpers (Help patterns) ----------
function ESP.SetFont(w, size)
  if not ESPValid(w) then return end
  pcall(function()
    local f = w.Font
    if f then
      f.Size = size
      if f.OutlineSettings then
        pcall(function() f.OutlineSettings.OutlineSize = 1 end)
        pcall(function() f.OutlineSettings.OutlineColor = C_BLACK end)
      end
      w:SetFont(f)
    end
    if w.SetShadowOffset then w:SetShadowOffset(ESPV2(1.0, 1.0)) end
    if w.SetShadowColorAndOpacity then w:SetShadowColorAndOpacity(C_BLACK) end
  end)
end

function ESP.SetTextColor(w, color)
  if not ESPValid(w) then return end
  pcall(function()
    if SlateColor then w:SetColorAndOpacity(SlateColor(color))
    else w:SetColorAndOpacity(color) end
  end)
end

function ESP.NewLine(color, z)
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local border = nil
  pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
  if not ESPValid(border) then return nil end
  pcall(function()
    border:SetBrushColor(color)
    border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    border:SetRenderTransformPivot(ESPV2(0.0, 0.5))
  end)
  local slot = nil
  pcall(function() slot = canvas:AddChildToCanvas(border) end)
  if not slot then
    pcall(function() border:RemoveFromParent() end)
    return nil
  end
  pcall(function() slot:SetAutoSize(false) slot:SetZOrder(z or 30) end)
  return { Widget = border, Slot = slot }
end

function ESP.DrawLine(data, x1, y1, x2, y2, thickness)
  if not data or not ESPValid(data.Widget) or not data.Slot then return false end
  if x1 ~= x1 or y1 ~= y1 or x2 ~= x2 or y2 ~= y2 then return false end
  x1, y1, x2, y2 = RND(x1), RND(y1), RND(x2), RND(y2)
  local dz = CFG.DeadZone or 0.5
  if data.lx1 and data.th == thickness then
    if math.abs((data.lx1 or 0) - x1) < dz and math.abs((data.ly1 or 0) - y1) < dz
    and math.abs((data.lx2 or 0) - x2) < dz and math.abs((data.ly2 or 0) - y2) < dz then
      if data.hidden ~= true then return true end
    end
  end
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then
    ESP.Hide(data)
    return false
  end
  local angle = ((math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)) * 180.0 / math.pi
  angle = math.floor(angle * 10 + 0.5) / 10
  len = RND(len)
  if data.lx1 == x1 and data.ly1 == y1 and data.lx2 == x2 and data.ly2 == y2 and data.th == thickness then
    if data.hidden == true then
      pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      data.hidden = false
    end
    return true
  end
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x1, y1 - thickness * 0.5))
    data.Slot:SetSize(ESPV2(len, thickness))
    data.Widget:SetRenderAngle(angle)
    data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  if ok then
    data.lx1, data.ly1, data.lx2, data.ly2, data.th = x1, y1, x2, y2, thickness
    data.hidden = false
  end
  return true
end

function ESP.DrawVBar(data, x, top, h, thickness)
  -- vertical health bar: no angle math, seedha Position+Size (double-draw fix)
  if not data or not ESPValid(data.Widget) or not data.Slot then return false end
  if h ~= h or h < 1 then ESP.Hide(data) return false end
  x, top, h = RND(x), RND(top), RND(h)
  local dz = CFG.DeadZone or 0.5
  if data.bx ~= nil then
    if math.abs(data.bx - x) < dz and math.abs(data.bt - top) < dz and math.abs(data.bh - h) < dz then
      if data.hidden ~= true then return true end
    end
  end
  if data.bx == x and data.bt == top and data.bh == h then
    if data.hidden == true then
      pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      data.hidden = false
    end
    return true
  end
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x, top))
    data.Slot:SetSize(ESPV2(thickness, h))
    data.Widget:SetRenderAngle(0)
    data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  if ok then data.bx, data.bt, data.bh = x, top, h data.hidden = false end
  return true
end

function ESP.Hide(data)
  if data and ESPValid(data.Widget) and data.hidden ~= true then
    pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    data.hidden = true
    data.lx1, data.ly1, data.lx2, data.ly2, data.th = nil, nil, nil, nil, nil
    data.bx, data.bt, data.bh = nil, nil, nil
  end
end

function ESP.SetBrush(data, color, colorKey)
  if not data or not ESPValid(data.Widget) then return end
  if colorKey and data.colorKey == colorKey then return end
  pcall(function() data.Widget:SetBrushColor(color) end)
  if colorKey then data.colorKey = colorKey end
end

function ESP.Destroy(data)
  if not data then return end
  local w = data.Widget or data.Container
  if ESPValid(w) then
    pcall(function() w:RemoveFromParent() end)
    pcall(function() w:ConditionalBeginDestroy() end)
  end
end

-- top counter "Players: X | Bots: Y" : bilkul center-top
function ESP.CreateCounter()
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local container = nil
  pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
  if not ESPValid(container) then return nil end
  local txt = nil
  pcall(function() txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  if not ESPValid(txt) then ESP.Destroy({ Widget = container }) return nil end
  pcall(function()
    txt:SetText("Players: 0 | Bots: 0")
    txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    if txt.SetJustification then txt:SetJustification(1) end
  end)
  ESP.SetTextColor(txt, C_WHITE)
  ESP.SetFont(txt, CFG.CounterFontSize)
  local tSlot, mSlot = nil, nil
  pcall(function() tSlot = container:AddChildToCanvas(txt) end)
  pcall(function() mSlot = canvas:AddChildToCanvas(container) end)
  if not tSlot or not mSlot then ESP.Destroy({ Widget = container }) return nil end
  local W, H = CFG.CounterW or 300.0, CFG.CounterH or 28.0
  pcall(function()
    tSlot:SetAutoSize(true)
    tSlot:SetAlignment(ESPV2(0.5, 0.5))
    tSlot:SetPosition(ESPV2(W * 0.5, H * 0.5))
    tSlot:SetZOrder(5)
    mSlot:SetAutoSize(false)
    mSlot:SetAlignment(ESPV2(0.5, 0.0))
    mSlot:SetSize(ESPV2(W, H))
    mSlot:SetZOrder(60)
  end)
  return { Container = container, Text = txt, Slot = mSlot, W = W, H = H }
end

function ESP.CanvasCenterX(viewW)
  local cw = nil
  pcall(function()
    local canvas = ESP.GetCanvas()
    if ESPValid(canvas) then
      local geo = canvas:GetCachedGeometry()
      if geo and geo.GetLocalSize then
        local s = geo:GetLocalSize()
        if s and tonumber(s.X) and s.X > 1 then cw = tonumber(s.X) end
      end
    end
  end)
  if tonumber(cw) and cw > 1 then return cw * 0.5 end
  return (viewW * 0.5) * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0)
end

function ESP.UpdateCounter(nPlayers, nBots, pc, viewW)
  local d = ESP.Counter
  if not d or not ESPValid(d.Container) then
    ESP.Destroy(d)
    d = ESP.CreateCounter()
    ESP.Counter = d
  end
  if not d then return nil end
  local label = string.format("Players: %d | Bots: %d", nPlayers or 0, nBots or 0)
  pcall(function()
    if d.Last ~= label then d.Text:SetText(label) d.Last = label end
  end)
  local cx = ESP.CanvasCenterX(viewW)
  if cx then
    cx = RND(cx)
    if d.px == nil or math.abs(d.px - cx) >= 1.0 then
      d.px = cx
      pcall(function()
        -- alignment (0.5,0) hai, isliye seedha center X do (cx-150 wala purana math hata diya)
        d.Slot:SetPosition(ESPV2(cx, CFG.TopTextY))
        d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
    else
      pcall(function()
        d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
    end
  end
  return ESPV2(cx, (CFG.SnapOriginY or 0.0))
end

-- bottom info: Bot / 16m / Open
function ESP.CreateInfo()
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local container, tName, tDist, tState = nil, nil, nil, nil
  pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
  if not ESPValid(container) then return nil end
  pcall(function() tName = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tDist = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tState = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  if not ESPValid(tName) or not ESPValid(tDist) or not ESPValid(tState) then
    ESP.Destroy({ Widget = container })
    return nil
  end
  pcall(function()
    tName:SetText("Bot")
    tDist:SetText("0m")
    tState:SetText("Open")
    tName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tDist:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tState:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    if tName.SetJustification then tName:SetJustification(1) end
    if tDist.SetJustification then tDist:SetJustification(1) end
    if tState.SetJustification then tState:SetJustification(1) end
  end)
  ESP.SetTextColor(tName, C_BLUE)
  ESP.SetTextColor(tDist, C_WHITE)
  ESP.SetTextColor(tState, C_GREEN)
  ESP.SetFont(tName, CFG.NameFontSize)
  ESP.SetFont(tDist, CFG.DistFontSize)
  ESP.SetFont(tState, CFG.StateFontSize)
  local s1, s2, s3, ms = nil, nil, nil, nil
  pcall(function() s1 = container:AddChildToCanvas(tName) end)
  pcall(function() s2 = container:AddChildToCanvas(tDist) end)
  pcall(function() s3 = container:AddChildToCanvas(tState) end)
  pcall(function() ms = canvas:AddChildToCanvas(container) end)
  if not s1 or not s2 or not s3 or not ms then
    ESP.Destroy({ Widget = container })
    return nil
  end
  pcall(function()
    s1:SetAutoSize(true) s1:SetAlignment(ESPV2(0.5, 0.5)) s1:SetZOrder(36)
    s2:SetAutoSize(true) s2:SetAlignment(ESPV2(0.5, 0.5)) s2:SetZOrder(36)
    s3:SetAutoSize(true) s3:SetAlignment(ESPV2(0.5, 0.5)) s3:SetZOrder(36)
    ms:SetAutoSize(false) ms:SetZOrder(35)
  end)
  return { Container = container, Name = tName, Dist = tDist, State = tState,
           S1 = s1, S2 = s2, S3 = s3, Slot = ms }
end

function ESP.UpdateInfo(key, Character, isBot, distM, bVisible, footX, footY)
  local d = ESP.Infos[key]
  if not d or not ESPValid(d.Container) then
    ESP.Destroy(d)
    d = ESP.CreateInfo()
    ESP.Infos[key] = d
  end
  if not d then return end
  -- Bot pe "Bot", real player pe real name (cache, flicker fix)
  local name = d.CachedName
  if not name then
    name = ESP.ResolveName(Character, isBot)
    d.CachedName = name
  end
  if isBot then
    name = "Bot"
    d.CachedName = "Bot"
  end
  local dl = string.format("%dm", math.max(0, math.floor((tonumber(distM) or 0) + 0.5)))
  -- Visibility: Open (green) / Close (red)
  local st = bVisible and "Open" or "Close"
  local stKey = bVisible and "open" or "close"
  pcall(function()
    if d.LastN ~= name then
      d.Name:SetText(name) d.LastN = name
      -- Bot = blue, real name = white
      if isBot then ESP.SetTextColor(d.Name, C_BLUE)
      else ESP.SetTextColor(d.Name, C_WHITE) end
    end
    if d.LastD ~= dl then d.Dist:SetText(dl) d.LastD = dl end
    if d.LastS ~= st then
      d.State:SetText(st) d.LastS = st
      if bVisible then ESP.SetTextColor(d.State, C_GREEN)
      else ESP.SetTextColor(d.State, C_RED) end
    end
    if d.LastK ~= stKey then d.LastK = stKey end
  end)
  -- 3 lines, centered under feet (pos cache, flicker fix)
  local w = 120.0
  local h1, h2, h3 = 20.0, 17.0, 17.0
  local x = RND(footX - w * 0.5)
  local y = RND(footY + 4.0)
  if d.ix == nil or math.abs(d.ix - x) >= 1.0 or math.abs((d.iy or 0) - y) >= 1.0 then
    d.ix, d.iy = x, y
    pcall(function()
      d.Slot:SetPosition(ESPV2(x, y))
      d.Slot:SetSize(ESPV2(w, h1 + h2 + h3 + 6.0))
      d.S1:SetPosition(ESPV2(w * 0.5, h1 * 0.5))
      d.S2:SetPosition(ESPV2(w * 0.5, h1 + h2 * 0.5 + CFG.TextGap))
      d.S3:SetPosition(ESPV2(w * 0.5, h1 + h2 + h3 * 0.5 + CFG.TextGap * 2.0))
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
  else
    pcall(function()
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
  end
end

function ESP.EnsureCorner(key, idx, color)
  local t = ESP.Corners[key]
  if not t then t = {} ESP.Corners[key] = t end
  local d = t[idx]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(color or C_WHITE, 32)
  t[idx] = d
  return d
end

function ESP.EnsureHealthBg(key)
  local d = ESP.HealthBg[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(ESPMKC(0.0, 0.0, 0.0, CFG.SideBgAlpha or 0.55), 31)
  ESP.HealthBg[key] = d
  return d
end

function ESP.EnsureHealthFill(key)
  local d = ESP.HealthFill[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(C_GREEN, 32)
  ESP.HealthFill[key] = d
  return d
end

-- Health bar: bg full height + fill bottom-se-up pct height, color HealthColor()
-- single bg + single fill per target (double-draw fix)
function ESP.UpdateHealthBar(key, pct, x, top, h)
  local bg = ESP.EnsureHealthBg(key)
  local fill = ESP.EnsureHealthFill(key)
  if not bg or not fill then return end
  local w = CFG.SideBarWidth or 3.5
  ESP.DrawVBar(bg, x, top, h, w)
  pct = tonumber(pct) or 1.0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  -- color bucket cache: har frame SetBrushColor nahi (flicker fix)
  local bucket
  if pct >= 0.7 then bucket = "g_" .. math.floor(pct * 20 + 0.5)
  elseif pct >= 0.4 then bucket = "y_" .. math.floor(pct * 20 + 0.5)
  else bucket = "r_" .. math.floor(pct * 20 + 0.5) end
  ESP.SetBrush(fill, HealthColor(pct), bucket)
  local fh = h * pct
  if fh < 1 then
    ESP.Hide(fill)
    return
  end
  -- bottom anchored: khali hissa upar, bhara hissa neeche
  ESP.DrawVBar(fill, x, top + (h - fh), fh, w)
end

function ESP.EnsureMark(key, idx)
  local t = ESP.Marks[key]
  if not t then t = {} ESP.Marks[key] = t end
  local d = t[idx]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(C_YELLOW, 33)
  t[idx] = d
  return d
end

function ESP.EnsureSnap(key)
  local d = ESP.Lines[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(C_GREEN, 30)
  ESP.Lines[key] = d
  return d
end

function ESP.HideTarget(key)
  local c = ESP.Corners[key]
  if c then for i = 1, 8 do ESP.Hide(c[i]) end end
  ESP.Hide(ESP.HealthBg[key])
  ESP.Hide(ESP.HealthFill[key])
  local m = ESP.Marks[key]
  if m then for i = 1, 4 do ESP.Hide(m[i]) end end
  ESP.Hide(ESP.Lines[key])
  local inf = ESP.Infos[key]
  if inf and ESPValid(inf.Container) then
    pcall(function() inf.Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
  end
end

function ESP.ReleaseTarget(key)
  local c = ESP.Corners[key]
  if c then for i = 1, 8 do ESP.Destroy(c[i]) end end
  ESP.Corners[key] = nil
  ESP.Destroy(ESP.HealthBg[key])
  ESP.HealthBg[key] = nil
  ESP.Destroy(ESP.HealthFill[key])
  ESP.HealthFill[key] = nil
  local m = ESP.Marks[key]
  if m then for i = 1, 4 do ESP.Destroy(m[i]) end end
  ESP.Marks[key] = nil
  ESP.Destroy(ESP.Lines[key])
  ESP.Lines[key] = nil
  ESP.Destroy(ESP.Infos[key])
  ESP.Infos[key] = nil
  ESP.VisCache[key] = nil
end

function ESP.ResetWidgets()
  for _, d in pairs(ESP.Lines) do ESP.Destroy(d) end
  for _, t in pairs(ESP.Corners) do for _, d in pairs(t) do ESP.Destroy(d) end end
  for _, d in pairs(ESP.HealthBg) do ESP.Destroy(d) end
  for _, d in pairs(ESP.HealthFill) do ESP.Destroy(d) end
  for _, t in pairs(ESP.Marks) do for _, d in pairs(t) do ESP.Destroy(d) end end
  for _, d in pairs(ESP.Infos) do ESP.Destroy(d) end
  ESP.Lines = {}
  ESP.Corners = {}
  ESP.HealthBg = {}
  ESP.HealthFill = {}
  ESP.Marks = {}
  ESP.Infos = {}
  ESP.VisCache = {}
  if ESP.Counter then ESP.Destroy(ESP.Counter) end
  ESP.Counter = nil
  ESP.Canvas = nil
  ESP.EnemyCache = {}
end

function ESP.Scan()
  local pc = ESP.GetController()
  local me = ESP.GetLocalCharacter()
  if not pc or not me then ESP.EnemyCache = {} return pc, 0, 0 end
  local myLoc = ESP.ActorLocation(me)
  if not myLoc then ESP.EnemyCache = {} return pc, 0, 0 end
  local myTeam = ESP.GetTeamID(me)
  local list = {}
  local nReal, nBot = 0, 0
  local pawns = nil
  pcall(function() if Game and Game.GetAllPlayerPawns then pawns = Game:GetAllPlayerPawns() end end)
  if pawns then
    for _, ch in pairs(pawns) do
      if ESPValid(ch) and ch ~= me and ESP.IsAlive(ch) then
        local team = ESP.GetTeamID(ch)
        if myTeam == nil or team == nil or tostring(team) ~= tostring(myTeam) then
          local loc = ESP.ActorLocation(ch)
          local dm = ESP.DistMeters(myLoc, loc)
          if dm * 100.0 <= (CFG.MaxDistance or 40000) then
            local isBot = ESP.IsBot(ch)
            if isBot then nBot = nBot + 1 else nReal = nReal + 1 end
            list[#list + 1] = { Character = ch, Key = ESP.GetPlayerKey(ch),
                                IsBot = isBot, Distance = dm }
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return (a.Distance or 99999) < (b.Distance or 99999) end)
  local trimmed = {}
  local maxR = CFG.MaxTracked or 16
  for i, it in ipairs(list) do
    if i > maxR then break end
    trimmed[#trimmed + 1] = it
  end
  ESP.EnemyCache = trimmed
  return pc, nReal, nBot
end
--// SRC HUB
function ESP.Update()
  if not ESP_Enabled then ESP.ResetWidgets() return end
  local world = ESP.World()
  if world ~= ESP.LastWorld then
    ESP.ResetWidgets()
    ESP.LastWorld = world
    ESP.LastScan = -999.0
    ESP.LastTransform = -999.0
  end
  local canvas = ESP.GetCanvas()
  if not canvas then return end
  local now = ESP.Now()
  local pc = ESP.GetController()
  if (now - ESP.LastScan) >= (ESP.ScanInterval or 0.35) then
    local r, b
    pc, r, b = ESP.Scan()
    ESP.LastScan = now
    ESP.RealCount, ESP.BotCount = r or 0, b or 0
  end
  pc = pc or ESP.GetController()
  if not pc then return end
  if (now - (ESP.LastTransform or -999.0)) >= (ESP.TransformInterval or 0.50) then
    ESP.UpdateCanvasTransform(pc)
    ESP.LastTransform = now
  end
  local vw, vh = ESP.Viewport(pc)
  -- viewport hysteresis: 2px se kam farq ignore (flicker fix)
  local hyst = CFG.SizeHyst or 2.0
  if math.abs(vw - (ESP.ViewW or 0)) > hyst or math.abs(vh - (ESP.ViewH or 0)) > hyst then
    ESP.ViewW, ESP.ViewH = vw, vh
  else
    vw, vh = ESP.ViewW, ESP.ViewH
  end
  local origin = ESP.UpdateCounter(ESP.RealCount or 0, ESP.BotCount or 0, pc, vw)
  if not origin then return end
  local camLoc = ESP.GetCamLoc(pc)

  local active = {}
  for _, item in ipairs(ESP.EnemyCache) do
    local c = item.Character
    local key = item.Key
    if ESPValid(c) and ESP.IsAlive(c) then
      local head, feet = ESP.GetHeadFeet(c)
      if head and feet then
        local headS, headPix = ESP.Project(pc, head)
        local feetS, feetPix = ESP.Project(pc, feet)
        if headS and feetS and headPix and feetPix then
          local m = CFG.ScreenMargin or 220
          local on = headPix.X > -m and headPix.X < vw + m
            and headPix.Y > -m and headPix.Y < vh + m
            and feetPix.X > -m and feetPix.X < vw + m
            and feetPix.Y > -m and feetPix.Y < vh + m
          if on then
            local H = feetS.Y - headS.Y
            -- sanity: ulti box / bahut badi box = garbage projection, hide
            if H >= (CFG.BoxMinHeight or 14) and H <= vh * 1.5 then
              active[key] = true
              local W = H * (CFG.BoxWidthFactor or 0.62)
              W = math.max(CFG.BoxMinWidth or 22, math.min(CFG.BoxMaxWidth or 320, W))
              local padT = H * (CFG.HeadExtra or 0)
              local padB = H * (CFG.FootExtra or 0)
              local cx = (headS.X + feetS.X) * 0.5
              local L = cx - W * 0.5
              local R = cx + W * 0.5
              local T = headS.Y - padT
              local B = feetS.Y + padB

              -- 1) white corners (8 segments)
              local arm = math.min(R - L, B - T) * (CFG.CornerLen or 0.28)
              arm = math.max(CFG.CornerMin or 6, math.min(CFG.CornerMax or 28, arm))
              local th = CFG.CornerThickness or 2.2
              ESP.DrawLine(ESP.EnsureCorner(key, 1, C_WHITE), L, T, L + arm, T, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 2, C_WHITE), L, T, L, T + arm, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 3, C_WHITE), R, T, R - arm, T, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 4, C_WHITE), R, T, R, T + arm, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 5, C_WHITE), L, B, L + arm, B, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 6, C_WHITE), L, B, L, B - arm, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 7, C_WHITE), R, B, R - arm, B, th)
              ESP.DrawLine(ESP.EnsureCorner(key, 8, C_WHITE), R, B, R, B - arm, th)

              -- 2) health bar (left): bg full + fill pct + HealthColor
              local pct = ESP.GetHealthPct(c)
              local sbX = L - (CFG.SideBarGap or 5.0)
              ESP.UpdateHealthBar(key, pct, sbX, T, B - T)

              -- 3) yellow double chevron above head
              local ccx = (L + R) * 0.5
              local mw = CFG.MarkW or 15.0
              local mh = CFG.MarkH or 10.0
              local gv = CFG.MarkGapV or 6.0
              local gp = CFG.MarkGap or 8.0
              local mt = CFG.MarkThickness or 2.4
              local y2 = T - gp
              local y1 = y2 - mh - gv
              -- upper V
              ESP.DrawLine(ESP.EnsureMark(key, 1), ccx - mw, y1, ccx, y1 + mh, mt)
              ESP.DrawLine(ESP.EnsureMark(key, 2), ccx + mw, y1, ccx, y1 + mh, mt)
              -- lower V
              ESP.DrawLine(ESP.EnsureMark(key, 3), ccx - mw, y2 - mh, ccx, y2, mt)
              ESP.DrawLine(ESP.EnsureMark(key, 4), ccx + mw, y2 - mh, ccx, y2, mt)

              -- 4) green snap line top-center -> head
              ESP.DrawLine(ESP.EnsureSnap(key), origin.X, origin.Y, headS.X, headS.Y,
                           CFG.SnapThickness or 1.8)

              -- 5) bottom info: name / distance / Open-Close(visibility)
              local bVis = ESP.IsVisible(key, pc, camLoc, c)
              ESP.UpdateInfo(key, c, item.IsBot, item.Distance, bVis, cx, B)
            else
              ESP.HideTarget(key)
            end
          else
            ESP.HideTarget(key)
          end
        else
          ESP.HideTarget(key)
        end
      else
        ESP.HideTarget(key)
      end
    end
  end
  -- stale: jo is frame me nahi dikha usko hide; jo cache me bhi nahi usko release
  local seenCache = {}
  for _, it in ipairs(ESP.EnemyCache) do seenCache[it.Key] = true end
  local function stillActive(k)
    return active[k] == true
  end
  for k, _ in pairs(ESP.Lines) do if not stillActive(k) then ESP.HideTarget(k) end end
  for k, _ in pairs(ESP.Infos) do if not stillActive(k) then ESP.HideTarget(k) end end
  for k, _ in pairs(ESP.Corners) do
    if not stillActive(k) and not seenCache[k] then ESP.ReleaseTarget(k) end
  end
  for k, _ in pairs(ESP.HealthBg) do
    if not seenCache[k] and not stillActive(k) then ESP.ReleaseTarget(k) end
  end
end

-- Single driver: sirf ek repeating timer (lag/flicker fix).
-- Purana triple-driver (Tick loop + 2x AddGameTimer) hata diya.
function ESP.Tick()
  pcall(ESP.Update)
end

function ESP.AttachTimers()
  if not ESP.bActive then return end
  pcall(function()
    local pc = ESP.GetController()
    if ESPValid(pc) and pc.AddGameTimer then
      if ESP._TimerPC == pc and ESP._TimerHooked then return end
      ESP._TimerPC = pc
      ESP._TimerHooked = true
      -- Timer único; la actualización solo ocurre mientras el interruptor está activo.
      ESP._TimerId = pc:AddGameTimer(ESP.LightInterval or 0.033, true, function()
        if ESP.bActive then pcall(ESP.Tick) end
      end)
    else
      pcall(function()
        require("timer").SetGameTimer(1.0, false, function()
          if ESP.bActive then
            ESP._TimerHooked = false
            ESP.AttachTimers()
          end
        end)
      end)
    end
    pcall(function() require("timer").SetGameTimer(5.0, false, function() if ESP.bActive then ESP.AttachTimers() end end) end)
  end)
end

function ESP.Start()
  if ESP.bActive then return end
  ESP_Enabled = true
  ESP.bActive = true
  pcall(ESP.Update)
  ESP.AttachTimers()
end

function ESP.Stop()
  ESP_Enabled = false
  ESP.bActive = false
  if ESP._TimerPC and ESP._TimerId then
    pcall(function()
      if ESP._TimerPC.RemoveGameTimer then ESP._TimerPC:RemoveGameTimer(ESP._TimerId) end
    end)
  end
  ESP._TimerId = nil
  ESP._TimerHooked = false
  ESP._TimerPC = nil
  pcall(ESP.ResetWidgets)
end

_G.ESP = ESP
_G.PlayerMapMarker = ESP


-- ==================== END INTEGRATED FILE 1 ====================
-- ==============================================================================
-- ============================ BẮT ĐẦU FULL LOGIC MOD ==========================
-- ==============================================================================

-- [الكود الموجود مسبقاً في BRPlayerCharacterBase.lua يبقى كما هو]
-- ... (كل الكود الأصلي الخاص بك يبقى في مكانه) ...

-- ==============================================================================
-- ==================== نظام الترخيص والأكواد (VIP License) =====================
-- ==============================================================================
-- هذا القسم يضيف:
--   1. نظام تحقق من الأكواد (VIPLicenseCore)
--   2. واجهة تسجيل الدخول (LunarLoginRuntime)
--   3. حفظ/تحميل الكود تلقائياً
--   4. ربط مع الإعدادات الأصلية للعبة
-- ==============================================================================

local function _VIPLicense_Init()
    local licenseScope
    local VIPLicenseConfig = {
        game = 'BGMI',
        manualExpiry = nil,
        secret = 'Vm8Lk7Uj2JmsjCPVPVjrLa7zgfx3uz5E',
        validKeys = {
            "VIP-DEMO-0001",
            { key = "1M-KEY-PRO", expires = "2026-11-30 23:59:59" },
            { key = "2M-KEY-PRO2", expires = "2026-11-29 23:59:59" },
            -- أضف مفاتيحك هنا
        },
    }

    -- ============================================================================
    -- 1) VIPLicenseCore : خوارزمية MD5 + إدارة الجلسة + التحقق من الأكواد
    -- ============================================================================
    local VIPLicenseCore = (function()
        local Primitives = (function()
            local floor, abs, max = math.floor, math.abs, math.max
            local byte, char, format = string.byte, string.char, string.format
            local U32 = 4294967296
            local AND, XOR = {}, {}
            for a = 0, 15 do for b = 0, 15 do
                local av, bv, both, different, place = a, b, 0, 0, 1
                for _ = 1, 4 do
                    local x, y = av % 2, bv % 2
                    if x == 1 and y == 1 then both = both + place end
                    if x ~= y then different = different + place end
                    av, bv, place = floor(av / 2), floor(bv / 2), place * 2
                end
                AND[a * 16 + b], XOR[a * 16 + b] = both, different
            end end
            local function bitop(a, b, lookup)
                local value, place = 0, 1
                for _ = 1, 8 do
                    value = value + lookup[(a % 16) * 16 + b % 16] * place
                    a, b, place = floor(a / 16), floor(b / 16), place * 16
                end
                return value
            end
            local function band(a, b) return bitop(a, b, AND) end
            local function bxor(a, b) return bitop(a, b, XOR) end
            local function rol(value, amount)
                local divisor = 2 ^ (32 - amount)
                return (value % divisor) * 2 ^ amount + floor(value / divisor)
            end
            local function little32(value)
                return char(value % 256, floor(value / 256) % 256,
                    floor(value / 65536) % 256, floor(value / 16777216) % 256)
            end
            local K = {
                0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
                0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
                0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
                0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
                0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
                0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
                0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
                0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
            }
            local SHIFT = {7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21}
            local function md5_raw(input)
                assert(type(input) == "string", "MD5 input must be a string")
                local size = #input
                local message = input .. char(128) .. string.rep(char(0), (55 - size) % 64)
                    .. little32((size * 8) % U32) .. little32(floor(size / 536870912))
                local h0, h1, h2, h3 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
                local words = {}
                for offset = 1, #message, 64 do
                    for j = 0, 15 do
                        local a, b, c, d = byte(message, offset + j * 4, offset + j * 4 + 3)
                        words[j] = a + b * 256 + c * 65536 + d * 16777216
                    end
                    local a, b, c, d = h0, h1, h2, h3
                    for i = 0, 63 do
                        local f, g, shiftBase
                        if i < 16 then
                            f, g, shiftBase = band(b, c) + band(U32 - 1 - b, d), i, 0
                        elseif i < 32 then
                            f, g, shiftBase = band(d, b) + band(U32 - 1 - d, c), (5 * i + 1) % 16, 4
                        elseif i < 48 then
                            f, g, shiftBase = bxor(bxor(b, c), d), (3 * i + 5) % 16, 8
                        else
                            local bOrNotD = U32 - 1 - band(U32 - 1 - b, d)
                            f, g, shiftBase = bxor(c, bOrNotD), (7 * i) % 16, 12
                        end
                        local nextB = (b + rol((a + f + K[i + 1] + words[g]) % U32,
                            SHIFT[shiftBase + i % 4 + 1])) % U32
                        a, b, c, d = d, nextB, b, c
                    end
                    h0, h1, h2, h3 = (h0 + a) % U32, (h1 + b) % U32, (h2 + c) % U32, (h3 + d) % U32
                end
                return little32(h0) .. little32(h1) .. little32(h2) .. little32(h3)
            end
            local function hex(input)
                return (input:gsub(".", function(c) return format("%02x", byte(c)) end))
            end
            local function md5(input) return hex(md5_raw(input)) end
            local function form_encode(input)
                assert(type(input) == "string", "Form value must be a string")
                return (input:gsub("[^A-Za-z0-9%-%._~ ]", function(c)
                    return format("%%%02X", byte(c)) end):gsub(" ", "+"))
            end
            local function constant_time_equal(a, b)
                if type(a) ~= "string" or type(b) ~= "string" then return false end
                local difference = abs(#a - #b)
                for i = 1, max(#a, #b) do
                    difference = difference + abs((byte(a, i) or 0) - (byte(b, i) or 0))
                end
                return difference == 0
            end
            local function name_uuid(input)
                local digest = md5_raw(input)
                local h = hex(digest:sub(1,6) .. char(byte(digest,7) % 16 + 48)
                    .. digest:sub(8,8) .. char(byte(digest,9) % 64 + 128) .. digest:sub(10))
                return h:sub(1,8) .. "-" .. h:sub(9,12) .. "-" .. h:sub(13,16)
                    .. "-" .. h:sub(17,20) .. "-" .. h:sub(21,32)
            end
            return {md5 = md5, md5_raw = md5_raw, form_encode = form_encode,
                    constant_time_equal = constant_time_equal, name_uuid = name_uuid}
        end)()

        local SESSION_KEY = '__LunarLicenseSessionV7'
        local function loadSession()
            local t = rawget(_G, SESSION_KEY)
            if type(t) == 'table' and t.authorized == true and t.scope == licenseScope then return t end
        end
        local function saveSession(expiresAt)
            _G[SESSION_KEY] = {authorized = true, expiresAt = expiresAt, scope = licenseScope}
        end
        local function clearSession() _G[SESSION_KEY] = nil end

        local CreateLocalExpiry = function(cfg)
            local E = {}
            local expiredText = 'Mod expired. Contact VIP Server for renewal.'
            local tamperText  = "Don't be over smart"
            local blockedMessage, blockedPhase
            local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
            local function parse(text)
                if type(text) ~= 'string' then return nil end
                local y,m,d,h,n,s = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
                y,m,d,h,n,s = tonumber(y),tonumber(m),tonumber(d),tonumber(h),tonumber(n),tonumber(s)
                if not y or not m or not d or not h or not n or not s or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or n > 59 or s > 59 then return nil end
                local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
                local months = {31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
                if d < 1 or d > months[m] then return nil end
                local prior = y - 1
                local days = 365 * (y - 1970) + math.floor(prior / 4) - math.floor(1969 / 4)
                    - math.floor(prior / 100) + math.floor(1969 / 100)
                    + math.floor(prior / 400) - math.floor(1969 / 400)
                for i = 1, m - 1 do days = days + months[i] end
                return (days + d - 1) * 86400 + h * 3600 + n * 60 + s - 6 * 3600
            end
            local expiry = cfg.manualExpiry and parse(cfg.manualExpiry) or nil
            if cfg.manualExpiry and not expiry then
                blockedMessage, blockedPhase = 'Invalid local expiry date. Use YYYY-MM-DD HH:MM:SS.', 'error'
            end
            local function block(message, phase)
                if not blockedMessage then blockedMessage, blockedPhase = message, phase end
                return false, blockedMessage, blockedPhase
            end
            function E.Status() return not blockedMessage, blockedMessage, blockedPhase end
            function E.MarkTampered() return block(tamperText, 'tampered') end
            function E.GetExpiry() return expiry end
            function E.Accept(now, keyExpiry)
                if blockedMessage then return E.Status() end
                if not finite(now) or now < 0 then
                    return block('Clock verification unavailable.', 'error')
                end
                local effective = expiry
                if keyExpiry then
                    if not effective or keyExpiry < effective then effective = keyExpiry end
                end
                if effective and now >= effective then return false, expiredText, 'expired' end
                return true
            end
            function E.GetEffectiveExpiry(keyExpiry)
                local effective = expiry
                if keyExpiry then
                    if not effective or keyExpiry < effective then effective = keyExpiry end
                end
                return effective
            end
            function E.Parse(t) return parse(t) end
            return E
        end

        local CreateAuth = function(P, cfg, deps)
            local A = {}
            licenseScope = P.md5(cfg.game .. "\0" .. (cfg.secret or "") .. "\0offlinekeys")
            local phase, message = 'locked', 'Enter your key to sign in.'
            local allowed, generation = false, 0
            local expiresAt
            local startFn, stopFn, payloadStarted, restartRequired
            local localExpiry = deps.localExpiry
            do
                local stored = loadSession()
                if stored then
                    allowed = true; expiresAt = stored.expiresAt
                    phase, message = 'active', 'Session restored'
                end
            end
            if localExpiry then
                local ok, text, state = localExpiry.Status()
                if not ok then message, phase = text, state end
            end
            local function readClock()
                local ok, n = pcall(deps.clock)
                if ok and type(n) == 'number' and n == n and n >= 0 then return n end
            end
            local function notify(text, state)
                message, phase = text, state
                if type(deps.status) == 'function' then pcall(deps.status, text, state) end
            end
            local function stopPayload()
                if payloadStarted then
                    payloadStarted = false
                    local ok, accepted = pcall(stopFn)
                    if not ok or accepted == false then restartRequired = true end
                end
            end
            local function revoke(text, state)
                generation = generation + 1
                allowed, expiresAt = false, nil
                stopPayload()
                local localDenied = false
                if localExpiry then
                    local ok, localText, localPhase = localExpiry.Status()
                    if not ok then text, state, localDenied = localText, localPhase, true end
                end
                notify(restartRequired and not localDenied
                    and 'Restart required: payload cleanup failed.' or text, state or 'error')
            end
            local function startPayload()
                if payloadStarted or not startFn then return true end
                payloadStarted = true
                local before = generation
                local ok, accepted = pcall(startFn)
                if not ok or accepted == false then
                    restartRequired = true
                    revoke('Restart required: offline script startup failed.', 'error')
                    return false
                end
                return generation == before and allowed
            end

            local keyIndex = {}
            do
                local list = cfg.validKeys or {}
                for _, entry in ipairs(list) do
                    local k, exp
                    if type(entry) == "string" then
                        k = entry
                    elseif type(entry) == "table" and type(entry.key) == "string" then
                        k = entry.key
                        if entry.expires then
                            exp = localExpiry and localExpiry.Parse(entry.expires) or nil
                        end
                    end
                    if k and #k > 0 then
                        keyIndex[k] = {expires = exp}
                    end
                end
            end

            local function verifyKey(key)
                local entry = keyIndex[key]
                if not entry then return false, "Invalid key.", nil end
                return true, nil, entry.expires
            end

            local function begin(key)
                if restartRequired then return false end
                if localExpiry then
                    local ok, text, state = localExpiry.Status()
                    if not ok then revoke(text, state); return false end
                end
                if type(key) ~= 'string' then key = '' end
                key = key:match('^%s*(.-)%s*$')
                if #key == 0 or #key > 512 then
                    revoke('Enter a valid key.', 'denied'); return false
                end
                local now = readClock()
                if not now then
                    revoke('Phone clock unavailable. Please try again.', 'error'); return false
                end
                local okSerial, serial = pcall(deps.serial, key)
                if not okSerial or type(serial) ~= 'string' or #serial == 0 or #serial > 512 then
                    local failure = tostring(serial)
                    local text = 'Device identifier unavailable.'
                    if not okSerial and failure:find('DEVICE_CACHE_CONFLICT', 1, true) then
                        text = 'Saved device records conflict. Restore the registered device backup.'
                    elseif not okSerial and failure:find('DEVICE_CACHE_RECOVERY_REQUIRED', 1, true) then
                        text = 'Saved device data could not be recovered. Check storage or restore its backup.'
                    elseif not okSerial and failure:find('DEVICE_CACHE_SAVE_FAILED', 1, true) then
                        text = 'Device cache could not be saved. Check game storage access.'
                    end
                    revoke(text, 'error'); return false
                end
                generation = generation + 1
                notify('Verifying key...', 'pending')
                local okV, valid, reason, keyExpiry = pcall(verifyKey, key)
                if not okV then
                    revoke('Key verification failed.', 'error'); return false
                end
                if not valid then
                    revoke('Expired: ' .. tostring(reason), 'denied'); return false
                end
                if localExpiry then
                    local accepted, text, state = localExpiry.Accept(now, keyExpiry)
                    if not accepted then revoke(text, state); return false end
                end
                allowed = true
                expiresAt = localExpiry and localExpiry.GetEffectiveExpiry(keyExpiry) or keyExpiry
                saveSession(expiresAt)
                if not startPayload() then return false end
                notify('Login successful.', 'active')
                return true
            end

            function A.Login(key) if allowed then return false end; return begin(key) end
            function A.Tick() end
            function A.IsAuthorized()
                if allowed and not restartRequired then return true end
                local stored = loadSession()
                if stored and not restartRequired then
                    allowed = true; expiresAt = stored.expiresAt; return true
                end
                return false
            end
            function A.Logout() clearSession(); revoke('Expired: signed out.', 'locked') end
            function A.FailClosed(text, requiresRestart)
                if requiresRestart == true then restartRequired = true end
                revoke(text or 'Access unavailable.', 'error')
            end
            function A.ReportClockTampering()
                if localExpiry then localExpiry.MarkTampered() end
                revoke("Don't be over smart", 'tampered')
            end
            function A.Bind(onStart, onStop)
                if type(onStart) ~= 'function' or type(onStop) ~= 'function' then
                    return false, 'START_AND_STOP_REQUIRED'
                end
                if startFn and (startFn ~= onStart or stopFn ~= onStop) then return false, 'ALREADY_BOUND' end
                startFn, stopFn = onStart, onStop
                if A.IsAuthorized() then return startPayload() end
                return true
            end
            function A.Unbind()
                revoke('Offline script disconnected.', 'locked')
                startFn, stopFn = nil, nil
            end
            function A.GetRemainingSeconds() return nil end
            function A.GetState()
                local authorized = A.IsAuthorized()
                return {
                    phase = phase, message = message, authorized = authorized,
                    sessionAuthorized = authorized, expiresAt = expiresAt,
                    accessPolicy = "offline_whitelist", expiryCheckPolicy = "login_only",
                    periodicRecheck = false, pending = false,
                    linked = startFn ~= nil, restartRequired = restartRequired == true,
                }
            end
            return A
        end

        local Core = {Primitives = Primitives, createExpiry = CreateLocalExpiry}
        function Core.new(config, dependencies)
            assert(type(config) == 'table' and type(dependencies) == 'table',
                'License configuration and dependencies required')
            local deps = {}
            for key, value in pairs(dependencies) do deps[key] = value end
            if deps.localExpiry == nil then deps.localExpiry = CreateLocalExpiry(config) end
            return CreateAuth(Primitives, config, deps)
        end
        return Core
    end)()

    -- ============================================================================
    -- 2) UI.Build : واجهة تسجيل الدخول (نافذة الكود)
    -- ============================================================================
    local UI = {Version = "LunarUI.V10.Glass.OfflineKeys.1"}
    local function member(o, k)
        if o == nil then return nil end
        local ok, v = pcall(function() return o[k] end); if ok then return v end
    end
    local function valid(o)
        if o == nil then return false end
        local ok, v = pcall(slua.isValid, o); return ok and v == true
    end
    local vectorClass = rawget(_G, "FVector2D") or import("Vector2D")
    local colorClass = rawget(_G, "FLinearColor") or import("LinearColor")
    local function vector(x, y) return vectorClass(x, y) end
    local function color(r, g, b, a)
        local function linear(v) v = v / 255; if v <= 0.04045 then return v / 12.92 end; return ((v + 0.055) / 1.055) ^ 2.4 end
        return colorClass(linear(r), linear(g), linear(b), a or 1)
    end
    local function visibility(w, v)
        local fn = member(w, "SetWidgetVisibility") or member(w, "SetVisibility")
        assert(type(fn) == "function", "UI_VISIBILITY_UNAVAILABLE"); fn(w, v)
    end
    local function parent()
        local ok, t = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if not ok or type(member(t, "GetMainControlBaseUI")) ~= "function" then return end
        local found, root = pcall(t.GetMainControlBaseUI); if not found or not valid(root) then return end
        local p = member(root, "CanvasPanel_0"); if not valid(p) then p = member(root, "CanvasPanel_42") end
        if valid(p) then return p end
    end
    local function destroy(d)
        if not d then return end
        d.Visible = false
        if d.Event and d.Handle ~= nil then pcall(function() d.Event:Remove(d.Handle) end) end
        if valid(d.Container) then pcall(function() d.Container:RemoveFromParent() end) end
        d.Submit = nil; d.Event = nil; d.Handle = nil; d.Container = nil; d.Parent = nil
        d.Input = nil; d.Button = nil; d.Status = nil; d.Title = nil; d.Detail = nil; d.Hint = nil; d.Design = nil; d.Cache = nil
    end

    function UI.Build(kind, key, status, submit)
        local p = parent(); if not p then return nil, "UI_NOT_READY" end
        local enums = UEnums.ESlateVisibility
        local passive = enums.SelfHitTestInvisible
        if enums.Visible == nil or passive == nil then return nil, "UI_ENUM_UNAVAILABLE" end
        local welcome = kind == "welcome"
        local W, H = welcome and 600 or 500, welcome and 276 or 248
        local scale = welcome and 0.8 or 1
        pcall(function()
            local v = p:GetCachedGeometry():GetLocalSize()
            if v.X > 24 and v.Y > 24 then scale = math.min(scale, (v.X - 24) / W, (v.Y - 24) / H) end
        end)
        local d = {Parent = p, Visible = false, Submit = submit, Scale = scale}
        local ok, buildError = pcall(function()
            local function make(class, outer)
                local w = CGame:NewObjectFromPath("/Script/UMG." .. class, outer)
                assert(valid(w), "UI_WIDGET_UNAVAILABLE"); return w
            end
            d.Container = make("CanvasPanel", p)
            local design = make("CanvasPanel", d.Container); d.Design = design
            local artRoot = design
            local canCache, cache = pcall(make, "InvalidationBox", d.Container)
            if canCache and valid(cache) and type(member(cache, "SetCanCache")) == "function" then
                local attached = pcall(function() cache:AddChild(design); cache:SetCanCache(true); visibility(cache, passive) end)
                if attached then artRoot = cache; d.Cache = cache end
            end
            local artSlot = d.Container:AddChildToCanvas(artRoot)
            artSlot:SetAutoSize(false); artSlot:SetPosition(vector(0, 0)); artSlot:SetSize(vector(W, H)); artSlot:SetZOrder(1)
            visibility(design, passive)
            local function add(w, x, y, ww, hh, z, dynamic)
                local slot = (dynamic and d.Container or design):AddChildToCanvas(w)
                slot:SetAutoSize(false); slot:SetPosition(vector(x, y)); slot:SetSize(vector(ww, hh)); slot:SetZOrder(z)
                return slot
            end
            local artwork = {}
            local function drawRect(x, y, ww, hh, c, z, opacity)
                local w = make("Border", d.Container)
                w:SetBrushColor(colorClass(c.R, c.G, c.B, opacity or .5)); visibility(w, passive)
                add(w, x, y, ww, hh, z); return w
            end
            local function rect(x, y, ww, hh, c, z, opacity)
                artwork[#artwork+1] = {X = x, Y = y, W = ww, H = hh, C = c, Z = z, A = opacity or .5, Order = #artwork+1}
            end
            local function renderArt()
                table.sort(artwork, function(a, b)
                    if a.Z == b.Z then return a.Order > b.Order end
                    return a.Z > b.Z
                end)
                local covered = {}
                local function put(out, x, y, w, h)
                    if w > .00001 and h > .00001 then out[#out+1] = {X = x, Y = y, W = w, H = h} end
                end
                for _, shape in ipairs(artwork) do
                    local pieces = {{X = shape.X, Y = shape.Y, W = shape.W, H = shape.H}}
                    for _, cover in ipairs(covered) do
                        local nextPieces = {}
                        for _, piece in ipairs(pieces) do
                            local x1 = math.max(piece.X, cover.X); local y1 = math.max(piece.Y, cover.Y)
                            local x2 = math.min(piece.X + piece.W, cover.X + cover.W)
                            local y2 = math.min(piece.Y + piece.H, cover.Y + cover.H)
                            if x2 <= x1 or y2 <= y1 then nextPieces[#nextPieces+1] = piece
                            else
                                put(nextPieces, piece.X, piece.Y, piece.W, y1 - piece.Y)
                                put(nextPieces, piece.X, y2, piece.W, piece.Y + piece.H - y2)
                                put(nextPieces, piece.X, y1, x1 - piece.X, y2 - y1)
                                put(nextPieces, x2, y1, piece.X + piece.W - x2, y2 - y1)
                            end
                        end
                        pieces = nextPieces; if #pieces == 0 then break end
                    end
                    local changed = true
                    while changed do
                        changed = false
                        for i = 1, #pieces do
                            local a = pieces[i]
                            for j = i + 1, #pieces do
                                local b = pieces[j]
                                local vertical = math.abs(a.X - b.X) < .00001 and math.abs(a.W - b.W) < .00001
                                    and (math.abs(a.Y + a.H - b.Y) < .00001 or math.abs(b.Y + b.H - a.Y) < .00001)
                                local horizontal = math.abs(a.Y - b.Y) < .00001 and math.abs(a.H - b.H) < .00001
                                    and (math.abs(a.X + a.W - b.X) < .00001 or math.abs(b.X + b.W - a.X) < .00001)
                                if vertical or horizontal then
                                    local x, y = math.min(a.X, b.X), math.min(a.Y, b.Y)
                                    a.W = math.max(a.X + a.W, b.X + b.W) - x
                                    a.H = math.max(a.Y + a.H, b.Y + b.H) - y; a.X = x; a.Y = y
                                    table.remove(pieces, j); changed = true; break
                                end
                            end
                            if changed then break end
                        end
                    end
                    for _, piece in ipairs(pieces) do
                        drawRect(piece.X, piece.Y, piece.W, piece.H, shape.C, shape.Z, shape.A)
                    end
                    covered[#covered+1] = shape
                end
                artwork = nil
            end
            local function sample(stops, t, opacity)
                t = math.max(0, math.min(1, t)); local a, b, u
                if t <= .5 then a, b, u = stops[1], stops[2], t * 2 else a, b, u = stops[2], stops[3], (t - .5) * 2 end
                return color(a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u, opacity)
            end
            local function panel(x, y, ww, hh, cut, stops, z, columns, opacity)
                columns = math.min(columns, 12)
                for i = 0, columns - 1 do
                    local a = ww * i / columns; local b = ww * (i + 1) / columns
                    local inset = math.max(0, cut - math.min(a, ww - b))
                    rect(x + a, y + inset, b - a, hh - inset * 2, sample(stops, (i + .5) / columns, opacity), z, opacity)
                end
            end
            local function rail(x, y, ww, hh, stops, z, columns)
                columns = math.min(columns, 12)
                for i = 0, columns - 1 do
                    rect(x + ww * i / columns, y, ww / columns, hh, sample(stops, (i + .5) / columns), z)
                end
            end
            local function line(ax, ay, bx, by, th, c, z)
                local dx, dy = bx - ax, by - ay
                local len = math.sqrt(dx * dx + dy * dy)
                if len <= 0 then return end
                local angle
                if dx == 0 then angle = dy >= 0 and 90 or -90
                else angle = math.atan(dy / dx) * 180 / math.pi; if dx < 0 then angle = angle + 180 end end
                local w = drawRect((ax + bx - len) / 2, (ay + by - th) / 2, len, th, c, z, z >= 7 and 1 or .5)
                w:SetRenderTransformPivot(vector(.5, .5)); w:SetRenderAngle(angle)
            end
            local slate = import("SlateColor")
            local fontObject
            if slua and type(slua.loadObject) == "function" then
                local loaded, obj = pcall(slua.loadObject, "/Engine/EngineFonts/Roboto.Roboto")
                if loaded and valid(obj) then fontObject = obj end
            end
            local function style(w, size, c, bold)
                local font = member(w, "Font")
                if font then
                    if type(font) == "table" then local copy = {}; for k, v in pairs(font) do copy[k] = v end; font = copy end
                    font.Size = size
                    if fontObject then font.FontObject = fontObject; font.TypefaceFontName = bold and "Bold" or "Regular" end
                    if font.OutlineSettings then
                        local outline = font.OutlineSettings
                        if type(outline) == "table" then local copy = {}; for k, v in pairs(outline) do copy[k] = v end; outline = copy end
                        outline.OutlineSize = 0; font.OutlineSettings = outline
                    end
                    w:SetFont(font)
                end
                w:SetColorAndOpacity(slate(c))
                pcall(function() w:SetShadowOffset(vector(0, 0)); w:SetShadowColorAndOpacity(color(0, 0, 0, 0)) end)
                pcall(function() w:SetAutoWrapText(true) end)
            end
            local function text(value, x, y, ww, hh, size, c, z, bold, center, dynamic)
                local w = make("TextBlock", d.Container); w:SetText(value); style(w, size, c, bold)
                visibility(w, passive); add(w, x, y, ww, hh, z, dynamic)
                if center then pcall(function() w:SetJustification(1) end) end
                return w
            end
            local frame = {{28, 220, 255}, {92, 123, 255}, {155, 105, 255}}
            local bright = {{188, 250, 255}, {202, 215, 255}, {226, 198, 255}}
            local edge = {{12, 72, 104}, {37, 52, 112}, {69, 38, 112}}
            local body = {{8, 22, 39}, {13, 25, 49}, {17, 22, 45}}
            local header = {{11, 34, 58}, {20, 35, 70}, {36, 29, 67}}
            local gold = {{16, 105, 143}, {55, 104, 213}, {125, 73, 198}}
            local white = color(239, 249, 255)
            local forest = color(151, 232, 255)
            local burgundy = color(182, 215, 255)
            panel(6, 6, W - 12, H - 12, 10, body, 2, 24, .86)
            rail(13, 0, W - 26, 6, frame, 3, 24)
            rail(13, H - 6, W - 26, 6, frame, 3, 24)
            rect(0, 13, 6, H - 26, color(28, 220, 255), 3)
            rect(W - 6, 13, 6, H - 26, color(155, 105, 255), 3)
            rail(13, 1, W - 26, 1.5, bright, 3, 24)
            rail(13, H - 3, W - 26, 1.5, edge, 3, 24)
            rect(1, 13, 1.5, H - 26, color(125, 235, 255), 3)
            rect(W - 3, 13, 1.5, H - 26, color(190, 165, 255), 3)
            for _, s in ipairs({{1, 13, 13, 1}, {1, H - 13, 13, H - 1}}) do line(s[1], s[2], s[3], s[4], 2, color(188, 250, 255), 3) end
            for _, s in ipairs({{W - 13, 1, W - 1, 13}, {W - 13, H - 1, W - 1, H - 13}}) do line(s[1], s[2], s[3], s[4], 2, color(226, 198, 255), 3) end
            panel(10, 10, W - 20, 65, 16, gold, 4, 24, .68)
            panel(13, 13, W - 26, 59, 14, header, 5, 32, .94)
            rail(24, 17, W - 48, 1.2, bright, 6, 24)
            if welcome then
                d.Title = text("VIP ACCESS // WELCOME", 24, 22, W - 48, 42, 19, white, 7, true, true)
                local pw = math.min(340, W - 72); local px = (W - pw) / 2
                panel(px, 99, pw, 51, 12, gold, 4, 16, .82)
                panel(px + 3, 102, pw - 6, 45, 10, {{12, 82, 126}, {35, 106, 201}, {83, 63, 158}}, 5, 20, .96)
                d.Detail = text("Kill limit 8-10", px + 16, 109, pw - 32, 34, 23, white, 7, true, true)
                d.Hint = text("PREMIUM ACCESS • READY WHEN YOU ARE", 30, 165, W - 60, 32, 17, forest, 7, true, true)
            else
                d.Title = text("VIP GLASS", 22, 15, W - 44, 31, 24, white, 7, true, true)
                text("SECURE KEY AUTHENTICATION", 22, 45, W - 44, 21, 12, white, 7, true, true)
                line(W / 2 - 118, 56, W / 2 - 47, 56, 1, color(251, 244, 228), 7)
                line(W / 2 + 47, 56, W / 2 + 118, 56, 1, color(251, 244, 228), 7)
                text("LICENSE KEY", 22, 82, W - 44, 20, 13, burgundy, 7, true, false)
                rail(27, 104, W - 54, 2, gold, 4, 24)
                rail(27, 143, W - 54, 2, gold, 4, 24)
                rect(20, 111, 2, 27, color(188, 108, 59), 4)
                rect(W - 22, 111, 2, 27, color(114, 179, 105), 4)
                line(20, 111, 27, 104, 2, color(242, 219, 164), 4)
                line(W - 27, 104, W - 20, 111, 2, color(242, 219, 164), 4)
                line(20, 138, 27, 145, 2, color(242, 219, 164), 4)
                line(W - 27, 145, W - 20, 138, 2, color(242, 219, 164), 4)
                d.Input = make("EditableTextBox", d.Container)
                d.Input:SetText(key or "")
                local fg = forest; local bg = color(255, 244, 216, 0)
                local inputStyle = member(d.Input, "WidgetStyle")
                if inputStyle then
                    if type(inputStyle) == "table" then local copy = {}; for k, v in pairs(inputStyle) do copy[k] = v end; inputStyle = copy end
                    local inputFont = member(inputStyle, "Font")
                    if inputFont then
                        if type(inputFont) == "table" then local copy = {}; for k, v in pairs(inputFont) do copy[k] = v end; inputFont = copy end
                        inputFont.Size = 17
                        if fontObject then inputFont.FontObject = fontObject; inputFont.TypefaceFontName = "Regular" end
                        inputStyle.Font = inputFont
                    end
                    inputStyle.ForegroundColor = slate(fg); inputStyle.ReadOnlyForegroundColor = slate(fg)
                    for _, name in ipairs({"BackgroundImageNormal", "BackgroundImageHovered", "BackgroundImageFocused", "BackgroundImageReadOnly"}) do
                        local brush = member(inputStyle, name)
                        if brush then
                            if type(brush) == "table" then local copy = {}; for k, v in pairs(brush) do copy[k] = v end; brush = copy end
                            brush.TintColor = slate(bg); inputStyle[name] = brush
                        end
                    end
                    d.Input.WidgetStyle = inputStyle
                else
                    local inputFont = member(d.Input, "Font")
                    if inputFont then
                        if type(inputFont) == "table" then local copy = {}; for k, v in pairs(inputFont) do copy[k] = v end; inputFont = copy end
                        inputFont.Size = 17; d.Input.Font = inputFont
                    end
                    d.Input.ForegroundColor = fg; d.Input.BackgroundColor = bg
                end
                local setForeground = member(d.Input, "SetForegroundColor")
                if type(setForeground) == "function" then setForeground(d.Input, fg) end
                pcall(function() d.Input:SetHintText("Enter your key") end)
                visibility(d.Input, enums.Visible); add(d.Input, 23, 107, W - 46, 35, 8, true)
                d.Hint = text("ENCRYPTED LOCAL KEY STORAGE", 22, 149, W - 44, 19, 11, burgundy, 7, false, false)
                d.Status = text(status or "Enter your key", 22, 170, W - 44, 23, 11, burgundy, 8, false, false, true)
            end
            local button = make("Button", d.Container); d.Button = button
            local by = welcome and 212 or 201; local bh = welcome and 42 or 34
            local bw = welcome and 202 or 190; local bx = (W - bw) / 2
            panel(bx - 4, by - 3, bw + 8, bh + 6, 9, gold, 4, 16, .82)
            panel(bx, by, bw, bh, 8, {{10, 137, 183}, {39, 121, 229}, {100, 77, 201}}, 5, 16, .98)
            pcall(function() button:SetBackgroundColor(color(255, 255, 255, 0)) end)
            visibility(button, enums.Visible)
            local label = make("TextBlock", button); label:SetText(welcome and "CONTINUE" or "UNLOCK ACCESS"); style(label, 17, white, true); visibility(label, passive)
            local labelSlot = button:AddChild(label)
            pcall(function() labelSlot:SetHorizontalAlignment(2); labelSlot:SetVerticalAlignment(2) end)
            add(button, bx, by, bw, bh, 9, true)
            d.Event = button.OnClicked
            d.Handle = d.Event:Add(function()
                if not d.Visible or d.Busy then return end
                if welcome then
                    destroy(d); d.Dismissed = true
                    local l = _G.LunarLoginRuntime; if l and l.WelcomeUI == d then l.WelcomeUI = nil end
                    return
                end
                local okRead, k = pcall(function() return d.Input:GetText() end)
                if not okRead or type(k) ~= "string" then return end
                k = k:match("^%s*(.-)%s*$")
                if #k == 0 or #k > 512 then d.Status:SetText("Enter a valid key"); return end
                if d.Submit then d.Submit(k) end
            end)
            renderArt()
            local slot = p:AddChildToCanvas(d.Container); slot:SetAutoSize(false); slot:SetSize(vector(W, H)); slot:SetZOrder(9200)
            local anchors = slot:GetAnchors(); anchors.Minimum = vector(.5, .5); anchors.Maximum = vector(.5, .5)
            slot:SetAnchors(anchors); slot:SetAlignment(vector(.5, .5)); slot:SetPosition(vector(0, 0))
            d.Container:SetRenderTransformPivot(vector(.5, .5)); d.Container:SetRenderScale(vector(scale, scale))
            visibility(d.Container, passive)
        end)
        if not ok then UI.LastBuildError = tostring(buildError); destroy(d); return nil, "UI_BUILD_UNAVAILABLE" end
        UI.LastBuildError = nil
        d.Visible = true; return d
    end
    _G.LunarUIAssetCache = nil

    -- ============================================================================
    -- 3) إنشاء LunarLoginRuntime : الحالة الرئيسية لتسجيل الدخول
    -- ============================================================================
    local existing = _G.LunarLoginRuntime
    if existing and existing.UIFactory and existing.UIFactory.Version ~= UI.Version
        and existing.Scope == VIPLicenseCore.Primitives.md5(VIPLicenseConfig.game .. "\0" .. (VIPLicenseConfig.secret or "") .. "\0offlinekeys") then
        local visibleWelcome = existing.WelcomeUI and existing.WelcomeUI.Visible
        if existing.DestroyUI then existing.DestroyUI() end
        existing.UIFactory.Build = UI.Build; existing.UIFactory.Version = UI.Version
        if visibleWelcome then existing.WelcomeShown = false end
        existing.NeedsUpdate = true
    end

    local function hex(s) return (s:gsub('.', function(c) return string.format('%02x', string.byte(c)) end)) end
    local function unhex(s)
        if type(s) ~= "string" or #s > 1024 or #s % 2 ~= 0 or s:find('[^%x]') then return nil end
        return (s:gsub('..', function(v) return string.char(tonumber(v, 16)) end))
    end

    local current = _G.LunarLoginRuntime
    local expectedScope = VIPLicenseCore.Primitives.md5(VIPLicenseConfig.game .. "\0" .. (VIPLicenseConfig.secret or "") .. "\0offlinekeys")
    if not current or current.Scope ~= expectedScope then
        if current and current.DestroyUI then current.DestroyUI() end
        local L = {Authorized = false, Pending = false, NeedsUpdate = true, WelcomeShown = false,
            Key = "", Seed = "", Scope = expectedScope, StorageVersion = 1, Status = "Enter your key", Diagnostics = {DeviceReads = 0}}
        _G.LunarLoginRuntime = L
        L.UIFactory = UI
        -- مسارات حفظ الكود
        local paths = {}
        local basePaths = {
            "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "Documents/ShadowTrackerExtra/Saved/SaveGames/",
            "ShadowTrackerExtra/Saved/SaveGames/",
        }
        for _, base in ipairs(basePaths) do
            table.insert(paths, base .. "VIP_SERVER_LOGIN_V7_settings.lua")
        end
        -- إضافة مسارات ios
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/SaveGames/VIP_SERVER_LOGIN_V7_settings.lua")
            end
        end

        local function identityPath(path)
            local changed, count = path:gsub("VIP_SERVER_LOGIN_V7_settings%.lua$", "VIP_SERVER_DEVICE_V1_settings.lua")
            if count > 0 then return changed end
            return path .. ".device"
        end
        local function plainKeyPath(base)
            local prefix = base:match("^(.*[/\\])[^/\\]+$") or ""
            return prefix .. "VIP_SERVER_PLAINKEY_V1_settings.lua"
        end
        local function digest(key, seed)
            return VIPLicenseCore.Primitives.md5("LUNAR-DEVICE-1\0" .. L.Scope .. "\0" .. key .. "\0" .. seed)
        end
        local function readRecord(path, identity)
            if not (io and type(io.open) == "function") then return nil, "unreadable" end
            local ok, file, reason, code = pcall(io.open, path, "r")
            if not ok then return nil, "unreadable" end
            if not file then
                local text = type(reason) == "string" and reason:lower() or ""
                if reason == nil or code == 2 or text:find("no such file", 1, true)
                    or text:find("not found", 1, true) or text:find("does not exist", 1, true) then
                    return nil, "missing"
                end
                return nil, "unreadable"
            end
            local good, data = pcall(function() return file:read(4097) end)
            pcall(function() file:close() end)
            if not good or type(data) ~= "string" then return nil, "unreadable" end
            if #data > 4096 then return nil, "invalid" end
            local scope = data:match('%f[%w_]Scope%s*=%s*"([%x]+)"')
            if scope and scope ~= L.Scope then return nil, "other_scope" end
            if scope ~= L.Scope then return nil, "invalid" end
            local key = unhex(data:match('%f[%w_]KeyHex%s*=%s*"([^"]*)"'))
            local seed = unhex(data:match('%f[%w_]SeedHex%s*=%s*"([^"]*)"'))
            if key == nil or seed == nil or #seed == 0 or #seed > 512 then return nil, "invalid" end
            local check = data:match('%f[%w_]Check%s*=%s*"([%x]+)"')
            local version = data:match('%f[%w_]Version%s*=%s*(%d+)')
            if identity or check or version then
                if version ~= "1" or check ~= digest(key, seed) then return nil, "invalid" end
            end
            return {Key = key, Seed = seed, Path = path, Identity = identity, Checked = version == "1"}, "valid"
        end
        local function candidates()
            local list, seen = {}, {}
            local function add(path)
                if type(path) == "string" and not seen[path] then seen[path] = true; list[#list+1] = path end
            end
            add(L.Path); add(L.PreferredPath)
            for _, path in ipairs(paths) do add(path) end
            return list
        end
        local function recover()
            if L.IdentityPinned then return true end
            local identities, legacy, issues = {}, {}, {}
            local function collect(base, path, identity)
                local record, state = readRecord(path, identity)
                if record then
                    record.Base = base
                    local list = identity and identities or legacy; list[#list+1] = record
                elseif state == "invalid" or (state == "unreadable" and base == L.PreferredPath) then
                    issues[#issues+1] = state
                end
            end
            for _, base in ipairs(candidates()) do
                local device = identityPath(base)
                collect(base, device, true); collect(base, device .. ".bak", true)
                collect(base, base, false); collect(base, base .. ".bak", false)
            end
            local list = #identities > 0 and identities or legacy
            local first = list[1]
            if first then
                for _, record in ipairs(list) do
                    if record.Seed ~= first.Seed then
                        L.IdentityError = "DEVICE_CACHE_CONFLICT"; L.Diagnostics.Identity = "conflict"; return false
                    end
                end
                L.Seed = first.Seed; L.Key = first.Key; L.Path = first.Base
                if L.Key == "" then
                    for _, record in ipairs(list) do
                        if record.Key ~= "" then L.Key = record.Key; break end
                    end
                end
                if L.Key == "" then
                    for _, record in ipairs(legacy) do
                        if record.Seed == L.Seed and record.Key ~= "" then L.Key = record.Key; break end
                    end
                end
                L.IdentityPinned = true; L.IdentityPersisted = true; L.HasIdentityRecord = first.Identity
                L.IdentityError = nil; L.Dirty = true
                L.Diagnostics.Identity = first.Identity and "restored" or "legacy_migration"
                return true
            end
            if #issues > 0 then
                L.IdentityError = "DEVICE_CACHE_RECOVERY_REQUIRED"; L.Diagnostics.Identity = "recovery_required"; return false
            end
            L.IdentityError = nil; L.Diagnostics.Identity = "new_install"; return true
        end
        local function payload(key, seed)
            return 'return { Version = 1, Scope = "' .. L.Scope .. '", KeyHex = "' .. hex(key)
                .. '", SeedHex = "' .. hex(seed) .. '", Check = "' .. digest(key, seed) .. '" }'
        end
        local function plainPayload(key)
            return 'return { Key = "' .. key:gsub("\\", "\\\\"):gsub('"', '\\"')
                .. '", Scope = "' .. L.Scope .. '" }'
        end
        -- كتابة آمنة للملف
        local function verifiedWrite(path, identity, key, seed, data)
            local current, state = readRecord(path, identity)
            if current and current.Checked and current.Seed == seed and current.Key == key then return true end
            if state == "unreadable" or state == "other_scope" then return false end
            if current and current.Seed ~= seed and (identity or not L.HasIdentityRecord) then return false end
            local file = io.open(path, "w")
            if not file then return false end
            file:write(data)
            file:close()
            local result = readRecord(path, identity)
            return result ~= nil and result.Checked and result.Seed == seed and result.Key == key
        end
        -- حفظ الكود العادي (بدون هوية الجهاز)
        L.SavePlain = function()
            local key = L.AttemptKey or L.Key
            if type(key) ~= "string" or key == "" then return false end
            local data = plainPayload(key)
            local ok = false
            for _, base in ipairs(candidates()) do
                local pp = plainKeyPath(base)
                local f = io.open(pp, "w")
                if f then
                    f:write(data); f:close()
                    ok = true
                end
            end
            return ok
        end
        L.LoadPlain = function()
            if type(L.Key) == "string" and L.Key ~= "" then return true end
            for _, base in ipairs(candidates()) do
                local pp = plainKeyPath(base)
                local okR, file = pcall(io.open, pp, "r")
                if okR and file then
                    local data = file:read("*a") or ""
                    file:close()
                    local scope = data:match('Scope%s*=%s*"([%x]+)"')
                    if scope == L.Scope then
                        local key = data:match('Key%s*=%s*"([^"]*)"')
                        if key and key ~= "" then
                            L.Key = key
                            return true
                        end
                    end
                end
            end
            return false
        end
        L.Save = function()
            pcall(L.SavePlain)
            if L.Seed == "" or L.IdentityError then return false end
            local key = L.AttemptKey or L.Key
            local data = payload(key, L.Seed)
            local preferred = candidates()
            for _, base in ipairs(preferred) do
                local device = identityPath(base)
                local old, oldState = readRecord(base, false)
                local current, currentState = readRecord(device, true)
                if oldState ~= "unreadable" and currentState ~= "unreadable"
                    and oldState ~= "other_scope" and currentState ~= "other_scope"
                    and (not old or old.Seed == L.Seed or L.HasIdentityRecord)
                    and (not current or current.Seed == L.Seed) then
                    local a = verifiedWrite(device, true, key, L.Seed, data)
                    local b = verifiedWrite(device .. ".bak", true, key, L.Seed, data)
                    local c = verifiedWrite(base, false, key, L.Seed, data)
                    local d = verifiedWrite(base .. ".bak", false, key, L.Seed, data)
                    if (a or b) and ((a and b) or c or d) then
                        L.Path = base; L.Key = key; L.IdentityPinned = true; L.IdentityPersisted = true; L.HasIdentityRecord = true
                        L.IdentityError = nil; L.Dirty = not (a and b and c and d)
                        L.SaveRetryAt = L.Dirty and (os.time() + 30) or nil
                        L.SaveError = L.Dirty and "Device backup repair pending" or nil
                        L.Diagnostics.Identity = L.Dirty and "backup_pending" or "saved"
                        return true
                    end
                end
            end
            L.Dirty = true; L.SaveRetryAt = os.time() + 30
            L.SaveError = "Device cache could not be verified"; L.Diagnostics.Identity = "save_failed"
            return false
        end
        L.BindSettingsPath = function(featurePath)
            L.PreferredPath = featurePath
            if not L.IdentityPinned then recover() end
            if L.Seed ~= "" and not L.IdentityError and (L.Dirty or not L.IdentityPersisted) then L.Save() end
        end
        L.EnsureIdentity = function()
            if not L.IdentityPinned then
                L.Seed = ""
                assert(recover(), L.IdentityError or "DEVICE_CACHE_RECOVERY_REQUIRED")
            end
            if L.Seed == "" then
                L.Diagnostics.DeviceReads = L.Diagnostics.DeviceReads + 1
                local id = Client.GetPhoneDeviceID()
                assert(type(id) == "string" and #id > 0 and #id <= 512, "DEVICE_ID_UNAVAILABLE")
                L.Seed = id
            end
            local saved = L.Save()
            assert(saved or L.IdentityPersisted, "DEVICE_CACHE_SAVE_FAILED")
        end
        recover()
        L.LoadPlain()
        L.DestroyUI = function() destroy(L.LoginUI); destroy(L.WelcomeUI); L.LoginUI = nil; L.WelcomeUI = nil end
        local function wake()
            local f = _G.LunarFeatures; if f and f.Wake and not f.Token.Stopped then f.Wake() end
        end
        L.Core = VIPLicenseCore
        L.Auth = VIPLicenseCore.new(VIPLicenseConfig, {
            clock = function() local t = os.time(); return t end,
            wall = function() return os.time() end,
            serial = function(key)
                L.EnsureIdentity()
                return VIPLicenseCore.Primitives.name_uuid('VIP-SERVER-V1\0' .. key .. '\0' .. L.Seed)
            end,
            status = function(message, phase)
                L.Status = message; L.Pending = phase == "pending"
                if phase == "active" then
                    L.Authorized = true; L.Key = L.AttemptKey or L.Key; L.Save()
                    destroy(L.LoginUI); L.LoginUI = nil
                else L.Authorized = false end
                L.NeedsUpdate = true
                local d = L.LoginUI
                if d then
                    if d.StatusText ~= message then d.Status:SetText(message); d.StatusText = message end
                    if d.Busy ~= L.Pending then
                        d.Busy = L.Pending
                        pcall(function() d.Input:SetIsEnabled(not L.Pending); d.Button:SetIsEnabled(not L.Pending) end)
                    end
                end
                wake()
            end
        })
        L.Authorized = L.Auth.IsAuthorized()
        L.Login = function(key)
            if L.Authorized or L.Pending then return false end
            L.AttemptKey = type(key) == "string" and key:match("^%s*(.-)%s*$") or ""
            local ok, result = pcall(L.Auth.Login, L.AttemptKey)
            if not ok then L.Status = "Login could not start"; L.Pending = false; L.NeedsUpdate = true; wake(); return false end
            if result and L.Seed ~= "" then
                L.Key = L.AttemptKey
                pcall(L.Save)
            end
            return result
        end
        L.AutoLoginAttempted = false
        local function tryAutoLogin()
            if L.Authorized then return true end
            if type(L.Key) ~= "string" or L.Key == "" then return false end
            if L.Pending then return false end
            L.AutoLoginAttempted = true
            local ok, res = pcall(L.Login, L.Key)
            return ok and res == true
        end
        L.TryAutoLogin = tryAutoLogin
        tryAutoLogin()
        L.Logout = function()
            L.Auth.Logout(); L.Authorized = false; L.DestroyUI(); L.NeedsUpdate = true; wake()
        end
        L.Update = function()
            if not L.Authorized and not L.Pending then
                if type(L.Key) == "string" and L.Key ~= "" then
                    if not L.AutoLoginAttempted or L.IdentityError or (L.SaveError ~= nil) then
                        L.TryAutoLogin()
                    end
                end
            end
            if L.Dirty and (not L.SaveRetryAt or os.time() >= L.SaveRetryAt or os.time() < L.SaveRetryAt - 30) then L.Save() end
            if L.Authorized then
                if not L.WelcomeShown then
                    local d = UI.Build("welcome")
                    if d then L.WelcomeUI = d; L.WelcomeShown = true end
                end
                L.NeedsUpdate = not L.WelcomeShown or L.Dirty
                return
            end
            local p = parent()
            if L.LoginUI and (not valid(L.LoginUI.Container) or p ~= L.LoginUI.Parent) then destroy(L.LoginUI); L.LoginUI = nil end
            if not L.LoginUI then
                local d = UI.Build("login", L.Key, L.Status, L.Login)
                if d then
                    d.Busy = L.Pending; d.StatusText = L.Status; L.LoginUI = d
                    pcall(function() d.Input:SetIsEnabled(not L.Pending); d.Button:SetIsEnabled(not L.Pending) end)
                end
            end
            L.NeedsUpdate = true
        end
    end

    _G.VIPLicenseLogin = function(key) return _G.LunarLoginRuntime.Login(key) end
    _G.VIPLicenseLogout = function() return _G.LunarLoginRuntime.Logout() end
    _G.VIPLicenseStatus = function()
        local l = _G.LunarLoginRuntime
        return {authorized = l.Authorized, pending = l.Pending, message = l.Status,
            periodicRecheck = false, expiryCheckPolicy = "login_only", saveOK = not l.Dirty, identityState = l.Diagnostics.Identity}
    end
end

-- استدعاء التهيئة
_VIPLicense_Init()

-- ==============================================================================
-- ==================== نهاية نظام الترخيص والأكواد =============================
-- ==============================================================================

-- ==============================================================================
-- ============================ BẮT ĐẦU CÁC HỆ THỐNG KHÁC =======================
-- ==============================================================================

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  }
}, "BRPlayerCharacterBase")
