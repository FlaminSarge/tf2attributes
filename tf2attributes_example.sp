#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2attributes>

#define MAX_RUNTIME_ATTRIBUTES 20

Address lastAddr[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegAdminCmd("sm_addattrib", Command_AddAttrib, ADMFLAG_ROOT);
	RegAdminCmd("sm_addwepatt", Command_AddWepAttrib, ADMFLAG_ROOT);
	RegAdminCmd("sm_remattrib", Command_RemAttrib, ADMFLAG_ROOT);
	RegAdminCmd("sm_remwepatt", Command_RemWepAttrib, ADMFLAG_ROOT);
	RegAdminCmd("sm_remallatt", Command_RemAllAttrib, ADMFLAG_ROOT);
	RegAdminCmd("sm_remallwepatt", Command_RemAllWepAttrib, ADMFLAG_ROOT);
	RegAdminCmd("sm_getattrib", Command_GetAttrByName, ADMFLAG_ROOT);
//	RegAdminCmd("sm_getattrid", Command_GetAttrByID, ADMFLAG_ROOT);
	RegAdminCmd("sm_getattrs", Command_GetAttrs, ADMFLAG_ROOT);
//	RegAdminCmd("sm_attrset", SetValueStuff, ADMFLAG_ROOT); //Definitely unsafe as all hell
	LoadTranslations("common.phrases");
}
public void OnMapStart()
{
	for (int client = 0; client <= MaxClients; client++)
		lastAddr[client] = Address_Null;
}
public Action Command_RemAttrib(int client, int args)
{
	char arg1[32];
	char arg2[32];
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_remattrib <target> <attrib>");
		arg1 = "@me";
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	bool bydefidx = false;
	if (arg2[0] == '#')
	{
		strcopy(arg2, sizeof(arg2), arg2[1]);
		bydefidx = true;
	}

	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if (arg1[0] == '#' && arg1[1] == '#')	//'##entindex' instead of target
	{
		target_list[0] = StringToInt(arg1[2]);
		target_count = 1;
		strcopy(target_name, sizeof(target_name), arg1[2]);
		tn_is_ml = false;
	}
	else
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		if (IsValidEntity(target_list[i]))
		{
			if (bydefidx)
				TF2Attrib_RemoveByDefIndex(target_list[i], StringToInt(arg2));
			else
				TF2Attrib_RemoveByName(target_list[i], arg2);
		}
	}
	if (tn_is_ml)
		ReplyToCommand(client, "[SM] Removed attrib '%s' from %t", arg2, target_name);
	else
		ReplyToCommand(client, "[SM] Removed attrib '%s' from %s", arg2, target_name);
	return Plugin_Handled;
}
public Action Command_RemWepAttrib(int client, int args)
{
	char arg1[32];
	char arg2[32];
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_remwepatt <target> <attrib>");
		arg1 = "@me";
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	bool bydefidx = false;
	if (arg2[0] == '#')
	{
		strcopy(arg2, sizeof(arg2), arg2[1]);
		bydefidx = true;
	}
	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (int i = 0; i < target_count; i++)
	{
		if (IsValidClient(target_list[i]))
		{
			int wep = GetEntPropEnt(target_list[i], Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(wep))
				(bydefidx ? TF2Attrib_RemoveByDefIndex(wep, StringToInt(arg2)) : TF2Attrib_RemoveByName(wep, arg2));
		}
	}
	if (tn_is_ml)
		ReplyToCommand(client, "[SM] Removed attrib '%s' from active wep of %t", arg2, target_name);
	else
		ReplyToCommand(client, "[SM] Removed attrib '%s' from active wep of %s", arg2, target_name);
	return Plugin_Handled;
}
public Action Command_RemAllAttrib(int client, int args)
{
	char arg1[32];
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_remallatt <target>");
		arg1 = "@me";
	}
	else GetCmdArg(1, arg1, sizeof(arg1));


	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if (arg1[0] == '#' && arg1[1] == '#')	//'##entindex' instead of target
	{
		target_list[0] = StringToInt(arg1[2]);
		target_count = 1;
		strcopy(target_name, sizeof(target_name), arg1[2]);
		tn_is_ml = false;
	}
	else
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (int i = 0; i < target_count; i++)
	{
		if (IsValidEntity(target_list[i]))
		{
			TF2Attrib_RemoveAll(target_list[i]);
		}
	}
	if (tn_is_ml)
		ReplyToCommand(client, "[SM] Removed allattrib from %t", target_name);
	else
		ReplyToCommand(client, "[SM] Removed allattrib from %s", target_name);
	return Plugin_Handled;
}
public Action Command_RemAllWepAttrib(int client, int args)
{
	char arg1[32];
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_remallwepatt <target>");
		arg1 = "@me";
	}
	else GetCmdArg(1, arg1, sizeof(arg1));

	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (int i = 0; i < target_count; i++)
	{
		if (IsValidClient(target_list[i]))
		{
			int wep = GetEntPropEnt(target_list[i], Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(wep))
				TF2Attrib_RemoveAll(wep);
		}
	}
	if (tn_is_ml)
		ReplyToCommand(client, "[SM] Removed allattrib from active wep of %t", target_name);
	else
		ReplyToCommand(client, "[SM] Removed allattrib from active wep of %s", target_name);
	return Plugin_Handled;
}
public Action Command_AddAttrib(int client, int args)
{
	char arg1[32];
	char arg2[128];
	char arg3[32];
	if (args < 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addattrib <target> <attrib> <val> [pass as int]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	bool passint = false;
	if (args > 3) passint = true;
	float val = (passint ? (view_as<float>(StringToInt(arg3))) : StringToFloat(arg3));
	bool bydefidx = false;
	if (arg2[0] == '#')
	{
		strcopy(arg2, sizeof(arg2), arg2[1]);
		bydefidx = true;
	}
	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if (arg1[0] == '#' && arg1[1] == '#')	//'##entindex' instead of target
	{
		target_list[0] = StringToInt(arg1[2]);
		target_count = 1;
		strcopy(target_name, sizeof(target_name), arg1[2]);
		tn_is_ml = false;
	}
	else
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (int i = 0; i < target_count; i++)
	{
		if (IsValidEntity(target_list[i]))
		{
			bool result = false;
			if (bydefidx)
				result = TF2Attrib_SetByDefIndex(target_list[i], StringToInt(arg2), val);
			else
				result = TF2Attrib_SetByName(target_list[i], arg2, val);
			if (target_count == 1)
			{
				ReplyToCommand(client, "[SM] AddAttrib returned %d", result);
			}
		}
	}
	if (tn_is_ml)
		ReplyToCommand(client, "[SM] Added attrib '%s' val %s to %t%s", arg2, arg3, target_name, passint ? " as int" : "");
	else
		ReplyToCommand(client, "[SM] Added attrib '%s' val %s to %s%s", arg2, arg3, target_name, passint ? " as int" : "");
	return Plugin_Handled;
}
public Action Command_AddWepAttrib(int client, int args)
{
	char arg1[32];
	char arg2[128];
	char arg3[32];
	if (args < 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addattrib <target> <attrib> <val> [pass as int]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	bool passint = false;
	if (args > 3) passint = true;
	float val = (passint ? (view_as<float>(StringToInt(arg3))) : StringToFloat(arg3));
	bool bydefidx = false;
	if (arg2[0] == '#')
	{
		strcopy(arg2, sizeof(arg2), arg2[1]);
		bydefidx = true;
	}
	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (int i = 0; i < target_count; i++)
	{
		if (IsValidClient(target_list[i]))
		{
			int wep = GetEntPropEnt(target_list[i], Prop_Send, "m_hActiveWeapon");
			if (!IsValidEntity(wep)) continue;
			bool result = (bydefidx ? TF2Attrib_SetByDefIndex(wep, StringToInt(arg2), val) : TF2Attrib_SetByName(wep, arg2, val));
			if (target_count == 1)
			{
				ReplyToCommand(client, "[SM] AddAttrib wep returned %d", result);
			}
		}
	}
	if (tn_is_ml)
		ReplyToCommand(client, "[SM] Added attrib '%s' val %s to active wep of %t%s", arg2, arg3, target_name, passint ? " as int" : "");
	else
		ReplyToCommand(client, "[SM] Added attrib '%s' val %s to active wep of %s%s", arg2, arg3, target_name, passint ? " as int" : "");
	return Plugin_Handled;
}
public Action Command_GetAttrByName(int client, int args)
{
	char arg1[32];
	char arg2[128];
	char arg3[32];
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_getattrib <target> <attrib> [p/w]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	bool bydefidx = false;
	if (arg2[0] == '#')
	{
		strcopy(arg2, sizeof(arg2), arg2[1]);
		bydefidx = true;
	}
	if (args > 2) GetCmdArg(3, arg3, sizeof(arg3));
	else arg3 = "p";
	bool usePlayer = arg3[0] != 'w';
	int target = -1;
	if (arg1[0] == '#' && arg1[1] == '#')	//'##entindex' instead of target
	{
		target = StringToInt(arg1[2]);
	}
	else target = FindTarget(client, arg1, false, false);
	if (!IsValidEntity(target)) return Plugin_Handled;

	int wep = target;
	if (!usePlayer)
	{
		wep = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
		if (!IsValidEntity(wep))
		{
			usePlayer = true;
			wep = target;
		}
	}

	Address pAttrib = (bydefidx ? TF2Attrib_GetByDefIndex(wep, StringToInt(arg2)) : TF2Attrib_GetByName(wep, arg2));
	lastAddr[client] = pAttrib;
	if (!IsValidAddress(view_as<Address>(pAttrib)))
	{
		ReplyToCommand(client, "[SM] GetAttrib got null attrib '%s' on %s%d", arg2, usePlayer ? "" : "active wep of ", target);//, target);
		return Plugin_Handled;
	}
	float result = TF2Attrib_GetValue(pAttrib);
	int idx = TF2Attrib_GetDefIndex(pAttrib);
	if (TF2Attrib_IsIntegerValue(idx)) result = float(view_as<int>(result));
	float init;// = TF2Attrib_GetInitialValue(pAttrib);
	if (TF2Attrib_IsIntegerValue(idx)) init = float(view_as<int>(init));
	ReplyToCommand(client, "[SM] GetAttrib got: %d %d ; %.3f, %.3f, %d, %d for attrib '%s' on %s%d", view_as<int>(pAttrib), idx, result, init, TF2Attrib_GetRefundableCurrency(pAttrib), 0 /*TF2Attrib_GetIsSetBonus(pAttrib)*/, arg2, usePlayer ? "" : "active wep of ", target);//, target);
	return Plugin_Handled;
}
public Action Command_GetAttrByID(int client, int args)
{
	char arg1[32];
	char arg2[128];
	char arg3[32];
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_getattrib <target> <attrib> [p/w]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int index = StringToInt(arg2);
	if (args > 2) GetCmdArg(3, arg3, sizeof(arg3));
	else arg3 = "p";
	bool usePlayer = arg3[0] != 'w';
	int target = -1;
	if (arg1[0] == '#' && arg1[1] == '#')	//'##entindex' instead of target
	{
		target = StringToInt(arg1[2]);
	}
	else target = FindTarget(client, arg1, false, false);
	if (!IsValidEntity(target)) return Plugin_Handled;

	int wep = target;
	if (!usePlayer)
	{
		wep = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
		if (!IsValidEntity(wep))
		{
			usePlayer = true;
			wep = target;
		}
	}

	Address pAttrib = TF2Attrib_GetByDefIndex(wep, index);
	lastAddr[client] = pAttrib;
	if (!IsValidAddress(view_as<Address>(pAttrib)))
	{
		ReplyToCommand(client, "[SM] GetAttrib got null attrib '%d' on %s%d", index, usePlayer ? "" : "active wep of ", target);//, target);
		return Plugin_Handled;
	}
	float result = TF2Attrib_GetValue(pAttrib);
	int idx = TF2Attrib_GetDefIndex(pAttrib);
	if (TF2Attrib_IsIntegerValue(idx)) result = float(view_as<int>(result));
	float init;// = TF2Attrib_GetInitialValue(pAttrib);
	if (TF2Attrib_IsIntegerValue(idx)) init = float(view_as<int>(init));
	ReplyToCommand(client, "[SM] GetAttrib got: %08X %d ; %.3f, %.3f, %d, %d for attrib '%s' on %s%d", view_as<int>(pAttrib), idx, result, init, TF2Attrib_GetRefundableCurrency(pAttrib), 0 /*TF2Attrib_GetIsSetBonus(pAttrib)*/, arg2, usePlayer ? "" : "active wep of ", target);//, target);
	return Plugin_Handled;
}
public Action Command_GetAttrs(int client, int args)
{
	char arg1[64];
	char arg2[32];
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_getattrs <target> [p/w]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	arg2 = "p";
	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	bool usePlayer = arg2[0] != 'w';
	int target = -1;
	if (arg1[0] == '#' && arg1[1] == '#')	//'##entindex' instead of target
	{
		target = StringToInt(arg1[2]);
	}
	else target = FindTarget(client, arg1, false, false);
	if (!IsValidEntity(target)) return Plugin_Handled;

	int wep = target;
	if (!usePlayer)
	{
		wep = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
		if (!IsValidEntity(wep))
		{
			usePlayer = true;
			wep = target;
		}
	}

	int attriblist[MAX_RUNTIME_ATTRIBUTES];
	arg1 = "";
	int count = TF2Attrib_ListDefIndices(wep, attriblist, sizeof(attriblist));
	ReplyToCommand(client, "[SM] ListDefIndices: Got %d attributes on %s%d", count, usePlayer ? "" : "active wep of ", target);
	if (count > sizeof(attriblist))
	{
		ReplyToCommand(client, "Max expected was %d", sizeof(attriblist));
	}
	for (int i = 0; i < count && i < sizeof(attriblist); i++)
	{
		Format(arg1, sizeof(arg1), "%s %d", arg1, attriblist[i]);
	}
	TrimString(arg1);

	ReplyToCommand(client, "Runtime: [%s]", arg1);
	if (!usePlayer)
	{
		float valuelist[MAX_RUNTIME_ATTRIBUTES];
		int count_static = TF2Attrib_GetSOCAttribs(wep, attriblist, valuelist, sizeof(attriblist));
		if (count_static > 0)
		{
			ReplyToCommand(client, "SOC:");
		}
		for (int i = 0; i < count_static; i++)
		{
			ReplyToCommand(client, "%d: %.3f %d", attriblist[i], valuelist[i], view_as<int>(valuelist[i]));
		}
		int iDefIndex = GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex");
		count_static = TF2Attrib_GetStaticAttribs(iDefIndex, attriblist, valuelist);
		if (count_static > 0)
		{
			ReplyToCommand(client, "Static:");
		}
		for (int i = 0; i < count_static; i++)
		{
			ReplyToCommand(client, "%d: %.3f %d", attriblist[i], valuelist[i], view_as<int>(valuelist[i]));
		}
	}
	return Plugin_Handled;
}
public Action SetValueStuff(int client, int args)
{
	char arg1[32];
	char arg2[32];
	char arg3[32];
	if (args < 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_attrset <address> <type> <val>");
		return Plugin_Handled;
	}
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	Address addr = view_as<Address>(StringToInt(arg1));
	if (addr != lastAddr[client] || !IsValidAddress(addr))
	{
		ReplyToCommand(client, "[SM] Unsafe address");
		return Plugin_Handled;
	}
	int type = StringToInt(arg2);
	switch (type)
	{
		case 1: TF2Attrib_SetDefIndex(addr, StringToInt(arg3));
		case 2: TF2Attrib_SetValue(addr, StringToFloat(arg3));
//		case 3: TF2Attrib_SetInitialValue(addr, StringToFloat(arg3));
		case 3: TF2Attrib_SetRefundableCurrency(addr, StringToInt(arg3));
//		case 5: TF2Attrib_SetIsSetBonus(addr, !!StringToInt(arg3));
	}
	ReplyToCommand(client, "[SM] Set %d on %d to %s", type, addr, arg3);
	return Plugin_Handled;
}
stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	return IsClientInGame(client);
}
//TODO Stop using Address_MinimumValid once verified that logic still works without it
stock bool IsValidAddress(Address pAddress)
{
	static Address Address_MinimumValid = view_as<Address>(0x10000);
	if (pAddress == Address_Null)
		return false;
	return unsigned_compare(view_as<int>(pAddress), view_as<int>(Address_MinimumValid)) >= 0;
}
stock int unsigned_compare(int a, int b) {
	if (a == b)
		return 0;
	if ((a >>> 31) == (b >>> 31))
		return ((a & 0x7FFFFFFF) > (b & 0x7FFFFFFF)) ? 1 : -1;
	return ((a >>> 31) > (b >>> 31)) ? 1 : -1;
}
