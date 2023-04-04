#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_NAME		"[TF2] TF2Attributes"
#define PLUGIN_AUTHOR		"FlaminSarge"
#define PLUGIN_VERSION		"1.7.3"
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
Handle hSDKAttributeApplyStringWrapperWindows;
Handle hSDKAttributeApplyStringWrapperLinux;

Handle hSDKAttributeValueInitialize;
Handle hSDKAttributeTypeCanBeNetworked;
Handle hSDKAttributeValueFromString;
Handle hSDKAttributeValueUnload;
Handle hSDKAttributeValueUnloadByRef;
Handle hSDKCopyStringAttributeToCharPointer;

// caches attribute name to definition instance
StringMap g_AttributeDefinitionMapping;

// caches string_t instances from AllocPooledString
StringMap g_AllocPooledStringCache;

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
	Handle hGameConf = LoadGameConfigFile("tf2.attributes");
	if (!hGameConf) {
		SetFailState("Could not locate gamedata file tf2.attributes.txt for TF2Attributes, pausing plugin");
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetItemDefinition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of CEconItemDefinition
	hSDKGetItemDefinition = EndPrepSDKCall();
	if (!hSDKGetItemDefinition) {
		SetFailState("Could not initialize call to CEconItemSchema::GetItemDefinition");
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemView::GetSOCData");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of CEconItem
	hSDKGetSOCData = EndPrepSDKCall();
	if (!hSDKGetSOCData) {
		SetFailState("Could not initialize call to CEconItemView::GetSOCData");
	}
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GEconItemSchema");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of CEconItemSchema
	hSDKSchema = EndPrepSDKCall();
	if (!hSDKSchema) {
		SetFailState("Could not initialize call to GEconItemSchema");
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of a CEconItemAttributeDefinition
	hSDKGetAttributeDef = EndPrepSDKCall();
	if (!hSDKGetAttributeDef) {
		SetFailState("Could not initialize call to CEconItemSchema::GetAttributeDefinition");
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinitionByName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of a CEconItemAttributeDefinition
	hSDKGetAttributeDefByName = EndPrepSDKCall();
	if (!hSDKGetAttributeDefByName) {
		SetFailState("Could not initialize call to CEconItemSchema::GetAttributeDefinitionByName");
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::RemoveAttribute");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//not a clue what this return is
	hSDKRemoveAttribute = EndPrepSDKCall();
	if (!hSDKRemoveAttribute) {
		SetFailState("Could not initialize call to CAttributeList::RemoveAttribute");
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::SetRuntimeAttributeValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	//PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
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
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	hSDKDestroyAllAttributes = EndPrepSDKCall();
	if (!hSDKDestroyAllAttributes) {
		SetFailState("Could not initialize call to CAttributeList::DestroyAllAttributes");
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::GetAttributeByID");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of a CEconItemAttribute
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
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	hSDKAddCustomAttribute = EndPrepSDKCall();
	if (!hSDKAddCustomAttribute) {
		SetFailState("Could not initialize call to CTFPlayer::AddCustomAttribute");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTFPlayer::RemoveCustomAttribute");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	hSDKRemoveCustomAttribute = EndPrepSDKCall();
	if (!hSDKRemoveCustomAttribute) {
		SetFailState("Could not initialize call to CTFPlayer::RemoveCustomAttribute");
	}
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeManager::AttribHookValue<float>");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain); // initial value
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); // attribute class
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // CBaseEntity* entity
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CUtlVector<CBaseEntity*>, set to nullptr
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); // bool const_string
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
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CUtlVector<CBaseEntity*>, set to nullptr
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); // bool const_string
	hSDKAttributeHookInt = EndPrepSDKCall();
	if (!hSDKAttributeHookInt) {
		SetFailState("Could not initialize call to CAttributeManager::AttribHookValue<int>");
	}
	
	// linux signature. this uses a hidden pointer passed in before `this` on the stack
	// so we'll do our best with static since SM doesn't support that calling convention
	// no subclasses override this virtual function so we'll just call it directly
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeManager::ApplyAttributeStringWrapper");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // return string_t
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer); // return value
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // thisptr
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // string_t initial value
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // initator entity (should contain thisptr)
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // string_t attribute class
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CUtlVector<CBaseEntity*>, set to nullptr
	hSDKAttributeApplyStringWrapperLinux = EndPrepSDKCall();
	
	if (!hSDKAttributeApplyStringWrapperLinux) {
		// windows vcall. this one also uses a hidden pointer, but it's passed as the first param
		// `this` remains unchanged so we can still use a vcall
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CAttributeManager::ApplyAttributeStringWrapper");
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // return string_t
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer); // return value too
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // string_t initial value
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer); // CBaseEntity* entity
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // string_t attribute class
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CUtlVector<CBaseEntity*>, set to nullptr
		hSDKAttributeApplyStringWrapperWindows = EndPrepSDKCall();
	}
	
	if (!hSDKAttributeApplyStringWrapperWindows && !hSDKAttributeApplyStringWrapperLinux) {
		SetFailState("Could not initialize call to CAttributeManager::ApplyAttributeStringWrapper");
	}
	
	StartPrepSDKCall(SDKCall_Raw); // CEconItemAttribute*
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISchemaAttributeTypeBase::InitializeNewEconAttributeValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, .encflags = VENCODE_FLAG_COPYBACK); // CAttributeDefinition*
	hSDKAttributeValueInitialize = EndPrepSDKCall();
	if (!hSDKAttributeValueInitialize) {
		SetFailState("Could not initialize call to ISchemaAttributeTypeBase::InitializeNewEconAttributeValue");
	}
	
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
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, .encflags = VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	hSDKAttributeValueFromString = EndPrepSDKCall();
	if (!hSDKAttributeValueFromString) {
		SetFailState("Could not initialize call to ISchemaAttributeTypeBase::BConvertStringToEconAttributeValue");
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISchemaAttributeTypeBase::UnloadEconAttributeValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	hSDKAttributeValueUnload = EndPrepSDKCall();
	if (!hSDKAttributeValueUnload) {
		SetFailState("Could not initialize call to ISchemaAttributeTypeBase::UnloadEconAttributeValue");
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISchemaAttributeTypeBase::UnloadEconAttributeValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);
	hSDKAttributeValueUnloadByRef = EndPrepSDKCall();
	if (!hSDKAttributeValueUnloadByRef) {
		SetFailState("Could not initialize call to ISchemaAttributeTypeBase::UnloadEconAttributeValue");
	}
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"CopyStringAttributeValueToCharPointerOutput");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL, VENCODE_FLAG_COPYBACK); // char**, variable contains char* on return
	hSDKCopyStringAttributeToCharPointer = EndPrepSDKCall();
	if (!hSDKCopyStringAttributeToCharPointer) {
		SetFailState("Could not initialize call to CopyStringAttributeValueToCharPointerOutput");
	}
	
	CreateConVar("tf2attributes_version", PLUGIN_VERSION, "TF2Attributes version number", FCVAR_NOTIFY);
	
	g_bPluginReady = true;
	
	delete hGameConf;
	
	g_ManagedAllocatedValues = new ArrayList(sizeof(HeapAttributeValue));
	g_AttributeDefinitionMapping = new StringMap();
	
	g_AllocPooledStringCache = new StringMap();
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
	
	return LoadFromAddressOffset(pEconItemAttributeDefinition, 0x0E, NumberType_Int8);
}

static int GetStaticAttribs(Address pItemDef, int[] iAttribIndices, int[] iAttribValues, int size = 16) {
	AssertValidAddress(pItemDef);
	
	// 0x1C = CEconItemDefinition.m_Attributes (type CUtlVector<static_attrib_t>)
	// 0x1C = (...) m_Attributes.m_Memory.m_pMemory (m_Attributes + 0x00)
	// 0x28 = (...) m_Attributes.m_Size (m_Attributes + 0x0C)
	int iNumAttribs = LoadFromAddressOffset(pItemDef, 0x28, NumberType_Int32);
	if (!iNumAttribs) {
		return 0;
	}
	
	Address pAttribList = DereferencePointer(pItemDef, .offset = 0x1C);
	
	// Read static_attrib_t (size 0x08) entries from contiguous block of memory
	for (int i = 0; i < iNumAttribs && i < size; i++) {
		Address pStaticAttrib = pAttribList + view_as<Address>(i * 0x08);
		iAttribIndices[i] = LoadFromAddress(pStaticAttrib, NumberType_Int16);
		iAttribValues[i] = LoadFromAddressOffset(pStaticAttrib, 0x04, NumberType_Int32);
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
	
	Address pItemDef = SDKCall(hSDKGetItemDefinition, pSchema, iItemDefIndex);
	AssertValidAddress(pItemDef);
	
	int[] iAttribIndices = new int[size]; int[] iAttribValues = new int[size];
	int iCount = GetStaticAttribs(pItemDef, iAttribIndices, iAttribValues, size);
	SetNativeArray(2, iAttribIndices, size);
	SetNativeArray(3, iAttribValues, size);	//cast to float on inc side
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
	Address pEconItem = SDKCall(hSDKGetSOCData, pEconItemView);
	if (!pEconItem) {
		return 0;
	}
	
	// 0x34 = CEconItem.m_pAttributes (type CUtlVector<static_attrib_t>*, possibly null)
	Address pCustomData = DereferencePointer(pEconItem, .offset = 0x34);
	if (pCustomData) {
		AssertValidAddress(pCustomData);
		
		// 0x0C = (...) m_pAttributes->m_Size (m_pAttributes + 0x0C)
		// 0x00 = (...) m_pAttributes->m_Memory.m_pMemory (m_pAttributes + 0x00)
		int iCount = LoadFromAddressOffset(pCustomData, 0x0C, NumberType_Int32);
		if (!iCount) {
			// abort early if the attribute list is empty -- we might deref garbage otherwise
			return 0;
		}
		
		Address pCustomDataArray = DereferencePointer(pCustomData);
		
		// Read static_attrib_t (size 0x08) entries from contiguous block of memory
		for (int i = 0; i < iCount && i < size; ++i) {
			Address pSOCAttribEntry = pCustomDataArray + view_as<Address>(i * 0x08);
			
			iAttribIndices[i] = LoadFromAddress(pSOCAttribEntry, NumberType_Int16);
			iAttribValues[i] = LoadFromAddressOffset(pSOCAttribEntry, 0x04, NumberType_Int32);
		}
		return iCount;
	}
	
	//(CEconItem+0x27 & 0b100 & 0xFF) != 0
	bool hasInternalAttribute = !!(LoadFromAddressOffset(pEconItem, 0x27, NumberType_Int8) & 0b100);
	if (hasInternalAttribute) {
		iAttribIndices[0] = LoadFromAddressOffset(pEconItem, 0x2C, NumberType_Int16);
		iAttribValues[0] = LoadFromAddressOffset(pEconItem, 0x30, NumberType_Int32);
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
	
	//maybe move some address stuff to here from the stock, but for now it's okay
	int[] iAttribIndices = new int[size]; int[] iAttribValues = new int[size];
	int iCount = GetSOCAttribs(iEntity, iAttribIndices, iAttribValues, size);
	SetNativeArray(2, iAttribIndices, size);
	SetNativeArray(3, iAttribValues, size);	//cast to float on inc side
	return iCount;
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
	
	// allocate a CEconItemAttribute instance in an entity's runtime attribute list
	if (!InitializeAttributeValue(pEntAttributeList, attrdef, strAttribVal)) {
		return false;
	}
	return true;
}

/* native Address TF2Attrib_GetByName(int iEntity, char[] strAttrib); */
public int Native_GetAttrib(Handle plugin, int numParams) {
	// There is a CAttributeList::GetByName, wonder why this is being done instead...
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
	
	int iDefIndex;
	if (!GetAttributeDefIndexByName(strAttrib, iDefIndex)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Attribute name '%s' is invalid", strAttrib);
	}
	return SDKCall(hSDKGetAttributeByID, pEntAttributeList, iDefIndex);
}

/* native Address TF2Attrib_GetByDefIndex(int iEntity, int iDefIndex); */
public int Native_GetAttribByID(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d (%d) is invalid", EntIndexToEntRef(entity), entity);
	}
	
	int iDefIndex = GetNativeCell(2);
	
	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return 0;
	}
	
	return SDKCall(hSDKGetAttributeByID, pEntAttributeList, iDefIndex);
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
	Address pAttrib = GetNativeCell(1);
	int iDefIndex = GetNativeCell(2);
	StoreToAddressOffset(pAttrib, 0x04, iDefIndex, NumberType_Int16);
	return iDefIndex;
}

/* native int TF2Attrib_GetDefIndex(Address pAttrib); */
public int Native_GetID(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	return LoadFromAddressOffset(pAttrib, 0x04, NumberType_Int16);
}

/* native void TF2Attrib_SetValue(Address pAttrib, float flValue); */
public int Native_SetVal(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	int flVal = GetNativeCell(2);	//It's a float but avoiding tag mismatch warnings from StoreToAddress
	StoreToAddressOffset(pAttrib, 0x08, flVal, NumberType_Int32);
	return flVal;
}

/* native float TF2Attrib_GetValue(Address pAttrib); */
public int Native_GetVal(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	return LoadFromAddressOffset(pAttrib, 0x08, NumberType_Int32);
}

/* TF2Attrib_UnsafeGetStringValue(any pRawValue, char[] buffer, int maxlen); */
public int Native_GetStringVal(Handle plugin, int numParams) {
	Address pRawValue = GetNativeCell(1);
	
	int maxlen = GetNativeCell(3), length;
	char[] buffer = new char[maxlen];
	
	ReadStringAttributeValue(pRawValue, buffer, maxlen);
	SetNativeString(2, buffer, maxlen, .bytes = length);
	return length;
}

/* native void TF2Attrib_SetRefundableCurrency(Address pAttrib, int nCurrency); */
public int Native_SetCurrency(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	int nCurrency = GetNativeCell(2);
	StoreToAddressOffset(pAttrib, 0x0C, nCurrency, NumberType_Int32);
	return nCurrency;
}

/* native int TF2Attrib_GetRefundableCurrency(Address pAttrib); */
public int Native_GetCurrency(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	return LoadFromAddressOffset(pAttrib, 0x0C, NumberType_Int32);
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
	int iNumAttribs = LoadFromAddressOffset(pAttributeList, 0x10, NumberType_Int32);
	if (!iNumAttribs) {
		return 0;
	}
	
	// 0x04 = CAttributeList.m_Attributes (type CUtlVector<CEconItemAttribute>)
	// 0x04 = CAttributeList.m_Attributes.m_Memory.m_pMemory
	Address pAttribListData = DereferencePointer(pAttributeList, .offset = 0x04);
	AssertValidAddress(pAttribListData);
	
	int[] iAttribIndices = new int[size];
	
	// Read CEconItemAttribute (size 0x10) entries from contiguous block of memory
	for (int i = 0; i < iNumAttribs && i < size; i++) {
		Address pAttributeEntry = pAttribListData + view_as<Address>(i * 0x10);
		iAttribIndices[i] = LoadFromAddressOffset(pAttributeEntry, 0x04, NumberType_Int16);
	}
	SetNativeArray(2, iAttribIndices, size);
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

/* native void TF2Attrib_HookValueString(const char[] initial, const char[] attrClass,
		int iEntity, char[] buffer, int maxlen); */
public int Native_HookValueString(Handle plugin, int numParams) {
	int buflen;
	
	GetNativeStringLength(1, buflen);
	char[] inputValue = new char[++buflen];
	GetNativeString(1, inputValue, buflen);
	
	GetNativeStringLength(2, buflen);
	char[] attrClass = new char[++buflen];
	GetNativeString(2, attrClass, buflen);
	
	int entity = GetNativeCell(3);
	
	// string needs to be pooled for caching purposes
	Address pInput = AllocPooledString(inputValue);
	Address pAttrClass = AllocPooledString(attrClass);
	
	buflen = GetNativeCell(5);
	char[] output = new char[buflen];
	
	Address pOutput;
	if (hSDKAttributeApplyStringWrapperWindows) {
		// windows version; hidden ptr pushes params, `this` still in correct register
		Address result;
		pOutput = SDKCall(hSDKAttributeApplyStringWrapperWindows,
				GetEntityAttributeManager(entity), result, pInput, entity, pAttrClass,
				Address_Null);
	} else if (hSDKAttributeApplyStringWrapperLinux) {
		// linux version; hidden ptr moves the stack and this forward
		Address result;
		pOutput = SDKCall(hSDKAttributeApplyStringWrapperLinux, result,
				GetEntityAttributeManager(entity), pInput, entity, pAttrClass, Address_Null);
	}
	
	// read from the output string_t
	LoadStringFromAddress(DereferencePointer(pOutput), output, buflen);
	
	int written;
	SetNativeString(4, output, buflen, .bytes = written);
	return written;
}

/* helper functions */

static Address GetItemSchema() {
	return SDKCall(hSDKSchema);
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
	if (g_AttributeDefinitionMapping.GetValue(name, cachedResult)) {
		return cachedResult;
	}
	
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return Address_Null;
	}
	cachedResult = SDKCall(hSDKGetAttributeDefByName, pSchema, name);
	g_AttributeDefinitionMapping.SetValue(name, cachedResult);
	return cachedResult;
}

static Address GetAttributeDefinitionByID(int id) {
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return Address_Null;
	}
	return SDKCall(hSDKGetAttributeDef, pSchema, id);
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
	
	iDefIndex = LoadFromAddressOffset(pAttribDef, 0x04, NumberType_Int16);
	return true;
}

static Address GetEntityAttributeManager(int entity) {
	Address pAttributeList = GetEntityAttributeList(entity);
	if (!pAttributeList) {
		return Address_Null;
	}
	
	Address pAttributeManager = DereferencePointer(pAttributeList, .offset = 0x18);
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
	if (!pAttrDef) {
		return false;
	}
	
	Address pDefType = DereferencePointer(pAttrDef + view_as<Address>(0x08));

	bool networked = IsNetworkedRuntimeAttribute(pDefType);
	
	if (!networked) {
		// reusing any existing matching attribute value strings
		Address rawAttributeValue = GetHeapManagedAttributeString(attrdef, value);
		if (rawAttributeValue) {
			SDKCall(hSDKSetRuntimeValue, pAttributeList, pAttrDef, view_as<float>(rawAttributeValue));
			return true;
		}
	}
	
	// since attribute value is a union of 32 bit types, this is okay
	int attributeValue = 0;

	/**
	 * initialize raw value; any existing values present in the CEconItemAttribute* are trashed
	 * 
	 * that is okay -- tf2attributes is the only one managing heap-allocated values, and
	 * it holds its own reference to the value for freeing later
	 * 
	 * we don't attempt to free any existing attribute value mid-game as we don't know if
	 * the value is present in multiple places (no refcounts!)
	 */
	SDKCall(hSDKAttributeValueInitialize, pDefType, attributeValue);

	if (!SDKCall(hSDKAttributeValueFromString, pDefType, pAttrDef, value, attributeValue, true)) {
		// in case AttributeValueInitialize created a pointer, unload it
		UnloadAttributeRawValue(pAttrDef, view_as<Address>(attributeValue));
		// we couldn't parse the attribute value, abort
		return false;
	}
	
	SDKCall(hSDKSetRuntimeValue, pAttributeList, pAttrDef, view_as<float>(attributeValue));

	if (!networked) {
		// add to our managed values
		// this definitely works for heap, not sure if it works for inline
		HeapAttributeValue attribute;
		attribute.m_iAttributeDefinitionIndex = attrdef;
		attribute.m_pAttributeValue = view_as<Address>(attributeValue);
		
		g_ManagedAllocatedValues.PushArray(attribute);
	}
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
 */
static bool IsNetworkedRuntimeAttribute(Address pDefType) {
	return SDKCall(hSDKAttributeTypeCanBeNetworked, pDefType);
}

/**
 * Unloads the attribute in a given CEconItemAttribute instance.
 */
#pragma unused UnloadAttributeValue
static void UnloadAttributeValue(Address pAttrDef, Address pEconItemAttribute) {
	Address pDefType = DereferencePointer(pAttrDef + view_as<Address>(0x08));
	Address pAttributeValue = pEconItemAttribute + view_as<Address>(0x08);
	
	SDKCall(hSDKAttributeValueUnload, pDefType, pAttributeValue);
}

/**
 * Unloads the given raw attribute value.
 */
static void UnloadAttributeRawValue(Address pAttrDef, Address pAttributeValue) {
	Address pAttributeDataUnion = pAttributeValue;
	Address pDefType = DereferencePointer(pAttrDef + view_as<Address>(0x08));
	SDKCall(hSDKAttributeValueUnloadByRef, pDefType, pAttributeDataUnion);
}

/**
 * Returns true if the given attribute definition index is a string.
 */
static bool IsAttributeString(int attrdef) {
	Address pAttrDef = GetAttributeDefinitionByID(attrdef);
	Address pKnownStringAttribDef = GetAttributeDefinitionByName("cosmetic taunt sound");
	return pAttrDef && pKnownStringAttribDef
			&& DereferencePointer(pAttrDef, 0x08) == DereferencePointer(pKnownStringAttribDef, 0x08);
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
		
		int iNumAttribs = LoadFromAddressOffset(pAttributeList, 0x10, NumberType_Int32);
		if (!iNumAttribs) {
			continue;
		}
		
		Address pAttribListData = DereferencePointer(pAttributeList, .offset = 0x04);
		
		// we know there are attributes; make sure our contiguous memory is valid
		AssertValidAddress(pAttribListData);
		
		for (int i = 0; i < iNumAttribs; i++) {
			Address pAttributeEntry = pAttribListData + view_as<Address>(i * 0x10);
			int attrdef = LoadFromAddressOffset(pAttributeEntry, 0x04, NumberType_Int16);
			
			Address pAttrDef = GetAttributeDefinitionByID(attrdef);
			if (!pAttrDef) {
				// this shouldn't happen, but just in case
				continue;
			}
			
			Address pDefType = DereferencePointer(pAttrDef + view_as<Address>(0x08));
			if (IsNetworkedRuntimeAttribute(pDefType)) {
				continue;
			}
			
			any rawValue = LoadFromAddressOffset(pAttributeEntry, 0x08, NumberType_Int32);
			
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

bool IsAttributeValueInHeap(any rawValue) {
	for (int i, n = g_ManagedAllocatedValues.Length; i < n; i++) {
		HeapAttributeValue a;
		g_ManagedAllocatedValues.GetArray(i, a, sizeof(a));
		
		if (a.m_pAttributeValue == rawValue) {
			return true;
		}
	}
	return false;
}

/**
 * Inserts a string into the game's string pool.  This uses the same implementation that is in
 * SourceMod's core:
 * 
 * https://github.com/alliedmodders/sourcemod/blob/b14c18ee64fc822dd6b0f5baea87226d59707d5a/core/HalfLife2.cpp#L1415-L1423
 */
stock Address AllocPooledString(const char[] value) {
	Address pValue;
	if (g_AllocPooledStringCache.GetValue(value, pValue)) {
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
	Address pOrig = view_as<Address>(GetEntData(ent, offset));
	DispatchKeyValue(ent, "targetname", value);
	pValue = view_as<Address>(GetEntData(ent, offset));
	SetEntData(ent, offset, pOrig);
	
	g_AllocPooledStringCache.SetValue(value, pValue);
	return pValue;
}

stock int LoadFromAddressOffset(Address addr, int offset, NumberType size) {
	return LoadFromAddress(addr + view_as<Address>(offset), size);
}

stock void StoreToAddressOffset(Address addr, int offset, int data, NumberType size) {
	StoreToAddress(addr + view_as<Address>(offset), data, size);
}

stock Address DereferencePointer(Address addr, int offset = 0) {
	return view_as<Address>(LoadFromAddressOffset(addr, offset, NumberType_Int32));
}

stock int LoadStringFromAddress(Address addr, char[] buffer, int maxlen,
		bool &bIsNullPointer = false) {
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
stock void AssertValidAddress(Address pAddress) {
	static Address Address_MinimumValid = view_as<Address>(0x10000);
	if (pAddress == Address_Null) {
		ThrowError("Received invalid address (NULL)");
	}
	if (unsigned_compare(view_as<int>(pAddress), view_as<int>(Address_MinimumValid)) < 0) {
		ThrowError("Received invalid address (%08x)", pAddress);
	}
}

stock int unsigned_compare(int a, int b) {
	if (a == b) {
		return 0;
	}
	if ((a >>> 31) == (b >>> 31)) {
		return ((a & 0x7FFFFFFF) > (b & 0x7FFFFFFF)) ? 1 : -1;
	}
	return ((a >>> 31) > (b >>> 31)) ? 1 : -1;
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
