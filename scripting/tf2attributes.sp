#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_NAME		"[TF2] TF2Attributes"
#define PLUGIN_AUTHOR		"FlaminSarge"
#define PLUGIN_VERSION		"1.3.3@nosoop-1.6.0"
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
	CreateNative("TF2Attrib_GetByName", Native_GetAttrib);
	CreateNative("TF2Attrib_GetByDefIndex", Native_GetAttribByID);
	CreateNative("TF2Attrib_RemoveByName", Native_Remove);
	CreateNative("TF2Attrib_RemoveByDefIndex", Native_RemoveByID);
	CreateNative("TF2Attrib_RemoveAll", Native_RemoveAll);
	CreateNative("TF2Attrib_SetDefIndex", Native_SetID);
	CreateNative("TF2Attrib_GetDefIndex", Native_GetID);
	CreateNative("TF2Attrib_SetValue", Native_SetVal);
	CreateNative("TF2Attrib_GetValue", Native_GetVal);
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
		SetFailState("Could not initialize call to CTFPlayer::AddCustomAttribute");
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
	
	CreateConVar("tf2attributes_version", PLUGIN_VERSION, "TF2Attributes version number", FCVAR_NOTIFY);
	
	g_bPluginReady = true;
	
	delete hGameConf;
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

stock int GetStaticAttribs(Address pItemDef, int[] iAttribIndices, int[] iAttribValues, int size = 16) {
	AssertValidAddress(pItemDef);
	
	// 0x1C = CEconItemDefinition.m_Attributes (type CUtlVector<static_attrib_t>)
	// 0x1C = (...) m_Attributes.m_Memory.m_pMemory (m_Attributes + 0x00)
	// 0x28 = (...) m_Attributes.m_Size (m_Attributes + 0x0C)
	int iNumAttribs = LoadFromAddressOffset(pItemDef, 0x28, NumberType_Int32);
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

stock int GetSOCAttribs(int iEntity, int[] iAttribIndices, int[] iAttribValues, int size = 16) {
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
}

/* native float TF2Attrib_GetValue(Address pAttrib); */
public int Native_GetVal(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	return LoadFromAddressOffset(pAttrib, 0x08, NumberType_Int32);
}

/* native void TF2Attrib_SetRefundableCurrency(Address pAttrib, int nCurrency); */
public int Native_SetCurrency(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	int nCurrency = GetNativeCell(2);
	StoreToAddressOffset(pAttrib, 0x0C, nCurrency, NumberType_Int32);
}

/* native int TF2Attrib_GetRefundableCurrency(Address pAttrib); */
public int Native_GetCurrency(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	return LoadFromAddressOffset(pAttrib, 0x0C, NumberType_Int32);
}

public int Native_DeprecatedPropertyAccess(Handle plugin, int numParams) {
	return ThrowNativeError(SP_ERROR_NATIVE, "Property associated with native function no longer exists");
}

stock bool ClearAttributeCache(int entity) {
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
	
	// 0x04 = CAttributeList.m_Attributes (type CUtlVector<CEconItemAttribute>)
	// 0x04 = CAttributeList.m_Attributes.m_Memory.m_pMemory
	Address pAttribListData = DereferencePointer(pAttributeList, .offset = 0x04);
	AssertValidAddress(pAttribListData);
	
	// 0x10 = CAttributeList.m_Attributes.m_Size (m_Attributes + 0x0C)
	int iNumAttribs = LoadFromAddressOffset(pAttributeList, 0x10, NumberType_Int32);
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
	float flValue = GetNativeCell(3);
	float flDuration = GetNativeCell(4);
	
	SDKCall(hSDKAddCustomAttribute, client, strAttrib, flValue, flDuration);
	return;
}

public int Native_RemoveCustomAttribute(Handle plugin, int numParams) {
	char strAttrib[MAX_ATTRIBUTE_NAME_LENGTH];
	
	int client = GetNativeCell(1);
	GetNativeString(2, strAttrib, sizeof(strAttrib));
	
	SDKCall(hSDKRemoveCustomAttribute, client, strAttrib);
	return;
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

static Address GetEntityAttributeList(int entity) {
	int offsAttributeList = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offsAttributeList > 0) {
		return GetEntityAddress(entity) + view_as<Address>(offsAttributeList);
	}
	return Address_Null;
}

static Address GetAttributeDefinitionByName(const char[] name) {
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return Address_Null;
	}
	return SDKCall(hSDKGetAttributeDefByName, pSchema, name);
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

stock int LoadFromAddressOffset(Address addr, int offset, NumberType size) {
	return LoadFromAddress(addr + view_as<Address>(offset), size);
}

stock void StoreToAddressOffset(Address addr, int offset, int data, NumberType size) {
	StoreToAddress(addr + view_as<Address>(offset), data, size);
}

stock Address DereferencePointer(Address addr, int offset = 0) {
	return view_as<Address>(LoadFromAddressOffset(addr, offset, NumberType_Int32));
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
