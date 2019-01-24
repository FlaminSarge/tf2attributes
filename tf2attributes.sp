#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_NAME		"[TF2] TF2Attributes"
#define PLUGIN_AUTHOR		"FlaminSarge"
#define PLUGIN_VERSION		"1.3.3@nosoop-1.0.2"
#define PLUGIN_CONTACT		"http://forums.alliedmods.net/showthread.php?t=210221"
#define PLUGIN_DESCRIPTION	"Functions to add/get attributes for TF2 players/items"

public Plugin myinfo = {
	name		= PLUGIN_NAME,
	author		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESCRIPTION,
	version		= PLUGIN_VERSION,
	url		= PLUGIN_CONTACT
};

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
	CreateNative("TF2Attrib_IsReady", Native_IsReady);

	//unused, backcompat I guess?
	CreateNative("TF2Attrib_SetInitialValue", Native_SetInitialVal);
	CreateNative("TF2Attrib_GetInitialValue", Native_GetInitialVal);
	CreateNative("TF2Attrib_SetIsSetBonus", Native_SetSetBonus);
	CreateNative("TF2Attrib_GetIsSetBonus", Native_GetSetBonus);

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
	
	CreateConVar("tf2attributes_version", PLUGIN_VERSION, "TF2Attributes version number", FCVAR_NOTIFY);
	
	g_bPluginReady = true;
	
	delete hGameConf;
}

public int Native_IsIntegerValue(Handle plugin, int numParams) {
	int iDefIndex = GetNativeCell(1);
	switch (iDefIndex) {
		case 133, 143, 147, 152, 184, 185, 186, 192, 193, 194, 198, 211, 214, 227, 228, 229,
				262, 294, 302, 372, 373, 374, 379, 381, 383, 403, 420, 371, 500, 501, 2010,
				2011, 2021, 2023, 2024: {
			return true;
		}
	}
	return false;
}

stock int GetStaticAttribs(Address pItemDef, int[] iAttribIndices, int[] iAttribValues, int size = 16) {
	if (!IsValidAddress(pItemDef)) {
		return 0; // ...-1 maybe?
	}
	
	int iNumAttribs = LoadFromAddress(pItemDef+view_as<Address>(0x28), NumberType_Int32);
	Address pAttribList = view_as<Address>(LoadFromAddress(pItemDef+view_as<Address>(0x1C), NumberType_Int32));
	
	for (int i = 0; i < iNumAttribs && i < size; i++) {
		// THIS IS HOW YOU GET THE ATTRIBUTES ON AN ITEMDEF!
		iAttribIndices[i] = LoadFromAddress(pAttribList+view_as<Address>(i*8), NumberType_Int16);
		iAttribValues[i] = LoadFromAddress(pAttribList+view_as<Address>(i*8+4), NumberType_Int32);
	}
	return iNumAttribs;
}

public int Native_GetStaticAttribs(Handle plugin, int numParams) {
	int iItemDefIndex = GetNativeCell(1);
	int size = 16;
	if (numParams >= 4) {
		size = GetNativeCell(4);
	}
	
	if (size <= 0) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetStaticAttribs: Array size (iMaxLen=%d) must be greater than 0", size);
	}
	
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return -1;
	}
	
	Address pItemDef = SDKCall(hSDKGetItemDefinition, pSchema, iItemDefIndex);
	if (!IsValidAddress(pItemDef)) {
		return -1;
	}
	
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
	int iCEIVOffset = GetEntSendPropOffs(iEntity, "m_Item", true);
	if (iCEIVOffset <= 0) {
		return -1;
	}
	Address pEconItemView = GetEntityAddress(iEntity);
	if (!IsValidAddress(pEconItemView)) {
		return -1;
	}
	pEconItemView += view_as<Address>(iCEIVOffset);
	
	Address pEconItem = SDKCall(hSDKGetSOCData, pEconItemView);
	if (!IsValidAddress(pEconItem)) {
		return -1;
	}
	
	Address pCustomData = view_as<Address>(LoadFromAddress(pEconItem + view_as<Address>(0x34), NumberType_Int32));
	if (IsValidAddress(pCustomData)) {
		int iCount = LoadFromAddress(pCustomData + view_as<Address>(0x0C), NumberType_Int32);
		for (int i = 0; i < iCount && i < size; ++i) {
			Address pAttribDef = view_as<Address>(LoadFromAddress(pCustomData, NumberType_Int32) + (i * 8));
			Address pAttribVal = view_as<Address>(LoadFromAddress(pCustomData, NumberType_Int32) + (i * 8) + 4);
			iAttribIndices[i] = LoadFromAddress(pAttribDef, NumberType_Int16);
			iAttribValues[i] = LoadFromAddress(pAttribVal, NumberType_Int32);
		}
		return iCount;
	}
	
	//(CEconItem+0x27 & 0b100 & 0xFF) != 0
	bool hasInternalAttribute = (LoadFromAddress(pEconItem + view_as<Address>(0x27), NumberType_Int8) & 0b100) != 0;
	if (hasInternalAttribute) {
		iAttribIndices[0] = LoadFromAddress(pEconItem + view_as<Address>(0x2C), NumberType_Int16);
		iAttribValues[0] = LoadFromAddress(pEconItem + view_as<Address>(0x30), NumberType_Int32);
		return 1;
	}
	return 0;
}

public int Native_GetSOCAttribs(Handle plugin, int numParams) {
	int iEntity = GetNativeCell(1);
	int size = 16;
	if (numParams >= 4) {
		size = GetNativeCell(4);
	}
	
	if (size <= 0) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetSOCAttribs: Array size (iMaxLen=%d) must be greater than 0", size);
	}
	
	if (!IsValidEntity(iEntity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetSOCAttribs: Invalid entity (iEntity=%d) passed", iEntity);
	}
	
	//maybe move some address stuff to here from the stock, but for now it's okay
	int[] iAttribIndices = new int[size]; int[] iAttribValues = new int[size];
	int iCount = GetSOCAttribs(iEntity, iAttribIndices, iAttribValues, size);
	SetNativeArray(2, iAttribIndices, size);
	SetNativeArray(3, iAttribValues, size);	//cast to float on inc side
	return iCount;
}

public int Native_SetAttrib(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByName: Invalid entity (iEntity=%d) passed", entity);
	}
	
	char strAttrib[128];	//"counts as assister is some kind of pet this update is going to be awesome" is 73 characters. Valve... Valve.
	GetNativeString(2, strAttrib, sizeof(strAttrib));
	float flVal = GetNativeCell(3);
	
	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return false;
	}
	
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return false;
	}
	
	Address pAttribDef = SDKCall(hSDKGetAttributeDefByName, pSchema, strAttrib);
	if (!IsValidAddress(pAttribDef)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByName: Attribute '%s' not valid", strAttrib);
	}
	
	SDKCall(hSDKSetRuntimeValue, pEntAttributeList, pAttribDef, flVal);
	return true;
}

public int Native_SetAttribByID(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByDefIndex: Invalid entity (iEntity=%d) passed", entity);
	}
	
	int iAttrib = GetNativeCell(2);
	float flVal = GetNativeCell(3);
	
	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return false;
	}
	
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return false;
	}
	
	Address pAttribDef = SDKCall(hSDKGetAttributeDef, pSchema, iAttrib);
	if (!IsValidAddress(pAttribDef)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByDefIndex: Attribute %d not valid", iAttrib);
	}
	
	SDKCall(hSDKSetRuntimeValue, pEntAttributeList, pAttribDef, flVal);
	return true;
}

public int Native_GetAttrib(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetByName: Invalid entity (iEntity=%d) passed", entity);
	}
	
	char strAttrib[128];
	GetNativeString(2, strAttrib, sizeof(strAttrib));
	
	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return 0;
	}
	
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return 0;
	}
	
	Address pAttribDef = SDKCall(hSDKGetAttributeDefByName, pSchema, strAttrib);
	if (!IsValidAddress(pAttribDef)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetByName: Attribute '%s' not valid", strAttrib);
	}
	
	int iDefIndex = LoadFromAddress(pAttribDef + view_as<Address>(4), NumberType_Int16);
	Address pAttrib = SDKCall(hSDKGetAttributeByID, pEntAttributeList, iDefIndex);
	
	return (!IsValidAddress(pAttrib) ? 0 : view_as<int>(pAttrib));
}

public int Native_GetAttribByID(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetByDefIndex: Invalid entity (iEntity=%d) passed", entity);
	}
	
	int iDefIndex = GetNativeCell(2);
	
	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return 0;
	}
	
	Address pAttrib = SDKCall(hSDKGetAttributeByID, pEntAttributeList, iDefIndex);
	return (!IsValidAddress(pAttrib) ? 0 : view_as<int>(pAttrib));
}

public int Native_Remove(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveByName: Invalid entity (iEntity=%d) passed", entity);
		return false;
	}
	
	char strAttrib[128];
	GetNativeString(2, strAttrib, sizeof(strAttrib));

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return false;
	}
	
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return false;
	}
	
	Address pAttribDef = SDKCall(hSDKGetAttributeDefByName, pSchema, strAttrib);
	if (!IsValidAddress(pAttribDef)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveByName: Attribute '%s' not valid", strAttrib);
	}
	
	SDKCall(hSDKRemoveAttribute, pEntAttributeList, pAttribDef);	//Not a clue what the return is here, but it's probably a clone of the attrib being removed
	return true;
}

public int Native_RemoveByID(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveByDefIndex: Invalid entity (iEntity=%d) passed", entity);
		return false;
	}
	
	int iAttrib = GetNativeCell(2);

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return false;
	}
	
	Address pSchema = GetItemSchema();
	if (!pSchema) {
		return false;
	}

	Address pAttribDef = SDKCall(hSDKGetAttributeDef, pSchema, iAttrib);
	if (!IsValidAddress(pAttribDef)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveByDefIndex: Attribute %d not valid", iAttrib);
	}
	
	SDKCall(hSDKRemoveAttribute, pEntAttributeList, pAttribDef);	//Not a clue what the return is here, but it's probably a clone of the attrib being removed
	return true;
}

public int Native_RemoveAll(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveAll: Invalid entity (iEntity=%d) passed", entity);
		return false;
	}

	Address pEntAttributeList = GetEntityAttributeList(entity);
	if (!pEntAttributeList) {
		return false;
	}
	
	SDKCall(hSDKDestroyAllAttributes, pEntAttributeList);	//disregard the return (Valve does!)
	return true;
}

public int Native_SetID(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	int iDefIndex = GetNativeCell(2);
	StoreToAddress(pAttrib+view_as<Address>(4), iDefIndex, NumberType_Int16);
}

public int Native_GetID(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	return LoadFromAddress(pAttrib+view_as<Address>(4), NumberType_Int16);
}

public int Native_SetVal(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	int flVal = GetNativeCell(2);	//It's a float but avoiding tag mismatch warnings from StoreToAddress
	StoreToAddress(pAttrib+view_as<Address>(8), flVal, NumberType_Int32);
}

public int Native_GetVal(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	return LoadFromAddress(pAttrib+view_as<Address>(8), NumberType_Int32);
}

public int Native_SetInitialVal(Handle plugin, int numParams) {
	return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetInitialValue: m_flInitialValue is no longer present on attributes");
}

public int Native_GetInitialVal(Handle plugin, int numParams) {
	return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetInitialValue: m_flInitialValue is no longer present on attributes");
}

public int Native_SetCurrency(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	int nCurrency = GetNativeCell(2);
	StoreToAddress(pAttrib+view_as<Address>(12), nCurrency, NumberType_Int32);
}

public int Native_GetCurrency(Handle plugin, int numParams) {
	Address pAttrib = GetNativeCell(1);
	return LoadFromAddress(pAttrib+view_as<Address>(12), NumberType_Int32);
}

public int Native_SetSetBonus(Handle plugin, int numParams) {
	return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetIsSetBonus: m_bSetBonus is no longer present on attributes");
}

public int Native_GetSetBonus(Handle plugin, int numParams) {
	return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetIsSetBonus: m_bSetBonus is no longer present on attributes");
}

stock bool ClearAttributeCache(int entity) {
	if (entity <= 0 || !IsValidEntity(entity)) {
		return false;
	}
	
	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0) {
		return false;
	}
	
	Address pAttribs = GetEntityAddress(entity);
	pAttribs = view_as<Address>(LoadFromAddress(pAttribs+view_as<Address>(offs+24), NumberType_Int32));	//AttributeManager
	if (!IsValidAddress(pAttribs)) {
		return false;
	}
	
	SDKCall(hSDKOnAttribValuesChanged, pAttribs);
	return true;
}

public int Native_ClearCache(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity)) {
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_ClearCache: Invalid entity (iEntity=%d) passed", entity);
		return false;
	}
	return ClearAttributeCache(entity);
}

public int Native_ListIDs(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	int size = 20;
	if (numParams >= 3) {
		size = GetNativeCell(3);
	}
	
	if (size <= 0) {
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_ListDefIndices: Array size (iMaxLen=%d) must be greater than 0", size);
		return -1;
	}
	
	if (!IsValidEntity(entity)) {
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_ListDefIndices: Invalid entity (iEntity=%d) passed", entity);
		return -1;
	}
	
	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0) {
		return -1;
	}
	
	Address pEntity = GetEntityAddress(entity);
	Address pAttribList = view_as<Address>(LoadFromAddress(pEntity+view_as<Address>(offs+4), NumberType_Int32));
	if (!IsValidAddress(pAttribList)) {
		return -1;
	}
	
	int iNumAttribs = LoadFromAddress(pEntity+view_as<Address>(offs+16), NumberType_Int32);
	int[] iAttribIndices = new int[size];
	for (int i = 0; i < iNumAttribs && i < size; i++) {
		// THIS IS HOW YOU GET THE ATTRIBUTES ON AN ITEM!
		iAttribIndices[i] = LoadFromAddress(pAttribList+view_as<Address>(i*16+4), NumberType_Int16);
	}
	SetNativeArray(2, iAttribIndices, size);
	return iNumAttribs;
}

static Address GetItemSchema() {
	return SDKCall(hSDKSchema);
}

static Address GetEntityAttributeList(int entity) {
	int offsAttributeList = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offsAttributeList > 0) {
		return GetEntityAddress(entity) + view_as<Address>(offsAttributeList);
	}
	return Address_Null;
}

//TODO Stop using Address_MinimumValid once verified that logic still works without it
stock bool IsValidAddress(Address pAddress) {
	static Address Address_MinimumValid = view_as<Address>(0x10000);
	if (pAddress == Address_Null) {
		return false;
	}
	return unsigned_compare(view_as<int>(pAddress), view_as<int>(Address_MinimumValid)) >= 0;
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
