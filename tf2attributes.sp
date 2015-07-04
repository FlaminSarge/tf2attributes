#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls		required

#define PLUGIN_NAME		"[TF2] TF2Attributes"
#define PLUGIN_AUTHOR		"FlaminSarge"
#define PLUGIN_VERSION		"1.2.1" //as of July 02, 2015
#define PLUGIN_CONTACT		"http://forums.alliedmods.net/showthread.php?t=210221"
#define PLUGIN_DESCRIPTION	"Functions to add/get attributes for TF2 players/items"

public Plugin myinfo = {
	name			= PLUGIN_NAME,
	author			= PLUGIN_AUTHOR,
	description		= PLUGIN_DESCRIPTION,
	version			= PLUGIN_VERSION,
	url			= PLUGIN_CONTACT
};

Handle hSDKGetItemDefinition;
Handle hSDKGetSOCData;
Handle hSDKSetCustomName;
Handle hSDKSchema;
Handle hSDKGetAttributeDef;
Handle hSDKGetAttributeDefByName;
Handle hSDKSetRuntimeValue;
Handle hSDKGetAttributeByID;
Handle hSDKGetAttributeByName;
Handle hSDKOnAttribValuesChanged;
Handle hSDKRemoveAttribute;
Handle hSDKDestroyAllAttributes;
Handle hSDKClearCache;

Handle hSDKSetOrAddAttribute;	//no longer used

//Handle hPluginReady;
bool g_bPluginReady = false;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char game[8];
	GetGameFolderName(game, sizeof(game));
	if (strncmp(game, "tf", 2, false) != 0)
	{
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
	//hPluginReady = CreateGlobalForward("TF2Attrib_Ready", ET_Ignore);

	//unused, backcompat I guess?
	CreateNative("TF2Attrib_SetInitialValue", Native_SetInitialVal);
	CreateNative("TF2Attrib_GetInitialValue", Native_GetInitialVal);
	CreateNative("TF2Attrib_SetIsSetBonus", Native_SetSetBonus);
	CreateNative("TF2Attrib_GetIsSetBonus", Native_GetSetBonus);

	RegPluginLibrary("tf2attributes");
	return APLRes_Success;
}

public int Native_IsReady(Handle plugin, int numParams)
{
	return g_bPluginReady;
}

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("tf2.attributes");
	bool bPluginReady = true;	//we don't want to set g_bPluginReady BEFORE any of the checks... do we? W/e, I never asked for this.
	if (hGameConf == INVALID_HANDLE)
	{
		SetFailState("Could not locate gamedata file tf2.attributes.txt for TF2Attributes, pausing plugin");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetItemDefinition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of CEconItemDefinition
	hSDKGetItemDefinition = EndPrepSDKCall();
	if (hSDKGetItemDefinition == INVALID_HANDLE)
	{
		LogError("Could not initialize call to CEconItemSchema::GetItemDefinition");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemView::GetSOCData");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of CEconItem
	hSDKGetSOCData = EndPrepSDKCall();
	if (hSDKGetSOCData == INVALID_HANDLE)
	{
		LogError("Could not initialize call to CEconItemView::GetSOCData");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItem::SetCustomName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of something
	hSDKSetCustomName = EndPrepSDKCall();
	if (hSDKSetCustomName == INVALID_HANDLE)
	{
		LogError("Could not initialize call to CEconItem::SetCustomName");
		//bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GEconItemSchema");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of CEconItemSchema
	hSDKSchema = EndPrepSDKCall();
	if (hSDKSchema == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to GEconItemSchema");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of a CEconItemAttributeDefinition
	hSDKGetAttributeDef = EndPrepSDKCall();
	if (hSDKGetAttributeDef == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CEconItemSchema::GetAttributeDefinition");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinitionByName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of a CEconItemAttributeDefinition
	hSDKGetAttributeDefByName = EndPrepSDKCall();
	if (hSDKGetAttributeDefByName == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CEconItemSchema::GetAttributeDefinitionByName");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::RemoveAttribute");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//not a clue what this return is
	hSDKRemoveAttribute = EndPrepSDKCall();
	if (hSDKRemoveAttribute == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CAttributeList::RemoveAttribute");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::SetRuntimeAttributeValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //Apparently there's no return, but this is nonzero if the attribute is added successfully so let's try it
	hSDKSetRuntimeValue = EndPrepSDKCall();
	if (hSDKSetRuntimeValue == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CAttributeList::SetRuntimeAttributeValue");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::DestroyAllAttributes");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	hSDKDestroyAllAttributes = EndPrepSDKCall();
	if (hSDKDestroyAllAttributes == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CAttributeList::DestroyAllAttributes");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::GetAttributeByID");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of a CEconItemAttribute
	hSDKGetAttributeByID = EndPrepSDKCall();
	if (hSDKGetAttributeByID == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CAttributeList::GetAttributeByID");
		bPluginReady = false;
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CAttributeManager::OnAttributeValuesChanged");
	hSDKOnAttribValuesChanged = EndPrepSDKCall();
	if (hSDKOnAttribValuesChanged == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CAttributeManager::OnAttributeValuesChanged");
		bPluginReady = false;
	}

	CreateConVar("tf2attributes_version", PLUGIN_VERSION, "TF2Attributes version number", FCVAR_NOTIFY|FCVAR_PLUGIN);
//	Call_StartForward(hPluginReady);
//	Call_Finish();
	g_bPluginReady = bPluginReady;	//I really never asked for this.
	return;

//Below is stuff that we'll get back to later and/or never, for now everything above this works and PLEASE IGNORE THE COMPILER WARNING.
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::GetAttributeByName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns address of a CEconItemAttribute
	hSDKGetAttributeByName = EndPrepSDKCall();
	if (hSDKGetAttributeByName == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CAttributeList::GetAttributeByName");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::SetOrAddAttributeValueByName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //Apparently there's no return, but this is nonzero if the attribute is added successfully so let's try it
	hSDKSetOrAddAttribute = EndPrepSDKCall();
	if (hSDKSetOrAddAttribute == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CAttributeList::SetOrAddAttributeValueByName");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeList::RemoveAttribute");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	hSDKRemoveAttribute = EndPrepSDKCall();
	if (hSDKRemoveAttribute == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CAttributeList::RemoveAttribute");
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAttributeManager::ClearCache");
	hSDKClearCache = EndPrepSDKCall();
	if (hSDKClearCache == INVALID_HANDLE)
	{
		SetFailState("Could not initialize call to CAttributeManager::ClearCache");
	}


}

stock bool Internal_IsIntegerValue(int iDefIndex)
{
	switch (iDefIndex)
	{
		case 133, 143, 147, 152, 184, 185, 186, 192, 193, 194, 198, 211, 214, 227, 228, 229, 262, 294, 302, 372, 373, 374, 379, 381, 383, 403, 420, 371, 500, 501, 2010, 2011, 2021, 2023, 2024:
		{
			return true;
		}
	}
	return false;
}

public int Native_IsIntegerValue(Handle plugin, int numParams)
{
	int iDefIndex = GetNativeCell(1);
	return Internal_IsIntegerValue(iDefIndex);
}

stock int GetStaticAttribs(Address pItemDef, int[] iAttribIndices, int[] iAttribValues)
{
	if (!IsValidAddress(pItemDef)) return 0;	//...-1 maybe?
	int iNumAttribs = LoadFromAddress(pItemDef + view_as<Address>(32), NumberType_Int32);
	Address pAttribList = view_as<Address>( LoadFromAddress(pItemDef + view_as<Address>(20), NumberType_Int32) );
	for (int i = 0; i < iNumAttribs; i++)	//THIS IS HOW YOU GET THE ATTRIBUTES ON AN ITEMDEF!
	{
		iAttribIndices[i] = LoadFromAddress(pAttribList + view_as<Address>(i * 8), NumberType_Int16);
		iAttribValues[i] = LoadFromAddress(pAttribList + view_as<Address>(i * 8 + 4), NumberType_Int32);
	}
	return iNumAttribs;
}

public int Native_GetStaticAttribs(Handle plugin, int numParams)
{
	int iItemDefIndex = GetNativeCell(1);
	Address pSchema = SDKCall(hSDKSchema);
	if (pSchema == Address_Null) return -1;
	if (hSDKGetItemDefinition == INVALID_HANDLE)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetStaticAttribs: Could not find call to CEconItemSchema::GetItemDefinition");
	}
	Address pItemDef = SDKCall(hSDKGetItemDefinition, pSchema, iItemDefIndex);
	if (!IsValidAddress(pItemDef)) return -1;
	int iAttribIndices[16], iAttribValues[16];
	int iCount = GetStaticAttribs(pItemDef, iAttribIndices, iAttribValues);
	SetNativeArray(2, iAttribIndices, 16);
	SetNativeArray(3, iAttribValues, 16);	//cast to float on inc side
	return iCount;
}

stock int GetSOCAttribs(int iEntity, int[] iAttribIndices, int[] iAttribValues)
{
	int iCEIVOffset = GetEntSendPropOffs(iEntity, "m_Item", true);
	if (iCEIVOffset <= 0) return -1;
	Address pEconItemView = GetEntityAddress(iEntity);
	if (!IsValidAddress(pEconItemView))
	{
		return -1;
	}
	pEconItemView += view_as<Address>(iCEIVOffset);

	Address pEconItem = SDKCall(hSDKGetSOCData, pEconItemView);
	if (!IsValidAddress(pEconItem))
	{
		return -1;
	}
	Address pCustomData = view_as<Address>( LoadFromAddress(pEconItem+view_as<Address>(44), NumberType_Int32) );
	int iCount = (LoadFromAddress(pEconItem+view_as<Address>(31), NumberType_Int8) >> 2) & 1;	//(CEconItem+31 & 4) != 0
	if (pCustomData >= Address_MinimumValid)
	{
		iCount = LoadFromAddress(pCustomData + view_as<Address>(12), NumberType_Int32);
	}
	Address pAttribDef = pEconItem+view_as<Address>(36);
	Address pAttribVal = pEconItem+view_as<Address>(40);
	for (int i = 0; i < iCount; ++i)
	{
		if (pCustomData >= Address_MinimumValid)
		{
			pAttribDef = view_as<Address>( (LoadFromAddress(pCustomData, NumberType_Int32) + 8 * i) );
			pAttribVal = view_as<Address>( (LoadFromAddress(pCustomData, NumberType_Int32) + 8 * i + 4) );
		}
		int iAttribIndex = LoadFromAddress(pAttribDef, NumberType_Int16);
		int iAttribValue = LoadFromAddress(pAttribVal, NumberType_Int32);
		iAttribIndices[i] = iAttribIndex;
		iAttribValues[i] = iAttribValue;
	}
	return iCount;
}

public int Native_GetSOCAttribs(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	if (!IsValidEntity(iEntity))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetSOCAttribs: Invalid entity index %d passed", iEntity);
	}
	if (hSDKGetSOCData == INVALID_HANDLE)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetSOCAttribs: Could not find call to CEconItemView::GetSOCData");
	}
	//maybe move some address stuff to here from the stock, but for now it's okay
	int iAttribIndices[16], iAttribValues[16];
	int iCount = GetSOCAttribs(iEntity, iAttribIndices, iAttribValues);
	SetNativeArray(2, iAttribIndices, 16);
	SetNativeArray(3, iAttribValues, 16);	//cast to float on inc side
	return iCount;
}

public int Native_SetAttrib(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByName: Invalid entity index %d passed", entity);
//		return;
	}
	char strAttrib[128];	//"counts as assister is some kind of pet this update is going to be awesome" is 73 characters. Valve... Valve.
	GetNativeString(2, strAttrib, sizeof(strAttrib));
	float flVal = GetNativeCell(3);

	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0)
	{
//		char strClassname[64];
//		if (!GetEntityClassname(entity, strClassname, sizeof(strClassname))) strClassname = "";
//		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByName: \"m_AttributeList\" not found (entity %d/%s)", entity, strClassname);
		return false;
	}
	Address pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null) return false;
	Address pSchema = SDKCall(hSDKSchema);
	if (pSchema == Address_Null) return false;
	Address pAttribDef = SDKCall(hSDKGetAttributeDefByName, pSchema, strAttrib);
	if (!IsValidAddress(pAttribDef))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByName: Attribute '%s' not valid", strAttrib);
	}
	bool bSuccess = !!SDKCall(hSDKSetRuntimeValue, pEntity+view_as<Address>(offs), pAttribDef, flVal);
	//Just a note, the above SDKCall returns ((entindex + 4) * 4) | 0xA000), and you can AND it with 0x1FFF to get back the entindex if you want, though it's pointless)
	//I don't know any other specifics, such as if the highest 3 bits actually matter
	//And I don't know what happens when you hit ent index 2047

//	ClearAttributeCache(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"));
//	char strClassname[64];
//	GetEntityClassname(entity, strClassname, sizeof(strClassname));
//	if (strncmp(strClassname, "tf_wea", 6, false) == 0 || StrEqual(strClassname, "tf_powerup_bottle", false))
//	{
//		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
//		if (client > 0 && client <= MaxClients && IsClientInGame(client)) ClearAttributeCache(client);
//	}

	return bSuccess;
}

public int Native_SetAttribByID(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByDefIndex: Invalid entity index %d passed", entity);
//		return;
	}
	int iAttrib = GetNativeCell(2);
	float flVal = GetNativeCell(3);

	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0)
	{
//		char strClassname[64];
//		if (!GetEntityClassname(entity, strClassname, sizeof(strClassname))) strClassname = "";
//		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByDefIndex: \"m_AttributeList\" not found (entity %d/%s)", entity, strClassname);
		return false;
	}
	Address pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null) return false;
	Address pSchema = SDKCall(hSDKSchema);
	if (pSchema == Address_Null) return false;
	Address pAttribDef = SDKCall(hSDKGetAttributeDef, pSchema, iAttrib);
	if (!IsValidAddress(pAttribDef))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetByDefIndex: Attribute %d not valid", iAttrib);
	}
	bool bSuccess = !!SDKCall(hSDKSetRuntimeValue, pEntity+view_as<Address>(offs), pAttribDef, flVal);
//	ClearAttributeCache(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"));
//	char strClassname[64];
//	GetEntityClassname(entity, strClassname, sizeof(strClassname));
//	if (strncmp(strClassname, "tf_wea", 6, false) == 0 || StrEqual(strClassname, "tf_powerup_bottle", false))
//	{
//		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
//		if (client > 0 && client <= MaxClients && IsClientInGame(client)) ClearAttributeCache(client);
//	}

	return bSuccess;
}

public int Native_GetAttrib(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetByName: Invalid entity index %d passed", entity);
//		return;
	}
	char strAttrib[128];
	GetNativeString(2, strAttrib, sizeof(strAttrib));

	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0)
	{
//		char strClassname[64];
//		if (!GetEntityClassname(entity, strClassname, sizeof(strClassname))) strClassname = "";
//		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetByName: \"m_AttributeList\" not found (entity %d/%s)", entity, strClassname);
		return view_as<int>(Address_Null);
	}
	Address pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null) return view_as<int>(Address_Null);
	Address pSchema = SDKCall(hSDKSchema);
	if (pSchema == Address_Null) return view_as<int>(Address_Null);
	Address pAttribDef = SDKCall(hSDKGetAttributeDefByName, pSchema, strAttrib);
	if (!IsValidAddress(pAttribDef))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetByName: Attribute '%s' not valid", strAttrib);
	}
	int iDefIndex = LoadFromAddress(pAttribDef + view_as<Address>(4), NumberType_Int16);
	Address pAttrib = view_as<Address>( SDKCall(hSDKGetAttributeByID, pEntity+view_as<Address>(offs), iDefIndex) );
	return (!IsValidAddress(pAttrib) ? (view_as<int>(Address_Null)) : (view_as<int>(pAttrib)));
}

public int Native_GetAttribByID(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetByDefIndex: Invalid entity index %d passed", entity);
//		return;
	}
	int iDefIndex = GetNativeCell(2);

	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0)
	{
//		char strClassname[64];
//		if (!GetEntityClassname(entity, strClassname, sizeof(strClassname))) strClassname = "";
//		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetByName: \"m_AttributeList\" not found (entity %d/%s)", entity, strClassname);
		return view_as<int>(Address_Null);
	}
	Address pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null) return view_as<int>(Address_Null);
	Address pAttrib = view_as<Address>( SDKCall(hSDKGetAttributeByID, pEntity+view_as<Address>(offs), iDefIndex) );
	return (!IsValidAddress(pAttrib) ? (view_as<int>(Address_Null)) : (view_as<int>(pAttrib)));
}

public int Native_Remove(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveByName: Invalid entity index %d passed", entity);
		return false;
		// return;
	}
	char strAttrib[128];
	GetNativeString(2, strAttrib, sizeof(strAttrib));

	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0)
	{
//		char strClassname[64];
//		if (!GetEntityClassname(entity, strClassname, sizeof(strClassname))) strClassname = "";
//		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_Remove: \"m_AttributeList\" not found (entity %d/%s)", entity, strClassname);
		return false;
		// return;
	}
	Address pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null)
	{
		return false;
		// return;
	}
	if (pEntity == Address_Null) return false;
	Address pSchema = SDKCall(hSDKSchema);
	if (pSchema == Address_Null) return false;
	Address pAttribDef = SDKCall(hSDKGetAttributeDefByName, pSchema, strAttrib);
	if (!IsValidAddress(pAttribDef))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveByName: Attribute '%s' not valid", strAttrib);
	}
	SDKCall(hSDKRemoveAttribute, pEntity+view_as<Address>(offs), pAttribDef);	//Not a clue what the return is here, but it's probably a clone of the attrib being removed

//	SDKCall(hSDKRemoveAttribute, pEntity+view_as<Address>(offs), strAttrib);
//	ClearAttributeCache(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"));
//	char strClassname[64];
//	GetEntityClassname(entity, strClassname, sizeof(strClassname));
//	if (strncmp(strClassname, "tf_wea", 6, false) == 0 || StrEqual(strClassname, "tf_powerup_bottle", false))
//	{
//		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
//		if (client > 0 && client <= MaxClients && IsClientInGame(client)) ClearAttributeCache(client);
//	}

	return true;
}

public int Native_RemoveByID(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveByDefIndex: Invalid entity index %d passed", entity);
		return false;
		// return;
	}
	int iAttrib = GetNativeCell(2);

	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0)
	{
//		char strClassname[64];
//		if (!GetEntityClassname(entity, strClassname, sizeof(strClassname))) strClassname = "";
//		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_Remove: \"m_AttributeList\" not found (entity %d/%s)", entity, strClassname);
		return false;
		// return;
	}
	Address pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null)
	{
		return false;
		// return;
	}
	if (pEntity == Address_Null) return false;
	Address pSchema = SDKCall(hSDKSchema);
	if (pSchema == Address_Null) return false;
	Address pAttribDef = SDKCall(hSDKGetAttributeDef, pSchema, iAttrib);
	if (!IsValidAddress(pAttribDef))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveByDefIndex: Attribute %d not valid", iAttrib);
	}
	SDKCall(hSDKRemoveAttribute, pEntity+view_as<Address>(offs), pAttribDef);	//Not a clue what the return is here, but it's probably a clone of the attrib being removed

//	SDKCall(hSDKRemoveAttribute, pEntity+view_as<Address>(offs), strAttrib);
//	ClearAttributeCache(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"));
//	char strClassname[64];
//	GetEntityClassname(entity, strClassname, sizeof(strClassname));
//	if (strncmp(strClassname, "tf_wea", 6, false) == 0 || StrEqual(strClassname, "tf_powerup_bottle", false))
//	{
//		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
//		if (client > 0 && client <= MaxClients && IsClientInGame(client)) ClearAttributeCache(client);
//	}

	return true;
}

public int Native_RemoveAll(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveAll: Invalid entity index %d passed", entity);
		return false;
		// return;
	}

	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0)
	{
//		char strClassname[64];
//		if (!GetEntityClassname(entity, strClassname, sizeof(strClassname))) strClassname = "";
//		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveAll: \"m_AttributeList\" not found (entity %d/%s)", entity, strClassname);
		return false;
		// return;
	}
	Address pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null)
	{
		return false;
		// return;
	}
	SDKCall(hSDKDestroyAllAttributes, pEntity+view_as<Address>(offs));	//disregard the return (Valve does!)

//	ClearAttributeCache(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"));
//	char strClassname[64];
//	GetEntityClassname(entity, strClassname, sizeof(strClassname));
//	if (strncmp(strClassname, "tf_wea", 6, false) == 0 || StrEqual(strClassname, "tf_powerup_bottle", false))
//	{
//		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
//		if (client > 0 && client <= MaxClients && IsClientInGame(client)) ClearAttributeCache(client);
//	}

	return true;
}

public int Native_SetID(Handle plugin, int numParams)
{
	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return;
	int iDefIndex = GetNativeCell(2);
	StoreToAddress(pAttrib+view_as<Address>(4), iDefIndex, NumberType_Int16);
}

public int Native_GetID(Handle plugin, int numParams)
{
	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return -1;
	return LoadFromAddress(pAttrib+view_as<Address>(4), NumberType_Int16);
}

public int Native_SetVal(Handle plugin, int numParams)
{
	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return;
	int flVal = GetNativeCell(2);	//It's a float but avoiding tag mismatch warnings
	StoreToAddress(pAttrib+view_as<Address>(8), flVal, NumberType_Int32);
}

public int Native_GetVal(Handle plugin, int numParams)
{
	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return -1;
	return LoadFromAddress(pAttrib+view_as<Address>(8), NumberType_Int32);
}

public int Native_SetInitialVal(Handle plugin, int numParams)
{
	return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetInitialValue: m_flInitialValue is no longer present on attributes");

//	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return;
//	int flInitialVal = GetNativeCell(2);	//It's a float but avoiding tag mismatch warnings
//	StoreToAddress(pAttrib+view_as<Address>(12), flInitialVal, NumberType_Int32);
}

public int Native_GetInitialVal(Handle plugin, int numParams)
{
	return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetInitialValue: m_flInitialValue is no longer present on attributes");

//	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return -1;
//	return LoadFromAddress(pAttrib+view_as<Address>(12), NumberType_Int32);
}

public int Native_SetCurrency(Handle plugin, int numParams)
{
	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return;
	int nCurrency = GetNativeCell(2);
	StoreToAddress(pAttrib+view_as<Address>(12), nCurrency, NumberType_Int32);
}

public int Native_GetCurrency(Handle plugin, int numParams)
{
	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return -1;
	return LoadFromAddress(pAttrib+view_as<Address>(12), NumberType_Int32);
}

public int Native_SetSetBonus(Handle plugin, int numParams)
{
	return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_SetIsSetBonus: m_bSetBonus is no longer present on attributes");

//	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return;
//	bool bSetBonus = !!GetNativeCell(2);
//	StoreToAddress(pAttrib+view_as<Address>(20), bSetBonus, NumberType_Int8);
}

public int Native_GetSetBonus(Handle plugin, int numParams)
{
	return ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_GetIsSetBonus: m_bSetBonus is no longer present on attributes");

//	Address pAttrib = view_as<Address>( GetNativeCell(1) );
//	if (!IsValidAddress(pAttrib)) return -1;
//	return !!LoadFromAddress(pAttrib+view_as<Address>(20), NumberType_Int8);
}

stock bool ClearAttributeCache(int entity)
{
	if (hSDKOnAttribValuesChanged == INVALID_HANDLE) return false;
	if (entity <= 0 || !IsValidEntity(entity)) return false;
	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0) return false;
	Address pAttribs = GetEntityAddress(entity);
	if (!IsValidAddress(pAttribs)) return false;
	pAttribs = view_as<Address>( LoadFromAddress(pAttribs+view_as<Address>(offs+24), NumberType_Int32) );	//AttributeManager
	if (!IsValidAddress(pAttribs)) return false;
	SDKCall(hSDKOnAttribValuesChanged, pAttribs);
	return true;
}

public int Native_ClearCache(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_ClearCache: Invalid entity index %d passed", entity);
		return false;
	}
	return ClearAttributeCache(entity);
}

public int Native_ListIDs(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_ListDefIndices: Invalid entity index %d passed", entity);
		return -1;
		// return;
	}

	int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
	if (offs <= 0)
	{
//		char strClassname[64];
//		if (!GetEntityClassname(entity, strClassname, sizeof(strClassname))) strClassname = "";
//		ThrowNativeError(SP_ERROR_NATIVE, "TF2Attrib_RemoveAll: \"m_AttributeList\" not found (entity %d/%s)", entity, strClassname);
		return -1;
		// return;
	}
	Address pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null)
	{
		return -1;
		// return;
	}
	Address pAttribList = view_as<Address>( LoadFromAddress(pEntity + view_as<Address>(offs + 4), NumberType_Int32) );
	if (!IsValidAddress(pAttribList)) return -1;
	int iNumAttribs = LoadFromAddress(pEntity + view_as<Address>(offs + 16), NumberType_Int32);
	int iAttribIndices[16];
	for (int i = 0; i < iNumAttribs; i++)	//THIS IS HOW YOU GET THE ATTRIBUTES ON AN ITEM!
	{
		iAttribIndices[i] = LoadFromAddress(pAttribList + view_as<Address>(i * 16 + 4), NumberType_Int16);
	}
	SetNativeArray(2, iAttribIndices, 16);
	return iNumAttribs;
}

stock bool IsValidAddress(Address pAddress)
{
	if (pAddress == Address_Null)	//yes the other one overlaps this but w/e
		return false;
	return ((pAddress & view_as<Address>(0x7FFFFFFF)) >= Address_MinimumValid);
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
