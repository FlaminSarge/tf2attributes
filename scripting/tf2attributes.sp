#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_NAME		"[TF2] TF2Attributes"
#define PLUGIN_AUTHOR		"FlaminSarge"
#define PLUGIN_VERSION		"1.7.5"
#define PLUGIN_CONTACT		"http://forums.alliedmods.net/showthread.php?t=210221"
#define PLUGIN_DESCRIPTION	"Functions to add/get attributes for TF2 players/items"

public Plugin myinfo = {
	name		= PLUGIN_NAME,
	author		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESCRIPTION,
	version		= PLUGIN_VERSION,
	url		= PLUGIN_CONTACT
};

// "counts as assister is some kind of pet this update is going to be awesome" is 73 characters. Valve... Valve.
#define MAX_ATTRIBUTE_NAME_LENGTH 128
#define MAX_ATTRIBUTE_VALUE_LENGTH PLATFORM_MAX_PATH

enum OS {
	OS_Unknown = 0,
	OS_Windows,
	OS_Windows64,
	OS_Linux,
	OS_Linux64,
	OS_Mac,
}
OS g_OS;

Handle hSDKGetItemDefinition;
Handle hSDKGetSOCData;
Handle hSDKSchema;
Handle hSDKGetAttributeDef;
Handle hSDKGetAttributeDefByName;
Handle hSDKSetRuntimeValue;
Handle hSDKGetAttributeByID;
Handle hSDKOnAttribValuesChanged;
Handle hSDKRemoveAttribute;
Handle hSDKDestroyAllAttributes;
Handle hSDKAddCustomAttribute;
Handle hSDKRemoveCustomAttribute;
Handle hSDKAttributeHookFloat;
Handle hSDKAttributeHookInt;

// these two are mutually exclusive
Handle hSDKAttributeApplyStringWrapperVtable;
Handle hSDKAttributeApplyStringWrapperSig;

Handle hSDKAttributeValueInitialize;
Handle hSDKAttributeValueInitialize_Virtual;
Handle hSDKAttributeTypeCanBeNetworked;
Handle hSDKAttributeValueFromString;
Handle hSDKAttributeValueFromString_Virtual;
Handle hSDKAttributeValueUnloadByRef;
Handle hSDKCopyStringAttributeToCharPointer;

// caches attribute name to definition instance
StringMap g_AttributeDefinitionMapping;

// caches string_t instances from AllocPooledString
StringMap g_AllocPooledStringCache;

IntMap g_imapAttrIsNetworked;

/** Address Offsets **/
enum struct CUtlVector {
	Address m_size; // int

	void Init() {
		// this.m_memory = view_as<Address>(0); // CUtlMemory<T> {T* m_pMemory, int m_nAllocationCount, int m_nGrowSize}
		this.m_size = Address_PointerSize + view_as<Address>(4 + 4); // 12/16
		// this.m_pElements = this.m_size + Address_PointerSize; // 16/24(+ 4 padding) T*
	}
}
CUtlVector g_CUtlVector;

enum struct CAttributeList {
	Address m_Attributes; // CUtlVector<CEconItemAttribute>
	Address m_Attributes_m_Size; // int
	Address m_pManager; // CAttributeManager*

	void Init() {
		// vfptr = 0; // offset 0
		this.m_Attributes = Address_PointerSize; // +PS (vfptr): CUtlVector<CEconItemAttribute>

		this.m_Attributes_m_Size = this.m_Attributes + Address_PointerSize + 8; // +sizeof(CUtlMemory): m_pMemory(PS) + m_nAllocationCount(4) + m_nGrowSize(4)
		this.m_pManager = this.m_Attributes + 3 * Address_PointerSize + 8; // +sizeof(CUtlVector): sizeof(CUtlMemory) + m_Size(4) + pad(PS-4) + m_pElements(PS)
	}
}
CAttributeList g_CAttributeList;

enum struct CEconItemAttribute {
	Address m_iAttributeDefinitionIndex; // attrib_definition_index_t (u16)
	Address m_flValue; // float
	Address m_nRefundableCurrency; // int
	int iSizeOf;

	void Init() {
		// vfptr = 0; // offset 0
		this.m_iAttributeDefinitionIndex = Address_PointerSize; // +PS (vfptr): attrib_definition_index_t (u16)

		this.m_flValue = this.m_iAttributeDefinitionIndex + 4; // +m_iAttributeDefinitionIndex(2) + pad(2)
		this.m_nRefundableCurrency = this.m_flValue + 4; // +m_flValue(4)
		this.iSizeOf = view_as<int>(2 * Address_PointerSize + 8); // sizeof: vfptr(PS) + u16(2) + pad(2) + float(4) + int(4) + tail_pad(PS-4)
	}
}
CEconItemAttribute g_CEconItemAttribute;

enum struct CEconItemAttributeDefinition {
	Address m_nDefIndex;
	Address m_pAttrType;
	Address m_bStoredAsInteger;

	void Init() {
		// this.m_pKVAttribute = view_as<Address>(0); // offset 0 (ptr)
		this.m_nDefIndex = Address_PointerSize; // +PS (m_pKVAttribute): u16

		this.m_pAttrType = this.m_nDefIndex + Address_PointerSize; // +m_nDefIndex(2) + pad(PS-2)
		// this.m_bHidden = this.m_pAttrType + Address_PointerSize;
		// this.m_bWebSchemaOutputForced = this.m_bHidden + 1;
		this.m_bStoredAsInteger = this.m_pAttrType + Address_PointerSize + 2; // +m_pAttrType(PS) + m_bHidden(1) + m_bWebSchemaOutputForced(1)
		// this.m_bInstanceData = this.m_bStoredAsInteger + 1;
		// this.m_eAssetClassAttrExportRule = this.m_bInstanceData + 1;
		// this.m_unAssetClassBucket = this.m_eAssetClassAttrExportRule + 4; // +m_eAssetClassAttrExportRule(4)
		// this.m_bIsSetBonus = this.m_unAssetClassBucket + 4;
		// this.m_iUserGenerationType = this.m_bIsSetBonus + 4;
		// this.m_iEffectType = this.m_iUserGenerationType + 4;
		// this.m_iDescriptionFormat = this.m_iEffectType + 4;
		// this.m_pszDescriptionString = this.m_iDescriptionFormat + Address_PointerSize; // +m_iDescriptionFormat(4) + pad(PS-4)
		// this.m_pszArmoryDesc = this.m_pszDescriptionString + Address_PointerSize;
		// this.m_pszDefinitionName = this.m_pszArmoryDesc + Address_PointerSize;
		// this.m_pszAttributeClass = this.m_pszDefinitionName + Address_PointerSize;
		// this.m_bCanAffectMarketName = this.m_pszAttributeClass + Address_PointerSize;
		// this.m_bCanAffectRecipeComponentName = this.m_bCanAffectMarketName + 1;
		// this.m_ItemDefinitionTag = this.m_bCanAffectRecipeComponentName + 3; // +m_bCanAffectRecipeComponentName(1) + pad(2)
		// this.m_iszAttributeClass = this.m_ItemDefinitionTag + 4; // +m_ItemDefinitionTag(int CRC32)
		// this.iSizeOf = this.m_iszAttributeClass + Address_PointerSize; // +m_iszAttributeClass(4) + pad(PS-4)
	}
}
CEconItemAttributeDefinition g_CEconItemAttributeDefinition;

enum struct CEconItem
{
	Address m_dirtyBits; // dirty_bits_t {u8 m_bInUse : 1, u8 m_bHasEquipSingleton : 1, u8 m_bHasAttribSingleton: 1}
	Address m_CustomAttribSingleton_m_unDefinitionIndex; // attribute_t + 0
	Address m_CustomAttribSingleton_m_flValue; // attribute_t + 4
	Address m_pCustomData; // CEconItemCustomData* {CUtlVector< CEconItem::attribute_t > m_vecAttributes, CEconItem* m_pInteriorItem, uint64 m_ulOriginalID, uint16 m_unQuantity}

	void Init() {
		// GCSDK::CSharedObject {vfptr} = 0
		// IEconItemInterface {vfptr} = Address_PointerSize;
		// this.m_pszSmallIcon = 2 * Address_PointerSize;
		// this.m_pszLargeIcon = this.m_pszSmallIcon + Address_PointerSize;
		// this.m_ulID = this.m_pszLargeIcon + Address_PointerSize; // u64

		// this.m_unAccountID = this.m_ulID + 8; // +m_ulID(u64)
		// this.m_unInventory = this.m_unAccountID + 4;
		// this.m_unDefIndex = this.m_unInventory + 4;
		// this.m_unLevel = this.m_unDefIndex + 2; // +m_unDefIndex(u16)
		// this.m_nQuality = this.m_unLevel + 1;
		// this.m_unFlags = this.m_nQuality + 1;
		// this.m_unOrigin = this.m_unFlags + 1;
		// this.m_unStyle = this.m_unOrigin + 1;
		this.m_dirtyBits = 4 * Address_PointerSize + 23; // 2 vfptrs + 2 icon ptrs + m_ulID(8) + 2 u32s + u16 + 5 u8s
		// this.m_EquipInstanceSingleton_m_unDefinitionIndex = this.m_dirtyBits + 1;
		this.m_CustomAttribSingleton_m_unDefinitionIndex = this.m_dirtyBits + 1 + Address_PointerSize; // +m_dirtyBits(1) + EquippedInstance_t(4) + pad(PS-4)
		this.m_CustomAttribSingleton_m_flValue = this.m_CustomAttribSingleton_m_unDefinitionIndex + Address_PointerSize; // +m_unDefinitionIndex(2) + pad(PS-2)
		this.m_pCustomData = this.m_CustomAttribSingleton_m_flValue + Address_PointerSize; // +attribute_data_union_t(PS)
	}
}
CEconItem g_CEconItem;

enum struct CEconItemDefinition {
	Address m_vecStaticAttributes; // CUtlVector<static_attrib_t>
	Address m_vecStaticAttributes_m_Size; // int

	void Init() {
		// vfptr = 0; // offset 0
		// this.m_pKVItem = Address_PointerSize;
		// this.m_nDefIndex = this.m_pKVItem + Address_PointerSize; // +m_pKVItem(PS): u16

		// this.m_nRemappedDefIndex = this.m_nDefIndex + 2; // +m_nDefIndex(2): u16
		// this.m_pszRemappedDefItemName = this.m_nRemappedDefIndex + Address_PointerSize - 2; // +m_nRemappedDefIndex(2) + pad(PS-4)
		// this.m_bEnabled = this.m_pszRemappedDefItemName + Address_PointerSize;
		// this.m_unMinItemLevel = this.m_bEnabled + 1;
		// this.m_unMaxItemLevel = this.m_unMinItemLevel + 1;
		// this.m_nItemQuality = this.m_unMaxItemLevel + 1;
		// this.m_nForcedItemQuality = this.m_nItemQuality + 1;
		// this.m_nItemRarity = this.m_nForcedItemQuality + 1;
		// this.m_nDefaultDropQuantity = this.m_nItemRarity + 1;
		// this.m_unItemSeries = this.m_nDefaultDropQuantity + 2; // +m_nDefaultDropQuantity(1) + pad(1)
		this.m_vecStaticAttributes = 5 * Address_PointerSize + 8; // 2 pointers + 2 u16s + pad(PS-4) + pointer + 7 u8s + pad(1) + u16 + pad(PS-2): CUtlVector<static_attrib_t>
		this.m_vecStaticAttributes_m_Size = this.m_vecStaticAttributes + Address_PointerSize + 8; // +sizeof(CUtlMemory): m_pMemory(PS) + m_nAllocationCount(4) + m_nGrowSize(4) -> 0x28 (x86) / 0x40 (x64)
		// this.m_nPopularitySeed = this.m_vecStaticAttributes_m_Size + 2 * Address_PointerSize; // +m_Size(4) + pad(PS-4) + m_pElements(PS)
		// this.m_pszItemBaseName = this.m_nPopularitySeed + Address_PointerSize; // +m_nPopularitySeed(4) + pad(PS-4)
		// this.m_bProperName = this.m_pszItemBaseName + Address_PointerSize;
		// this.m_pszItemTypeName = this.m_bProperName + Address_PointerSize; // +m_bProperName(1) + pad(PS-1)
		// this.m_pszItemDesc = this.m_pszItemTypeName + Address_PointerSize;
		// this.m_rtExpiration = this.m_pszItemDesc + Address_PointerSize;
		// this.m_pszInventoryModel = this.m_rtExpiration + Address_PointerSize; // +m_rtExpiration(4) + pad(PS-4)
		// this.m_pszInventoryImage = this.m_pszInventoryModel + Address_PointerSize;
		// this.m_pszInventoryOverlayImages = this.m_pszInventoryImage + Address_PointerSize; // CUtlVector<const char*>
		// this.m_iInventoryImagePosition = this.m_pszInventoryOverlayImages + 3 * Address_PointerSize + 8; // +sizeof(CUtlVector)
		// this.m_iInventoryImageSize = this.m_iInventoryImagePosition + 8; // +m_iInventoryImagePosition(8)
		// this.m_iInspectPanelDistance = this.m_iInventoryImageSize + 8; // +m_iInventoryImageSize(8)
		// this.m_pszBaseDisplayModel = this.m_iInspectPanelDistance + Address_PointerSize; // +m_iInspectPanelDistance(4) + pad(PS-4)
		// this.m_iDefaultSkin = this.m_pszBaseDisplayModel + Address_PointerSize;
		// this.m_bLoadOnDemand = this.m_iDefaultSkin + 4; // +m_iDefaultSkin(4)
		// this.m_bHasBeenLoaded = this.m_bLoadOnDemand + 1;
		// this.m_bHideBodyGroupsDeployedOnly = this.m_bHasBeenLoaded + 1;
		// this.m_pszWorldDisplayModel = this.m_bHideBodyGroupsDeployedOnly + 2; // +m_bHideBodyGroupsDeployedOnly(1) + pad(1)
		// this.m_pszWorldExtraWearableModel = this.m_pszWorldDisplayModel + Address_PointerSize;
		// this.m_pszWorldExtraWearableViewModel = this.m_pszWorldExtraWearableModel + Address_PointerSize;
		// this.m_pszVisionFilteredDisplayModel = this.m_pszWorldExtraWearableViewModel + Address_PointerSize;
		// this.m_pszCollectionReference = this.m_pszVisionFilteredDisplayModel + Address_PointerSize;
		// this.m_bAttachToHands = this.m_pszCollectionReference + Address_PointerSize;
		// this.m_bAttachToHandsVMOnly = this.m_bAttachToHands + 1;
		// this.m_bFlipViewModel = this.m_bAttachToHandsVMOnly + 1;
		// this.m_bActAsWearable = this.m_bFlipViewModel + 1;
		// this.m_bActAsWeapon = this.m_bActAsWearable + 1;
		// this.m_bIsTool = this.m_bActAsWeapon + 1;
		// this.m_pItemSetDef = this.m_bIsTool + 3; // +m_bIsTool(1) + pad(2)
		// this.m_pItemCollectionDef = this.m_pItemSetDef + Address_PointerSize;
		// this.m_PerTeamVisuals = this.m_pItemCollectionDef + Address_PointerSize;
		// this.m_pszBrassModelOverride = this.m_PerTeamVisuals + 5 * Address_PointerSize; // +m_PerTeamVisuals(5*PS)
		// this.m_pTool = this.m_pszBrassModelOverride + Address_PointerSize;
		// this.m_BundleInfo = this.m_pTool + Address_PointerSize;
		// this.m_iCapabilities = this.m_BundleInfo + Address_PointerSize;
		// this.m_pDictIcons = this.m_iCapabilities + Address_PointerSize; // +m_iCapabilities(4) + pad(PS-4)
		// this.m_pszItemClassname = this.m_pDictIcons + Address_PointerSize;
		// this.m_pszItemLogClassname = this.m_pszItemClassname + Address_PointerSize;
		// this.m_pszItemIconClassname = this.m_pszItemLogClassname + Address_PointerSize;
		// this.m_pszDefinitionName = this.m_pszItemIconClassname + Address_PointerSize;
		// this.m_pszDatabaseAuditTable = this.m_pszDefinitionName + Address_PointerSize;
		// this.m_bHidden = this.m_pszDatabaseAuditTable + Address_PointerSize;
		// this.m_bShouldShowInArmory = this.m_bHidden + 1;
		// this.m_bBaseItem = this.m_bShouldShowInArmory + 1;
		// this.m_bImported = this.m_bBaseItem + 1;
		// this.m_bIsPackBundle = this.m_bImported + 1;
		// this.m_pOwningPackBundle = this.m_bIsPackBundle + 4; // +m_bIsPackBundle(1) + pad(3)
		// this.m_bIsPackItem = this.m_pOwningPackBundle + Address_PointerSize;
		// this.m_pszArmoryDesc = this.m_bIsPackItem + Address_PointerSize; // +m_bIsPackItem(1) + pad(PS-1)
		// this.m_pszXifierRemapClass = this.m_pszArmoryDesc + Address_PointerSize;
		// this.m_pszBaseFunctionalItemName = this.m_pszXifierRemapClass + Address_PointerSize;
		// this.m_pszParticleSuffix = this.m_pszBaseFunctionalItemName + Address_PointerSize;
		// this.m_iArmoryRemap = this.m_pszParticleSuffix + Address_PointerSize;
		// this.m_iStoreRemap = this.m_iArmoryRemap + 4;
		// this.m_pszArmoryRemap = this.m_iStoreRemap + 4;
		// this.m_pszStoreRemap = this.m_pszArmoryRemap + Address_PointerSize;
		// this.m_pszClassToken = this.m_pszStoreRemap + Address_PointerSize;
		// this.m_pszSlotToken = this.m_pszClassToken + Address_PointerSize;
		// this.m_iDropType = this.m_pszSlotToken + Address_PointerSize;
		// this.m_pszHolidayRestriction = this.m_iDropType + Address_PointerSize; // +m_iDropType(4) + pad(PS-4)
		// this.m_nVisionFilterFlags = this.m_pszHolidayRestriction + Address_PointerSize;
		// this.m_iSubType = this.m_nVisionFilterFlags + 4; // +m_nVisionFilterFlags(4)
		// this.m_bAllowedInThisMatch = this.m_iSubType + 4;
		// this.m_unEquipRegionMask = this.m_bAllowedInThisMatch + 4; // +m_bAllowedInThisMatch(1) + pad(3)
		// this.m_unEquipRegionConflictMask = this.m_unEquipRegionMask + 4;
		// this.m_unSetItemRemapDefIndex = this.m_unEquipRegionConflictMask + 4;
		// this.m_jobs = this.m_unSetItemRemapDefIndex + 4; // +m_unSetItemRemapDefIndex(2) + pad(2): CUtlVector<job_def_t>
		// this.m_bValidForShuffle = this.m_jobs + 3 * Address_PointerSize + 8; // +sizeof(CUtlVector)
		// this.m_bValidForSelfMade = this.m_bValidForShuffle + 1;
		// this.m_vecTags = this.m_bValidForSelfMade + Address_PointerSize - 1; // +m_bValidForSelfMade(1) + pad(PS-2)
		// this.m_vecContainingBundleItemDefs = this.m_vecTags + 3 * Address_PointerSize + 8; // +sizeof(CUtlVector)
		// this.m_vecSteamWorkshopContributors = this.m_vecContainingBundleItemDefs + 3 * Address_PointerSize + 8; // +sizeof(CUtlVector)
	}
}
CEconItemDefinition g_CEconItemDefinition;

enum struct static_attrib_t {
	Address iDefIndex; // attrib_definition_index_t (u16)
	Address m_value; // union attribute_data_union_t {float asFloat; uint32 asUint32; byte *asBlobPointer;}
	int iSizeOf;

	void Init() {
		this.iDefIndex = view_as<Address>(0);
		this.m_value = Address_PointerSize; // alignment
		this.iSizeOf = view_as<int>(2 * Address_PointerSize); // sizeof: iDefIndex(2) + pad(PS-2) + m_value(PS)
	}
}
static_attrib_t g_static_attrib_t;
/** End Address Offsets **/


/**
 * since the game doesn't free heap-allocated non-GC attributes, we're taking on that
 * responsibility
 */
enum struct HeapAttributeValue {
	Address m_pAttributeValue;
	int m_iAttributeDefinitionIndex;

	void Destroy() {
		Address pAttrDef = GetAttributeDefinitionByID(this.m_iAttributeDefinitionIndex);
		UnloadAttributeRawValue(pAttrDef, this.m_pAttributeValue);
	}
}
ArrayList g_ManagedAllocatedValues;

static bool g_bPluginReady = false;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	char game[8];
	GetGameFolderName(game, sizeof(game));

	if (strncmp(game, "tf", 2, false) != 0) {
		strcopy(error, err_max, "Plugin only available for TF2 and possibly TF2Beta");
		return APLRes_Failure;
	}

	CreateNative("TF2Attrib_SetByName", Native_SetAttrib);
	CreateNative("TF2Attrib_SetByDefIndex", Native_SetAttribByID);
	CreateNative("TF2Attrib_SetFromStringValue", Native_SetAttribStringByName);
	CreateNative("TF2Attrib_GetByName", Native_GetAttrib);
	CreateNative("TF2Attrib_GetByDefIndex", Native_GetAttribByID);
	CreateNative("TF2Attrib_RemoveByName", Native_Remove);
	CreateNative("TF2Attrib_RemoveByDefIndex", Native_RemoveByID);
	CreateNative("TF2Attrib_RemoveAll", Native_RemoveAll);
	CreateNative("TF2Attrib_SetDefIndex", Native_SetID);
	CreateNative("TF2Attrib_GetDefIndex", Native_GetID);
	CreateNative("TF2Attrib_SetValue", Native_SetVal);
	CreateNative("TF2Attrib_GetValue", Native_GetVal);
	CreateNative("TF2Attrib_UnsafeGetStringValue", Native_GetStringVal);
	CreateNative("TF2Attrib_SetRefundableCurrency", Native_SetCurrency);
	CreateNative("TF2Attrib_GetRefundableCurrency", Native_GetCurrency);
	CreateNative("TF2Attrib_ClearCache", Native_ClearCache);
	CreateNative("TF2Attrib_ListDefIndices", Native_ListIDs);
	CreateNative("TF2Attrib_GetStaticAttribs", Native_GetStaticAttribs);
	CreateNative("TF2Attrib_GetSOCAttribs", Native_GetSOCAttribs);
	CreateNative("TF2Attrib_IsNetworked", Native_IsNetworked);
	CreateNative("TF2Attrib_IsIntegerValue", Native_IsIntegerValue);
	CreateNative("TF2Attrib_IsValidAttributeName", Native_IsValidAttributeName);
	CreateNative("TF2Attrib_AddCustomPlayerAttribute", Native_AddCustomAttribute);
	CreateNative("TF2Attrib_RemoveCustomPlayerAttribute", Native_RemoveCustomAttribute);
	CreateNative("TF2Attrib_HookValueFloat", Native_HookValueFloat);
	CreateNative("TF2Attrib_HookValueInt", Native_HookValueInt);
	CreateNative("TF2Attrib_HookValueString", Native_HookValueString);
	CreateNative("TF2Attrib_IsReady", Native_IsReady);

	//unused, backcompat I guess?
	CreateNative("TF2Attrib_SetInitialValue", Native_DeprecatedPropertyAccess);
	CreateNative("TF2Attrib_GetInitialValue", Native_DeprecatedPropertyAccess);
	CreateNative("TF2Attrib_SetIsSetBonus", Native_DeprecatedPropertyAccess);
	CreateNative("TF2Attrib_GetIsSetBonus", Native_DeprecatedPropertyAccess);

	RegPluginLibrary("tf2attributes");
	return APLRes_Success;
}

public int Native_IsReady(Handle plugin, int numParams) {
	return g_bPluginReady;
}

public void OnPluginStart() {
	GameData hGameConf = new GameData("tf2.attributes");
	if (!hGameConf) {
		SetFailState("Could not locate gamedata file tf2.attributes.txt for TF2Attributes, pausing plugin");
	}

	char pluginFailMessage[256];
	if (hGameConf.GetKeyValue("PluginFailMessage", pluginFailMessage,
			sizeof(pluginFailMessage)) && pluginFailMessage[0]) {
		SetFailState(pluginFailMessage);
	}

	g_OS = view_as<OS>(hGameConf.GetOffset("OS"));

	if (g_OS <= OS_Unknown) {
		SetFailState("Missing \"OS\" gamedata offset");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetItemDefinition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		//int iItemIndex
	PrepSDKCall_SetReturnInfo(SDKType_Address, SDKPass_Plain);	//Returns address of CEconItemDefinition
	hSDKGetItemDefinition = EndPrepSDKCall();
	if (!hSDKGetItemDefinition) {
		SetFailState("Could not initialize call to CEconItemSchema::GetItemDefinition");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemView::GetSOCData");
	PrepSDKCall_SetReturnInfo(SDKType_Address, SDKPass_Plain);	//Returns address of CEconItem
	hSDKGetSOCData = EndPrepSDKCall();
	if (!hSDKGetSOCData) {
		SetFailState("Could not initialize call to CEconItemView::GetSOCData");
	}

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GEconItemSchema");
	PrepSDKCall_SetReturnInfo(SDKType_Address, SDKPass_Plain);	//Returns address of CEconItemSchema
	hSDKSchema = EndPrepSDKCall();
	if (!hSDKSchema) {
		SetFailState("Could not initialize call to GEconItemSchema");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		//int iAttribIndex
	PrepSDKCall_SetReturnInfo(SDKType_Address, SDKPass_Plain);	//Returns address of a CEconItemAttributeDefinition
	hSDKGetAttributeDef = EndPrepSDKCall();
	if (!hSDKGetAttributeDef) {
		SetFailState("Could not initialize call to CEconItemSchema::GetAttributeDefinition");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinitionByName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);			//const char *pszDefName
	PrepSDKCall_SetReturnInfo(SDKType_Address, SDKPass_Plain);	//Returns address of a CEconItemAttributeDefinition
	hSDKGetAttributeDefByName = EndPrepSDKCall();
	if (!hSDKGetAttributeDefByName) {
		SetFailState("Could not initialize call to CEconItemSchema::GetAttributeDefinitionByName");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::RemoveAttribute");
	PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain);	//const CEconItemAttributeDefinition *pAttrDef
	hSDKRemoveAttribute = EndPrepSDKCall();
	if (!hSDKRemoveAttribute) {
		SetFailState("Could not initialize call to CAttributeList::RemoveAttribute");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::SetRuntimeAttributeValue");
	PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain); //const CEconItemAttributeDefinition *pAttrDef
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);			 //float flValue
	//PrepSDKCall_SetReturnInfo(SDKType_Address, SDKPass_Plain);
	//Apparently there's no return, so avoid setting return info, but the 'return' is nonzero if the attribute is added successfully
	//Just a note, the above SDKCall returns ((entindex + 4) * 4) | 0xA000), and you can AND it with 0x1FFF to get back the entindex if you want, though it's pointless)
	//I don't know any other specifics, such as if the highest 3 bits actually matter
	//And I don't know what happens when you hit ent index 2047

	hSDKSetRuntimeValue = EndPrepSDKCall();
	if (!hSDKSetRuntimeValue) {
		SetFailState("Could not initialize call to CAttributeList::SetRuntimeAttributeValue");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::DestroyAllAttributes");
	hSDKDestroyAllAttributes = EndPrepSDKCall();
	if (!hSDKDestroyAllAttributes) {
		SetFailState("Could not initialize call to CAttributeList::DestroyAllAttributes");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::GetAttributeByID");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		//int iAttributeID
	PrepSDKCall_SetReturnInfo(SDKType_Address, SDKPass_Plain);	//Returns address of a CEconItemAttribute
	hSDKGetAttributeByID = EndPrepSDKCall();
	if (!hSDKGetAttributeByID) {
		SetFailState("Could not initialize call to CAttributeList::GetAttributeByID");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CAttributeManager::OnAttributeValuesChanged");
	hSDKOnAttribValuesChanged = EndPrepSDKCall();
	if (!hSDKOnAttribValuesChanged) {
		SetFailState("Could not initialize call to CAttributeManager::OnAttributeValuesChanged");
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFPlayer::AddCustomAttribute");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);	//const char *pszAttributeName
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);		//float flValue
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);		//float flDuration
	hSDKAddCustomAttribute = EndPrepSDKCall();
	if (!hSDKAddCustomAttribute) {
		SetFailState("Could not initialize call to CTFPlayer::AddCustomAttribute");
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFPlayer::RemoveCustomAttribute");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);	//const char *pszAttributeName
	hSDKRemoveCustomAttribute = EndPrepSDKCall();
	if (!hSDKRemoveCustomAttribute) {
		SetFailState("Could not initialize call to CTFPlayer::RemoveCustomAttribute");
	}

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeManager::AttribHookValue<float>");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if (g_OS == OS_Linux64) {
		// initial value is changed from being the first parameter to being the last
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); // attribute class
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // CBaseEntity* entity
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain, VDECODE_FLAG_ALLOWNULL); // CUtlVector<CBaseEntity*>, set to nullptr
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); // bool const_string
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain); // initial value
	} else {
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain); // initial value
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); // attribute class
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // CBaseEntity* entity
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain, VDECODE_FLAG_ALLOWNULL); // CUtlVector<CBaseEntity*>, set to nullptr
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); // bool const_string
	}
	hSDKAttributeHookFloat = EndPrepSDKCall();
	if (!hSDKAttributeHookFloat) {
		SetFailState("Could not initialize call to CAttributeManager::AttribHookValue<float>");
	}

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeManager::AttribHookValue<int>");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // initial value
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); // attribute class
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // CBaseEntity* entity
	PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain, VDECODE_FLAG_ALLOWNULL); // CUtlVector<CBaseEntity*>, set to nullptr
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); // bool const_string
	hSDKAttributeHookInt = EndPrepSDKCall();
	if (!hSDKAttributeHookInt) {
		SetFailState("Could not initialize call to CAttributeManager::AttribHookValue<int>");
	}

	// returns string_t by value through a hidden return pointer on every platform except linux64 (which returns it in a register)
	// both windows builds use a normal thiscall: `this` stays in (e/r)cx and the hidden pointer is just the first explicit parameter (first stack arg on x86, rdx on x64)
	// so windows32 resolves the address from the vtable and windows64 from a signature (the vtable index isn't stable across builds)
	// linux32/linux64 use a static call so the hidden pointer (linux32) can sit before `this`
	if (g_OS == OS_Windows || g_OS == OS_Windows64) {
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetFromConf(hGameConf, g_OS == OS_Windows64 ? SDKConf_Signature : SDKConf_Virtual, "CAttributeManager::ApplyAttributeStringWrapper");
		PrepSDKCall_SetReturnInfo(SDKType_Address, SDKPass_Plain); // return string_t
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL); // hidden return pointer
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain, VDECODE_FLAG_ALLOWNULL); // string_t initial value
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // initiator entity
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain); // string_t attribute class
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain, VDECODE_FLAG_ALLOWNULL); // CUtlVector<CBaseEntity*>, set to nullptr
		hSDKAttributeApplyStringWrapperVtable = EndPrepSDKCall();
	} else {
		StartPrepSDKCall(SDKCall_Static);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeManager::ApplyAttributeStringWrapper");
		PrepSDKCall_SetReturnInfo(SDKType_Address, SDKPass_Plain); // return string_t
		if (g_OS != OS_Linux64) // linux64 returns string_t in a register, linux32 uses a hidden return pointer
			PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL); // hidden return pointer
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain); // thisptr
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain, VDECODE_FLAG_ALLOWNULL); // string_t initial value
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // initiator entity
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain); // string_t attribute class
		PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain, VDECODE_FLAG_ALLOWNULL); // CUtlVector<CBaseEntity*>, set to nullptr
		hSDKAttributeApplyStringWrapperSig = EndPrepSDKCall();
	}

	if (!hSDKAttributeApplyStringWrapperSig && !hSDKAttributeApplyStringWrapperVtable) {
		SetFailState("Could not initialize call to CAttributeManager::ApplyAttributeStringWrapper");
	}

	StartPrepSDKCall(SDKCall_Raw); // CEconItemAttribute*
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISchemaAttributeTypeBase::InitializeNewEconAttributeValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, .encflags = VENCODE_FLAG_COPYBACK); // attribute_data_union_t *out_pValue
	hSDKAttributeValueInitialize = EndPrepSDKCall();
	if (!hSDKAttributeValueInitialize) {
		SetFailState("Could not initialize call to ISchemaAttributeTypeBase::InitializeNewEconAttributeValue");
	}

	// Duplicate SDKCall to specifically handle attribute_data_union_t byte *asBlobPointer
	// attribute_data_union_t can contain a pointer and we can't handle both float/int and pointer variants with a single SDKCall
	StartPrepSDKCall(SDKCall_Raw); // CEconItemAttribute*
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISchemaAttributeTypeBase::InitializeNewEconAttributeValue");
	PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL, VENCODE_FLAG_COPYBACK); // attribute_data_union_t *out_pValue
	hSDKAttributeValueInitialize_Virtual = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Raw); // attr_type
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISchemaAttributeTypeBase::BSupportsGame..."); // 64 chars ought to be enough for anyone -- dvander, probably
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	hSDKAttributeTypeCanBeNetworked = EndPrepSDKCall();
	if (!hSDKAttributeTypeCanBeNetworked) {
		SetFailState("Could not initialize call to ISchemaAttributeTypeBase::BSupportsGameplayModificationAndNetworking");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISchemaAttributeTypeBase::BConvertStringToEconAttributeValue");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//const CEconItemAttributeDefinition *pAttrDef
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//const char *pszValue
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, .encflags = VENCODE_FLAG_COPYBACK);	//union attribute_data_union_t *out_pValue
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//bool bEnableTerribleBackwardsCompatibilitySchemaParsingCode
	hSDKAttributeValueFromString = EndPrepSDKCall();
	if (!hSDKAttributeValueFromString) {
		SetFailState("Could not initialize call to ISchemaAttributeTypeBase::BConvertStringToEconAttributeValue");
	}

	// Duplicate SDKCall to specifically handle attribute_data_union_t byte *asBlobPointer
	// attribute_data_union_t can contain a pointer and we can't handle both float/int and pointer variants with a single SDKCall
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISchemaAttributeTypeBase::BConvertStringToEconAttributeValue");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//const CEconItemAttributeDefinition *pAttrDef
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//const char *pszValue
	PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL, VENCODE_FLAG_COPYBACK);	//union attribute_data_union_t *out_pValue
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			//bool bEnableTerribleBackwardsCompatibilitySchemaParsingCode
	hSDKAttributeValueFromString_Virtual = EndPrepSDKCall();
	if (!hSDKAttributeValueFromString_Virtual) {
		SetFailState("Could not initialize call to ISchemaAttributeTypeBase::BConvertStringToEconAttributeValue");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISchemaAttributeTypeBase::UnloadEconAttributeValue");
	PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Pointer); //union attribute_data_union_t *out_pValue
	hSDKAttributeValueUnloadByRef = EndPrepSDKCall();
	if (!hSDKAttributeValueUnloadByRef) {
		SetFailState("Could not initialize call to ISchemaAttributeTypeBase::UnloadEconAttributeValue");
	}

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"CopyStringAttributeValueToCharPointerOutput");
	PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Plain);	//const CAttribute_String *pValue
	PrepSDKCall_AddParameter(SDKType_Address, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL, VENCODE_FLAG_COPYBACK); // char**, variable contains char* on return
	hSDKCopyStringAttributeToCharPointer = EndPrepSDKCall();
	if (!hSDKCopyStringAttributeToCharPointer) {
		SetFailState("Could not initialize call to CopyStringAttributeValueToCharPointerOutput");
	}

	CreateConVar("tf2attributes_version", PLUGIN_VERSION, "TF2Attributes version number", FCVAR_NOTIFY);

	g_bPluginReady = true;

	delete hGameConf;

	g_ManagedAllocatedValues = new ArrayList(sizeof(HeapAttributeValue));
	g_AttributeDefinitionMapping = new StringMap();
	g_imapAttrIsNetworked = new IntMap();

	g_AllocPooledStringCache = new StringMap();

	g_CUtlVector.Init();
	g_CAttributeList.Init();
	g_CEconItemAttribute.Init();
	g_CEconItemAttributeDefinition.Init();
	g_CEconItem.Init();
	g_CEconItemDefinition.Init();
	g_static_attrib_t.Init();
}

public void OnPluginEnd() {
	/**
	 * We don't need to do remove-on-entities on map end since their runtime lists will be gone,
	 * but we do need to remove them when the plugin is unloaded / reloaded, since we manage
	 * runtime non-networked attributes ourselves and they don't outlive the plugin.
	 */
	RemoveNonNetworkedRuntimeAttributesOnEntities();
	DestroyManagedAllocatedValues();
}

/**
 * Free up all attribute values that we allocated ourselves.
 */
public void OnMapEnd() {
	DestroyManagedAllocatedValues();

	// because attribute injection's a thing now, we invalidate our internal mappings
	// in case everything changes during the next map
	g_AttributeDefinitionMapping.Clear();
	g_imapAttrIsNetworked.Clear();

	// pooled strings might get purged only between map changes
	g_AllocPooledStringCache.Clear();
}

/* native bool TF2Attrib_IsIntegerValue(int iDefIndex); */
public int Native_IsIntegerValue(Handle plugin, int numParams) {
	int iDefIndex = GetNativeCell(1);

	Address pEconItemAttributeDefinition = GetAttributeDefinitionByID(iDefIndex);
	if (!pEconItemAttributeDefinition) {
		return ThrowNativeError(1, "Attribute index %d is invalid", iDefIndex);
	}

	return LoadFromAddress(pEconItemAttributeDefinition + g_CEconItemAttributeDefinition.m_bStoredAsInteger, NumberType_Int8);
}

static int GetStaticAttribs(Address pItemDef, int[] iAttribIndices, int[] iAttribValues, int size = 16) {
	AssertValidAddress(pItemDef);

	// 0x1C = CEconItemDefinition.m_Attributes (type CUtlVector<static_attrib_t>)
	// 0x1C = (...) m_Attributes.m_Memory.m_pMemory (m_Attributes + 0x00)
	// 0x28 = (...) m_Attributes.m_Size (m_Attributes + 0x0C)
	int iNumAttribs = LoadFromAddress(pItemDef + g_CEconItemDefinition.m_vecStaticAttributes_m_Size, NumberType_Int32);
	if (!iNumAttribs) {
		return 0;
	}

	Address pAttribList = LoadAddressFromAddress(pItemDef + g_CEconItemDefinition.m_vecStaticAttributes);

	// Read static_attrib_t (size 0x08) entries from contiguous block of memory
	for (int i = 0; i < iNumAttribs && i < size; i++) {
		Address pStaticAttrib = pAttribList + view_as<Address>(i * g_static_attrib_t.iSizeOf);
		iAttribIndices[i] = LoadFromAddress(pStaticAttrib, NumberType_Int16); // g_static_attrib_t.iDefIndex

		// non-networked values are 8-byte pointers
		// 0 on x64 (can't fit a float), low 32 bits on x86
		if (!Is64Bit() || IsNetworkedByDefIndex(iAttribIndices[i])) {
			iAttribValues[i] = LoadFromAddress(pStaticAttrib + g_static_attrib_t.m_value, NumberType_Int32);
		}
	}
	return iNumAttribs;
}

/* native int TF2Attrib_GetStaticAttribs(int iItemDefIndex, int[] iAttribIndices, float[] flAttribValues, int iMaxLen=16); */
public int Native_GetStaticAttribs(Handle plugin, int numParams) {
	int iItemDefIndex = GetNativeCell(1);
	int size = 16;
	if (numParams >= 4) {
		size = GetNativeCell(4);
	}

	if (size <= 0) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Array size must be greater than 0 (currently %d)", size);
	}

	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return -1;
	}

	Address pItemDef;
	SDKCall(hSDKGetItemDefinition, pSchema, pItemDef, iItemDefIndex);
	AssertValidAddress(pItemDef);

	int[] iAttribIndices = new int[size];
	int[] iAttribValues = new int[size];
	int iCount = GetStaticAttribs(pItemDef, iAttribIndices, iAttribValues, size);
	int written = iCount < size ? iCount : size;
	SetNativeArray(2, iAttribIndices, written);
	SetNativeArray(3, iAttribValues, written);	//cast to float on inc side
	return iCount;
}

static int GetSOCAttribs(int iEntity, int[] iAttribIndices, int[] iAttribValues, int size = 16) {
	if (size <= 0) {
		return -1;
	}
	Address pEconItemView = GetEntityEconItemView(iEntity);
	if (!pEconItemView) {
		return -1;
	}

	// pEconItem may be null if the item doesn't have SOC data (i.e., not from the item server)
	Address pEconItem;
	SDKCall(hSDKGetSOCData, pEconItemView, pEconItem);
	if (!pEconItem) {
		return 0;
	}

	// 0x34 = CEconItem.m_pAttributes (type CUtlVector<static_attrib_t>*, possibly null)
	Address pCustomData = LoadAddressFromAddress(pEconItem + g_CEconItem.m_pCustomData);
	if (pCustomData) {
		AssertValidAddress(pCustomData);

		// 0x0C = (...) m_pAttributes->m_Size (m_pAttributes + 0x0C)
		// 0x00 = (...) m_pAttributes->m_Memory.m_pMemory (m_pAttributes + 0x00)
		int iCount = LoadFromAddress(pCustomData + g_CUtlVector.m_size, NumberType_Int32);
		if (!iCount) {
			// abort early if the attribute list is empty -- we might deref garbage otherwise
			return 0;
		}

		Address pCustomDataArray = LoadAddressFromAddress(pCustomData);

		// Read static_attrib_t (size 0x08) entries from contiguous block of memory
		for (int i = 0; i < iCount && i < size; ++i) {
			Address pSOCAttribEntry = pCustomDataArray + view_as<Address>(i * g_static_attrib_t.iSizeOf);

			iAttribIndices[i] = LoadFromAddress(pSOCAttribEntry, NumberType_Int16); // g_static_attrib_t.iDefIndex
			if (!Is64Bit() || IsNetworkedByDefIndex(iAttribIndices[i])) {
				iAttribValues[i] = LoadFromAddress(pSOCAttribEntry + g_static_attrib_t.m_value, NumberType_Int32);
			}
		}
		return iCount;
	}

	//(CEconItem+0x27 & 0b100 & 0xFF) != 0
	bool hasInternalAttribute = !!(LoadFromAddress(pEconItem + g_CEconItem.m_dirtyBits, NumberType_Int8) & 0b100);
	if (hasInternalAttribute) {
		iAttribIndices[0] = LoadFromAddress(pEconItem + g_CEconItem.m_CustomAttribSingleton_m_unDefinitionIndex, NumberType_Int16);
		if (!Is64Bit() || IsNetworkedByDefIndex(iAttribIndices[0])) {
			iAttribValues[0] = LoadFromAddress(pEconItem + g_CEconItem.m_CustomAttribSingleton_m_flValue, NumberType_Int32);
		}
		return 1;
	}
	return 0;
}

/* native int TF2Attrib_GetSOCAttribs(int iEntity, int[] iAttribIndices, float[] flAttribValues, int iMaxLen=16); */
public int Native_GetSOCAttribs(Handle plugin, int numParams) {
	int iEntity = GetNativeCell(1);
	int size = 16;
	if (numParams >= 4) {
		size = GetNativeCell(4);
	}

	if (size <= 0) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Array size must be greater than 0 (currently %d)", size);
	}

	if (!IsValidEntity(iEntity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(iEntity), iEntity);
	}

	int[] iAttribIndices = new int[size];
	int[] iAttribValues = new int[size];
	int iCount = GetSOCAttribs(iEntity, iAttribIndices, iAttribValues, size);
	int written = iCount < size ? iCount : size;
	SetNativeArray(2, iAttribIndices, written);
	SetNativeArray(3, iAttribValues, written);	//cast to float on inc side
	return iCount;
}


/* native bool TF2Attrib_IsNetworked(int iDefIndex); */
public int Native_IsNetworked(Handle plugin, int numParams) {
	int iDefIndex = GetNativeCell(1);
	return IsNetworkedByDefIndex(iDefIndex);
}

/* native bool TF2Attrib_SetByName(int iEntity, char[] strAttrib, float flValue); */
public int Native_SetAttrib(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}

	char strAttrib[MAX_ATTRIBUTE_NAME_LENGTH];
	GetNativeString(2, strAttrib, sizeof(strAttrib));
	float flVal = GetNativeCell(3);

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) does not have property m_AttributeList", EntIndexToEntRef(entity), entity);
	}

	Address pAttribDef = GetAttributeDefinitionByName(strAttrib);
	if (!pAttribDef) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Attribute name '%s' is invalid", strAttrib);
	}

	SDKCall(hSDKSetRuntimeValue, pEntAttributeList, pAttribDef, flVal);
	return true;
}

/* native bool TF2Attrib_SetByDefIndex(int iEntity, int iDefIndex, float flValue); */
public int Native_SetAttribByID(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}

	int iAttrib = GetNativeCell(2);
	float flVal = GetNativeCell(3);

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) does not have property m_AttributeList", EntIndexToEntRef(entity), entity);
	}

	Address pAttribDef = GetAttributeDefinitionByID(iAttrib);
	if (!pAttribDef) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Attribute index %d is invalid", iAttrib);
	}

	SDKCall(hSDKSetRuntimeValue, pEntAttributeList, pAttribDef, flVal);
	return true;
}

/* native bool TF2Attrib_SetFromStringValue(int iEntity, const char[] strAttrib, const char[] strValue); */
public int Native_SetAttribStringByName(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) does not have property m_AttributeList", EntIndexToEntRef(entity), entity);
	}

	char strAttrib[MAX_ATTRIBUTE_NAME_LENGTH], strAttribVal[MAX_ATTRIBUTE_VALUE_LENGTH];
	GetNativeString(2, strAttrib, sizeof(strAttrib));
	GetNativeString(3, strAttribVal, sizeof(strAttribVal));

	int attrdef;
	if (!GetAttributeDefIndexByName(strAttrib, attrdef)) {
		// we don't throw on nonexistent attributes here; we return false and let the caller handle that
		return false;
	}

	if (Is64Bit() && !IsNetworkedByDefIndex(attrdef)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Attribute '%s' is a non-networked type, which cannot be set on 64-bit servers", strAttrib);
	}

	// allocate a CEconItemAttribute instance in an entity's runtime attribute list
	if (!InitializeAttributeValue(pEntAttributeList, attrdef, strAttribVal)) {
		return false;
	}
	return true;
}

/* native Address TF2Attrib_GetByName(int iEntity, char[] strAttrib); */
public int Native_GetAttrib(Handle plugin, int numParams) {
	// There is a CAttributeList::GetByName, wonder why this is being done instead...
	int entity = GetNativeCell(2);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}

	char strAttrib[MAX_ATTRIBUTE_NAME_LENGTH];
	GetNativeString(3, strAttrib, sizeof(strAttrib));

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) does not have property m_AttributeList", EntIndexToEntRef(entity), entity);
	}

	int iDefIndex;
	if (!GetAttributeDefIndexByName(strAttrib, iDefIndex)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Attribute name '%s' is invalid", strAttrib);
	}

	Address pAttrib;
	SDKCall(hSDKGetAttributeByID, pEntAttributeList, pAttrib, iDefIndex);
	return SetNativeReturnAddress(pAttrib);
}

/* native Address TF2Attrib_GetByDefIndex(int iEntity, int iDefIndex); */
public int Native_GetAttribByID(Handle plugin, int numParams) {
	int entity = GetNativeCell(2);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}

	int iDefIndex = GetNativeCell(3);

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return SetNativeReturnAddress(Address_Null);
	}

	Address pAttrib;
	SDKCall(hSDKGetAttributeByID, pEntAttributeList, pAttrib, iDefIndex);
	return SetNativeReturnAddress(pAttrib);
}

/* native bool TF2Attrib_RemoveByName(int iEntity, char[] strAttrib); */
public int Native_Remove(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}

	char strAttrib[MAX_ATTRIBUTE_NAME_LENGTH];
	GetNativeString(2, strAttrib, sizeof(strAttrib));

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) does not have property m_AttributeList", EntIndexToEntRef(entity), entity);
	}

	Address pAttribDef = GetAttributeDefinitionByName(strAttrib);
	if (!pAttribDef) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Attribute name '%s' is invalid", strAttrib);
	}

	SDKCall(hSDKRemoveAttribute, pEntAttributeList, pAttribDef);	//Not a clue what the return is here, but it's probably a clone of the attrib being removed
	return true;
}

/* native bool TF2Attrib_RemoveByDefIndex(int iEntity, int iDefIndex); */
public int Native_RemoveByID(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}

	int iAttrib = GetNativeCell(2);

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) does not have property m_AttributeList", EntIndexToEntRef(entity), entity);
	}

	Address pAttribDef = GetAttributeDefinitionByID(iAttrib);
	if (!pAttribDef) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Attribute index %d is invalid", iAttrib);
	}

	SDKCall(hSDKRemoveAttribute, pEntAttributeList, pAttribDef);	//Not a clue what the return is here, but it's probably a clone of the attrib being removed
	return true;
}

/* native bool TF2Attrib_RemoveAll(int iEntity); */
public int Native_RemoveAll(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) does not have property m_AttributeList", EntIndexToEntRef(entity), entity);
	}

	SDKCall(hSDKDestroyAllAttributes, pEntAttributeList);	//disregard the return (Valve does!)
	return true;
}

/* native void TF2Attrib_SetDefIndex(Address pAttrib, int iDefIndex); */
public int Native_SetID(Handle plugin, int numParams) {
	Address pAttrib = GetNativeAddress(1);
	int iDefIndex = GetNativeCell(2);
	StoreToAddress(pAttrib + g_CEconItemAttribute.m_iAttributeDefinitionIndex, iDefIndex, NumberType_Int16);
	return iDefIndex;
}

/* native int TF2Attrib_GetDefIndex(Address pAttrib); */
public int Native_GetID(Handle plugin, int numParams) {
	Address pAttrib = GetNativeAddress(1);
	return LoadFromAddress(pAttrib + g_CEconItemAttribute.m_iAttributeDefinitionIndex, NumberType_Int16);
}

/* native void TF2Attrib_SetValue(Address pAttrib, float flValue); */
public int Native_SetVal(Handle plugin, int numParams) {
	Address pAttrib = GetNativeAddress(1);
	int flVal = GetNativeCell(2);	//It's a float but avoiding tag mismatch warnings from StoreToAddress
	StoreToAddress(pAttrib + g_CEconItemAttribute.m_flValue, flVal, NumberType_Int32);
	return flVal;
}

/* native float TF2Attrib_GetValue(Address pAttrib); */
public int Native_GetVal(Handle plugin, int numParams) {
	Address pAttrib = GetNativeAddress(1);
	return LoadFromAddress(pAttrib + g_CEconItemAttribute.m_flValue, NumberType_Int32);
}

/* native int TF2Attrib_UnsafeGetStringValue(Address pRawValue, char[] buffer, int maxlen); */
public int Native_GetStringVal(Handle plugin, int numParams) {
	if (Is64Bit()) {
		return ThrowNativeError(SP_ERROR_NATIVE, "This native is not supported on 64-bit servers");
	}

	Address pRawValue = GetNativeAddress(1);
	int maxlen = GetNativeCell(3), length;

	char[] buffer = new char[maxlen];

	length = ReadStringAttributeValue(pRawValue, buffer, maxlen);
	SetNativeString(2, buffer, maxlen, .bytes = length);
	return length;
}

/* native void TF2Attrib_SetRefundableCurrency(Address pAttrib, int nCurrency); */
public int Native_SetCurrency(Handle plugin, int numParams) {
	Address pAttrib = GetNativeAddress(1);
	int nCurrency = GetNativeCell(2);
	StoreToAddress(pAttrib + g_CEconItemAttribute.m_nRefundableCurrency, nCurrency, NumberType_Int32);
	return nCurrency;
}

/* native int TF2Attrib_GetRefundableCurrency(Address pAttrib); */
public int Native_GetCurrency(Handle plugin, int numParams) {
	Address pAttrib = GetNativeAddress(1);
	return LoadFromAddress(pAttrib + g_CEconItemAttribute.m_nRefundableCurrency, NumberType_Int32);
}

public int Native_DeprecatedPropertyAccess(Handle plugin, int numParams) {
	return ThrowNativeError(SP_ERROR_NATIVE, "Property associated with native function no longer exists");
}

static bool ClearAttributeCache(int entity) {
	if (entity <= 0 || !IsValidEntity(entity)) {
		return false;
	}

	Address pAttributeManager = GetEntityAttributeManager(entity);
	if (!pAttributeManager) {
		return false;
	}

	SDKCall(hSDKOnAttribValuesChanged, pAttributeManager);
	return true;
}

/* native bool TF2Attrib_ClearCache(int iEntity); */
public int Native_ClearCache(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}
	return ClearAttributeCache(entity);
}

/* native int TF2Attrib_ListDefIndices(int iEntity, int[] iDefIndices, int iMaxLen=20); */
public int Native_ListIDs(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	int size = 20;
	if (numParams >= 3) {
		size = GetNativeCell(3);
	}

	if (size <= 0) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Array size must be greater than 0 (currently %d)", size);
	}

	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}

	Address pAttributeList = GetEntityAttributeList(entity);
	if (!pAttributeList) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) does not have property m_AttributeList", EntIndexToEntRef(entity), entity);
	}

	// 0x10 = CAttributeList.m_Attributes.m_Size (m_Attributes + 0x0C)
	int iNumAttribs = LoadFromAddress(pAttributeList + g_CAttributeList.m_Attributes_m_Size, NumberType_Int32);
	if (!iNumAttribs) {
		return 0;
	}

	// 0x04 = CAttributeList.m_Attributes (type CUtlVector<CEconItemAttribute>)
	// 0x04 = CAttributeList.m_Attributes.m_Memory.m_pMemory
	Address pAttribListData = LoadAddressFromAddress(pAttributeList + g_CAttributeList.m_Attributes);
	AssertValidAddress(pAttribListData);

	int[] iAttribIndices = new int[size];

	// Read CEconItemAttribute (size 0x10) entries from contiguous block of memory
	for (int i = 0; i < iNumAttribs && i < size; i++) {
		Address pAttributeEntry = pAttribListData + view_as<Address>(i * g_CEconItemAttribute.iSizeOf);
		iAttribIndices[i] = LoadFromAddress(pAttributeEntry + g_CEconItemAttribute.m_iAttributeDefinitionIndex, NumberType_Int16);
	}
	int written = iNumAttribs < size ? iNumAttribs : size;
	SetNativeArray(2, iAttribIndices, written);
	return iNumAttribs;
}

/* native bool TF2Attrib_IsValidAttributeName(const char[] strAttrib); */
public int Native_IsValidAttributeName(Handle plugin, int numParams) {
	char strAttrib[MAX_ATTRIBUTE_NAME_LENGTH];
	GetNativeString(1, strAttrib, sizeof(strAttrib));

	return GetAttributeDefinitionByName(strAttrib)? true : false;
}

/* native void TF2Attrib_AddCustomPlayerAttribute(int client, const char[] strAttrib, float flValue, float flDuration = -1.0); */
public int Native_AddCustomAttribute(Handle plugin, int numParams) {
	char strAttrib[MAX_ATTRIBUTE_NAME_LENGTH];

	int client = GetNativeCell(1);
	GetNativeString(2, strAttrib, sizeof(strAttrib));

	if (!GetAttributeDefinitionByName(strAttrib)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Attribute name '%s' is invalid", strAttrib);
	}

	float flValue = GetNativeCell(3);
	float flDuration = GetNativeCell(4);

	SDKCall(hSDKAddCustomAttribute, client, strAttrib, flValue, flDuration);
	return 0;
}

public int Native_RemoveCustomAttribute(Handle plugin, int numParams) {
	char strAttrib[MAX_ATTRIBUTE_NAME_LENGTH];

	int client = GetNativeCell(1);
	GetNativeString(2, strAttrib, sizeof(strAttrib));

	if (!GetAttributeDefinitionByName(strAttrib)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Attribute name '%s' is invalid", strAttrib);
	}

	SDKCall(hSDKRemoveCustomAttribute, client, strAttrib);
	return 0;
}

/* native float TF2Attrib_HookValueFloat(float flInitial, const char[] attrClass, int iEntity); */
public int Native_HookValueFloat(Handle plugin, int numParams) {
	/**
	 * CAttributeManager::AttribHookValue<float>(float value, string_t attr_class,
	 *         CBaseEntity const* entity, CUtlVector<CBaseEntity*> reentrantList,
	 *         bool is_const_str);
	 *
	 * `value` is the value that is returned after modifiers based on `attr_class`.
	 * `reentrantList` seems to be a list of entities to ignore?
	 * `is_const_str` is true iff the `attr_class` is hardcoded
	 *     (i.e., it's at a fixed location) -- this is never true from a plugin
	 *     This determines if the game uses AllocPooledString_StaticConstantStringPointer
	 *     (when is_const_str == true) or AllocPooledString (false).
	 */
	float initial = GetNativeCell(1);

	int buflen;
	GetNativeStringLength(2, buflen);
	char[] attrClass = new char[++buflen];
	GetNativeString(2, attrClass, buflen);

	int entity = GetNativeCell(3);

	if (g_OS == OS_Linux64) {
		return SDKCall(hSDKAttributeHookFloat, attrClass, entity,
			Address_Null, false, initial);
	}

	return SDKCall(hSDKAttributeHookFloat, initial, attrClass, entity,
			Address_Null, false);
}

/* native float TF2Attrib_HookValueInt(int nInitial, const char[] attrClass, int iEntity); */
public int Native_HookValueInt(Handle plugin, int numParams) {
	int initial = GetNativeCell(1);

	int buflen;
	GetNativeStringLength(2, buflen);
	char[] attrClass = new char[++buflen];
	GetNativeString(2, attrClass, buflen);

	int entity = GetNativeCell(3);

	return SDKCall(hSDKAttributeHookInt, initial, attrClass, entity,
			Address_Null, false);
}

/* native void TF2Attrib_HookValueString(const char[] initial, const char[] attrClass, int iEntity, char[] buffer, int maxlen); */
public int Native_HookValueString(Handle plugin, int numParams) {
	int buflen;

	GetNativeStringLength(1, buflen);
	char[] inputValue = new char[++buflen];
	GetNativeString(1, inputValue, buflen);

	GetNativeStringLength(2, buflen);
	char[] attrClass = new char[++buflen];
	GetNativeString(2, attrClass, buflen);

	int entity = GetNativeCell(3);

	buflen = GetNativeCell(5);
	char[] output = new char[buflen];

	// string needs to be pooled for caching purposes
	Address pInput = AllocPooledString(inputValue);
	Address pAttrClass = AllocPooledString(attrClass);

	Address pOutput;
	if (hSDKAttributeApplyStringWrapperVtable) {
		// windows32/windows64 thiscall; hidden return pointer is the first explicit arg, `this` stays in (e/r)cx
		Address result;
		SDKCall(hSDKAttributeApplyStringWrapperVtable, GetEntityAttributeManager(entity), pOutput, result, pInput, entity, pAttrClass, Address_Null);

		// read from the output string_t
		LoadStringFromAddress(LoadAddressFromAddress(pOutput), output, buflen);

	} else if (g_OS == OS_Linux64) {
		// linux64 returns string_t in a register, no hidden pointer
		SDKCall(hSDKAttributeApplyStringWrapperSig, pOutput, GetEntityAttributeManager(entity), pInput, entity, pAttrClass, Address_Null);

		LoadStringFromAddress(pOutput, output, buflen);

	} else {
		// linux32; hidden return pointer first, then thisptr
		Address result;
		SDKCall(hSDKAttributeApplyStringWrapperSig, pOutput, result, GetEntityAttributeManager(entity), pInput, entity, pAttrClass, Address_Null);

		LoadStringFromAddress(LoadAddressFromAddress(pOutput), output, buflen);
	}

	int written;
	SetNativeString(4, output, buflen, .bytes = written);
	return written;
}

/* helper functions */

static Address GetItemSchema() {
	Address pSchema;
	SDKCall(hSDKSchema, pSchema);
	return pSchema;
}

static Address GetEntityEconItemView(int entity) {
	int iCEIVOffset = GetEntSendPropOffs(entity, "m_Item", true);
	if (iCEIVOffset > 0) {
		return GetEntityAddress(entity) + view_as<Address>(iCEIVOffset);
	}
	return Address_Null;
}

/**
 * Returns the m_AttributeList offset.  This does not correspond to the CUtlVector instance
 * (which is offset by 0x04).
 */
static Address GetEntityAttributeList(int entity) {
	int offsAttributeList = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offsAttributeList > 0) {
		return GetEntityAddress(entity) + view_as<Address>(offsAttributeList);
	}
	return Address_Null;
}

static Address GetAttributeDefinitionByName(const char[] name) {
	Address cachedResult;
	if (StringMap_GetAddress(g_AttributeDefinitionMapping, name, cachedResult)) {
		return cachedResult;
	}

	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return Address_Null;
	}
	SDKCall(hSDKGetAttributeDefByName, pSchema, cachedResult, name);
	StringMap_SetAddress(g_AttributeDefinitionMapping, name, cachedResult);
	return cachedResult;
}

static Address GetAttributeDefinitionByID(int id) {
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return Address_Null;
	}
	Address pAttrDef;
	SDKCall(hSDKGetAttributeDef, pSchema, pAttrDef, id);
	return pAttrDef;
}

/**
 * Returns true if an attribute with the specified name exists, storing the definition index
 * to the given by-ref `iDefIndex` argument.
 */
static bool GetAttributeDefIndexByName(const char[] name, int &iDefIndex) {
	Address pAttribDef = GetAttributeDefinitionByName(name);
	if (!pAttribDef) {
		return false;
	}

	iDefIndex = LoadFromAddress(pAttribDef + g_CEconItemAttributeDefinition.m_nDefIndex, NumberType_Int16);
	return true;
}

static Address GetEntityAttributeManager(int entity) {
	Address pAttributeList = GetEntityAttributeList(entity);
	if (!pAttributeList) {
		return Address_Null;
	}

	Address pAttributeManager = LoadAddressFromAddress(pAttributeList + g_CAttributeList.m_pManager);
	AssertValidAddress(pAttributeManager);
	return pAttributeManager;
}

/**
 * Initializes the space occupied by a given CEconItemAttribute pointer, parsing and allocating
 * the raw value based on the attribute's underlying type.  This should correctly parse numeric
 * and string values.
 */
static bool InitializeAttributeValue(Address pAttributeList, int attrdef, const char[] value) {
	Address pAttrDef = GetAttributeDefinitionByID(attrdef);
	if (pAttrDef == Address_Null) {
		return false;
	}

	Address pDefType = LoadAddressFromAddress(pAttrDef + g_CEconItemAttributeDefinition.m_pAttrType);

	bool networked = IsNetworkedRuntimeAttribute(pDefType);

	if (!networked) {
		if (Is64Bit()) {
			return false;
		}

		// reusing any existing matching attribute value strings
		Address rawAttributeValue = GetHeapManagedAttributeString(attrdef, value); // This assumes the union value type will be a pointer

		if (rawAttributeValue != Address_Null) {
			// x86 only -- this lops off the high 32 bits of the pointer
			SDKCall(hSDKSetRuntimeValue, pAttributeList, pAttrDef, view_as<float>(view_as<int>(rawAttributeValue)));
			return true;
		}

		/**
		 * initialize raw value; any existing values present in the CEconItemAttribute* are trashed
		 *
		 * that is okay -- tf2attributes is the only one managing heap-allocated values, and
		 * it holds its own reference to the value for freeing later
		 *
		 * we don't attempt to free any existing attribute value mid-game as we don't know if
		 * the value is present in multiple places (no refcounts!)
		 */
		SDKCall(hSDKAttributeValueInitialize_Virtual, pDefType, rawAttributeValue);

		if (!SDKCall(hSDKAttributeValueFromString_Virtual, pDefType, pAttrDef, value, rawAttributeValue, true)) {
			// in case AttributeValueInitialize created a pointer, unload it
			if (rawAttributeValue != Address_Null)
				UnloadAttributeRawValue(pAttrDef, rawAttributeValue);
			// we couldn't parse the attribute value, abort
			return false;
		}

		// same deal -- truncates to 32 bits, so x86 only
		SDKCall(hSDKSetRuntimeValue, pAttributeList, pAttrDef, view_as<float>(view_as<int>(rawAttributeValue)));

		// add to our managed values
		// this definitely works for heap, not sure if it works for inline
		HeapAttributeValue attribute;
		attribute.m_iAttributeDefinitionIndex = attrdef;
		attribute.m_pAttributeValue = rawAttributeValue;

		g_ManagedAllocatedValues.PushArray(attribute);

		return true;
	}

	// attribute value is a union of int, float, and pointer types, we assume networked won't ever be a pointer
	int attributeValue = 0;

	SDKCall(hSDKAttributeValueInitialize, pDefType, attributeValue);

	if (!SDKCall(hSDKAttributeValueFromString, pDefType, pAttrDef, value, attributeValue, true)) {
		// we couldn't parse the attribute value, abort
		return false;
	}

	SDKCall(hSDKSetRuntimeValue, pAttributeList, pAttrDef, view_as<float>(attributeValue));
	return true;
}

/**
 * Returns the address of an existing instance for the given attribute definition and string
 * value, if it exists.
 */
static Address GetHeapManagedAttributeString(int attrdef, const char[] value) {
	/**
	 * we restrict it to strings as we don't have a way to determine equality on non-string
	 * attributes.
	 */
	if (!IsAttributeString(attrdef)) {
		return Address_Null;
	}

	for (int i, n = g_ManagedAllocatedValues.Length; i < n; i++) {
		HeapAttributeValue existingAttribute;
		g_ManagedAllocatedValues.GetArray(i, existingAttribute, sizeof(existingAttribute));

		if (existingAttribute.m_iAttributeDefinitionIndex != attrdef) {
			continue;
		}

		char attributeString[PLATFORM_MAX_PATH];
		ReadStringAttributeValue(existingAttribute.m_pAttributeValue, attributeString, sizeof(attributeString));
		if (StrEqual(attributeString, value)) {
			return existingAttribute.m_pAttributeValue;
		}
	}
	return Address_Null;
}

/**
 * Returns true if the given attribute type can (normally) be networked.
 * We make the assumption that non-networked attributes have to be heap / inline allocated.
 * This should correlate with an attribute's "attribute_type" value listed in items_game.txt.
 * If the "attribute_type" key is missing or has value "float"(never used), then it is networked.
 */
static bool IsNetworkedRuntimeAttribute(Address pDefType) {
	return SDKCall(hSDKAttributeTypeCanBeNetworked, pDefType);
}

bool IsNetworkedByDefIndex(int attrdef) {
	bool bNetworked;

	if (g_imapAttrIsNetworked.GetValue(attrdef, bNetworked)) {
		return bNetworked;
	}

	Address pAttrDef = GetAttributeDefinitionByID(attrdef);
	if (pAttrDef == Address_Null) {
		return false;
	}

	Address pDefType = LoadAddressFromAddress(pAttrDef + g_CEconItemAttributeDefinition.m_pAttrType);
	bNetworked = IsNetworkedRuntimeAttribute(pDefType);
	g_imapAttrIsNetworked.SetValue(attrdef, bNetworked);

	return bNetworked;
}

/**
 * Unloads the given raw attribute value.
 */
static void UnloadAttributeRawValue(Address pAttrDef, Address pAttributeValue) {
	Address pAttributeDataUnion = pAttributeValue;
	Address pDefType = LoadAddressFromAddress(pAttrDef + g_CEconItemAttributeDefinition.m_pAttrType);
	SDKCall(hSDKAttributeValueUnloadByRef, pDefType, pAttributeDataUnion);
}

/**
 * Returns true if the given attribute definition index is a string.
 */
static bool IsAttributeString(int attrdef) {
	Address pAttrDef = GetAttributeDefinitionByID(attrdef);
	Address pKnownStringAttribDef = GetAttributeDefinitionByName("cosmetic taunt sound");
	return pAttrDef != Address_Null && pKnownStringAttribDef != Address_Null
		&& LoadAddressFromAddress(pAttrDef + g_CEconItemAttributeDefinition.m_pAttrType) == LoadAddressFromAddress(pKnownStringAttribDef + g_CEconItemAttributeDefinition.m_pAttrType);
}

/**
 * Reads the contents of a CAttribute_String raw value.
 */
static int ReadStringAttributeValue(Address pRawValue, char[] buffer, int maxlen) {
	/**
	 * Linux, Windows, and Mac differ slightly on how the std::string is laid out.
	 *
	 * For the Linux binary, the first member is a char* containing the contents of the string.
	 * Deref that and call it a day.
	 *
	 * Windows implements it as a union where it's either a `char[16]` or a `char*, size_t @ 0x14`.
	 * Check if the size_t is less than 16, then read the inline string or deref the char* depending on the results.
	 *
	 * Mac implements it as either a `bool, char[]` or `bool, char* @ 0x8`.
	 *
	 * I'm too lazy to reimplement the platform-specific bits; we're going to use sigs for this.
	 */
	Address pString;
	SDKCall(hSDKCopyStringAttributeToCharPointer, pRawValue, pString);
	return LoadStringFromAddress(pString, buffer, maxlen);
}

/**
 * Iterates over entities and removes any attributes that aren't networked (that is,
 * allocated on the heap).
 *
 * We must do this before we unload ourselves, otherwise the game will crash trying to look up
 * the heap runtime attributes we managed.
 */
static void RemoveNonNetworkedRuntimeAttributesOnEntities() {
	// heap-allocated (non-networked) values are only ever added on 32-bit
	if (Is64Bit()) {
		return;
	}

	// remove heap-based attributes from any existing entities so they don't use-after-free
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "*")) != -1) {
		// iterate runtime attribute list and remove string attributes
		// implementation straight from TF2Attrib_ListDefIndices, go over there for details
		Address pAttributeList = GetEntityAttributeList(entity);
		if (!pAttributeList) {
			continue;
		}

		// hold attribute defs pointing to heaped attributes so we don't mutate the runtime
		// attribute list while we iterate over it - according to the CUtlVector docs the list
		// can be realloc'd when an element is removed

		// the runtime attribute list can be any size, the current limit of 20 is on networked
		ArrayList heapedAttribDefs = new ArrayList();

		int iNumAttribs = LoadFromAddress(pAttributeList + g_CAttributeList.m_Attributes_m_Size, NumberType_Int32);
		if (!iNumAttribs) {
			continue;
		}

		Address pAttribListData = LoadAddressFromAddress(pAttributeList + g_CAttributeList.m_Attributes);

		// we know there are attributes; make sure our contiguous memory is valid
		AssertValidAddress(pAttribListData);

		for (int i = 0; i < iNumAttribs; i++) {
			Address pAttributeEntry = pAttribListData + view_as<Address>(i * g_CEconItemAttribute.iSizeOf);
			int attrdef = LoadFromAddress(pAttributeEntry + g_CEconItemAttribute.m_iAttributeDefinitionIndex, NumberType_Int16);

			Address pAttrDef = GetAttributeDefinitionByID(attrdef);
			if (pAttrDef == Address_Null) {
				// this shouldn't happen, but just in case
				continue;
			}

			Address pDefType = LoadAddressFromAddress(pAttrDef + g_CEconItemAttributeDefinition.m_pAttrType);
			if (IsNetworkedRuntimeAttribute(pDefType)) {
				continue;
			}

			Address rawValue = LoadAddressFromAddress(pAttributeEntry + g_CEconItemAttribute.m_flValue);

			// allow plugins to `TF2Attrib_Set*()` their own instances undisturbed by only
			// processing attributes that we're aware of
			if (IsAttributeValueInHeap(rawValue)) {
				// we should be passing around pAttrDef instead,
				// but I want the nice display printout
				heapedAttribDefs.Push(attrdef);
			}
		}

		while (heapedAttribDefs.Length) {
			int attrdef = heapedAttribDefs.Get(0);
			heapedAttribDefs.Erase(0);

			Address pAttribDef = GetAttributeDefinitionByID(attrdef);

			PrintToServer("[tf2attributes] "
					... "Removing heap-allocated attribute index %d from entity %d",
					attrdef, entity);

			SDKCall(hSDKRemoveAttribute, pAttributeList, pAttribDef);
		}
		delete heapedAttribDefs;

		ClearAttributeCache(entity);
	}
}

/**
 * Frees our heap-allocated managed attribute values so they don't leak.
 * This happens on map change (where runtime attributes are invalidated) and when the plugin is
 * unloaded.
 */
void DestroyManagedAllocatedValues() {
	while (g_ManagedAllocatedValues.Length) {
		HeapAttributeValue attribute;
		g_ManagedAllocatedValues.GetArray(0, attribute, sizeof(attribute));

		attribute.Destroy();

		g_ManagedAllocatedValues.Erase(0);
	}
}

bool IsAttributeValueInHeap(Address rawValue) {
	for (int i, n = g_ManagedAllocatedValues.Length; i < n; i++) {
		HeapAttributeValue a;
		g_ManagedAllocatedValues.GetArray(i, a, sizeof(a));

		if (a.m_pAttributeValue == rawValue) {
			return true;
		}
	}
	return false;
}

stock bool Is64Bit() {
	return Address_PointerSize == view_as<Address>(8);
}

stock void Address_ToIntArray(Address addr, int arr[2]) {
	arr[0] = view_as<int>(addr);
	arr[1] = view_as<int>(addr >> 32);
}

stock Address IntArray_ToAddress(const int arr[2]) {
	Address low = view_as<Address>(arr[0]) & ((view_as<Address>(1) << 32) - view_as<Address>(1));
	return low | (view_as<Address>(arr[1]) << 32);
}

stock Address GetNativeAddress(int param) {
	int arr[2];
	GetNativeArray(param, arr, 2);
	return IntArray_ToAddress(arr);
}

stock int SetNativeReturnAddress(Address value) {
	int arr[2];
	Address_ToIntArray(value, arr);
	SetNativeArray(1, arr, 2);
	return view_as<int>(value);
}

stock bool StringMap_GetAddress(StringMap map, const char[] key, Address &value) {
	int arr[2];
	bool ok = map.GetArray(key, arr, 2);
	if (ok) value = IntArray_ToAddress(arr);
	return ok;
}

stock void StringMap_SetAddress(StringMap map, const char[] key, Address value) {
	int arr[2];
	Address_ToIntArray(value, arr);
	map.SetArray(key, arr, 2);
}

/**
 * Inserts a string into the game's string pool.  This uses the same implementation that is in
 * SourceMod's core:
 *
 * https://github.com/alliedmodders/sourcemod/blob/b14c18ee64fc822dd6b0f5baea87226d59707d5a/core/HalfLife2.cpp#L1415-L1423
 */
stock Address AllocPooledString(const char[] value) {
	Address pValue;
	if (StringMap_GetAddress(g_AllocPooledStringCache, value, pValue)) {
		return pValue;
	}

	int ent = FindEntityByClassname(-1, "worldspawn");
	if (!IsValidEntity(ent)) {
		return Address_Null;
	}
	int offset = FindDataMapInfo(ent, "m_iName");
	if (offset <= 0) {
		return Address_Null;
	}

	Address pEntity_m_iName = GetEntityAddress(ent) + view_as<Address>(offset);

	Address pOrig = LoadAddressFromAddress(pEntity_m_iName);
	DispatchKeyValue(ent, "targetname", value);
	pValue = LoadAddressFromAddress(pEntity_m_iName);
	StoreAddressToAddress(pEntity_m_iName, pOrig);

	StringMap_SetAddress(g_AllocPooledStringCache, value, pValue);
	return pValue;
}

stock int LoadStringFromAddress(Address addr, char[] buffer, int maxlen, bool &bIsNullPointer = false) {
	if (!addr) {
		bIsNullPointer = true;
		return 0;
	}

	int c;
	char ch;
	do {
		ch = view_as<int>(LoadFromAddress(addr + view_as<Address>(c), NumberType_Int8));
		buffer[c] = ch;
	} while (ch && ++c < maxlen - 1);
	return c;
}

/**
 * Runtime assertion that we're receiving valid addresses.
 * If we're not, something has gone terribly wrong and we might need to update.
 */
void AssertValidAddress(Address pAddress) {
	if (pAddress == Address_Null) {
		ThrowError("Received invalid address (NULL)");
	}
}

/*
struct CEconItemAttributeDefinition
{
	WORD index,						//4
	WORD blank,
	DWORD type,						//8
	BYTE hidden,					//12
	BYTE force_output_description,	//13
	BYTE stored_as_integer,			//14
	BYTE instance_data,				//15
	BYTE is_set_bonus,				//16
	BYTE blank,
	BYTE blank,
	BYTE blank,
	DWORD is_user_generated,		//20
	DWORD effect_type,				//24
	DWORD description_format,		//28
	DWORD description_string,		//32
	DWORD armory_desc,				//36
	DWORD name,						//40
	DWORD attribute_class,			//44
	BYTE can_affect_market_name,	//48
	BYTE can_affect_recipe_component_name,	//49
	BYTE blank,
	BYTE blank,
	DWORD apply_tag_to_item_definition,	//52
	DWORD unknown

};*/
/*class CEconItemAttribute
{
public:
	void *m_pVTable; //0

	uint16 m_iAttributeDefinitionIndex; //4
	float m_flValue; //8
	int32 m_nRefundableCurrency; //12
-----removed	float m_flInitialValue; //12
-----removed	bool m_bSetBonus; //20
};
and +24 is still attribute manager
*/
