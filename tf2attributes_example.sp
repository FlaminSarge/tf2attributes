#pragma semicolon 1

#include <sourcemod>
#include <tf2attributes>

new Address:lastAddr[MAXPLAYERS + 1];

public OnPluginStart()
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
public OnMapStart()
{
	for (new client = 0; client <= MaxClients; client++)
		lastAddr[client] = Address_Null;
}
public Action:Command_RemAttrib(client, args)
{
	decl String:arg1[32];
	decl String:arg2[32];
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_remattrib <target> <attrib>");
		arg1 = "@me";
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	new bool:bydefidx = false;
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
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

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

	for (new i = 0; i < target_count; i++)
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
public Action:Command_RemWepAttrib(client, args)
{
	decl String:arg1[32];
	decl String:arg2[32];
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_remwepatt <target> <attrib>");
		arg1 = "@me";
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	new bool:bydefidx = false;
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
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

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
	for (new i = 0; i < target_count; i++)
	{
		if (IsValidClient(target_list[i]))
		{
			new wep = GetEntPropEnt(target_list[i], Prop_Send, "m_hActiveWeapon");
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
public Action:Command_RemAllAttrib(client, args)
{
	decl String:arg1[32];
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
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

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
	for (new i = 0; i < target_count; i++)
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
public Action:Command_RemAllWepAttrib(client, args)
{
	decl String:arg1[32];
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
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

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
	for (new i = 0; i < target_count; i++)
	{
		if (IsValidClient(target_list[i]))
		{
			new wep = GetEntPropEnt(target_list[i], Prop_Send, "m_hActiveWeapon");
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
public Action:Command_AddAttrib(client, args)
{
	decl String:arg1[32];
	decl String:arg2[128];
	decl String:arg3[32];
	decl String:arg4[32];
	if (args < 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addattrib <target> <attrib> <val> [pass as int]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	new bool:bydefidx = false;
	if (arg2[0] == '#')
	{
		strcopy(arg2, sizeof(arg2), arg2[1]);
		bydefidx = true;
	}
	GetCmdArg(3, arg3, sizeof(arg3));
	if (args > 3) GetCmdArg(4, arg4, sizeof(arg4));
	else arg4 = "0";
	new Float:val = (!!StringToInt(arg4) ? (Float:StringToInt(arg3)) : StringToFloat(arg3));
	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

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
	for (new i = 0; i < target_count; i++)
	{
		if (IsValidEntity(target_list[i]))
		{
			new bool:result = false;
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
		ReplyToCommand(client, "[SM] Added attrib '%s' val %s to %t", arg2, arg3, target_name);
	else
		ReplyToCommand(client, "[SM] Added attrib '%s' val %s to %s", arg2, arg3, target_name);
	return Plugin_Handled;
}
public Action:Command_AddWepAttrib(client, args)
{
	decl String:arg1[32];
	decl String:arg2[128];
	decl String:arg3[32];
	decl String:arg4[32];
	if (args < 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addattrib <target> <attrib> <val> [pass as int]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	if (args > 3) GetCmdArg(4, arg4, sizeof(arg4));
	else arg4 = "0";
	new Float:val = (!!StringToInt(arg4) ? (Float:StringToInt(arg3)) : StringToFloat(arg3));
	new bool:bydefidx = false;
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
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

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
	for (new i = 0; i < target_count; i++)
	{
		if (IsValidClient(target_list[i]))
		{
			new wep = GetEntPropEnt(target_list[i], Prop_Send, "m_hActiveWeapon");
			if (!IsValidEntity(wep)) continue;
			new bool:result = (bydefidx ? TF2Attrib_SetByDefIndex(wep, StringToInt(arg2), val) : TF2Attrib_SetByName(wep, arg2, val));
			if (target_count == 1)
			{
				ReplyToCommand(client, "[SM] AddAttrib wep returned %d", result);
			}
		}
	}
	if (tn_is_ml)
		ReplyToCommand(client, "[SM] Added attrib '%s' val %s to active wep of %t", arg2, arg3, target_name);
	else
		ReplyToCommand(client, "[SM] Added attrib '%s' val %s to active wep of %s", arg2, arg3, target_name);
	return Plugin_Handled;
}
public Action:Command_GetAttrByName(client, args)
{
	decl String:arg1[32];
	decl String:arg2[128];
	decl String:arg3[32];
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_getattr <target> <attrib> [p/w]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	new bool:bydefidx = false;
	if (arg2[0] == '#')
	{
		strcopy(arg2, sizeof(arg2), arg2[1]);
		bydefidx = true;
	}
	if (args > 2) GetCmdArg(3, arg3, sizeof(arg3));
	else arg3 = "p";
	new bool:usePlayer = arg3[0] != 'w';
	new target = -1;
	if (arg1[0] == '#' && arg1[1] == '#')	//'##entindex' instead of target
	{
		target = StringToInt(arg1[2]);
	}
	else target = FindTarget(client, arg1, false, false);
	if (!IsValidEntity(target)) return Plugin_Handled;

	new wep = target;
	if (!usePlayer)
	{
		wep = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
		if (!IsValidEntity(wep))
		{
			usePlayer = true;
			wep = target;
		}
	}

	new Address:pAttrib = (bydefidx ? TF2Attrib_GetByDefIndex(wep, StringToInt(arg2)) : TF2Attrib_GetByName(wep, arg2));
	lastAddr[client] = pAttrib;
	if (Address:pAttrib < Address_MinimumValid)
	{
		ReplyToCommand(client, "[SM] GetAttrib got null attrib '%s' on %s%d", arg2, usePlayer ? "" : "active wep of ", target);//, target);
		return Plugin_Handled;
	}
	new Float:result = TF2Attrib_GetValue(pAttrib);
	new idx = TF2Attrib_GetDefIndex(pAttrib);
	if (TF2Attrib_IsIntegerValue(idx)) result = float(_:result);
	new Float:init;// = TF2Attrib_GetInitialValue(pAttrib);
	if (TF2Attrib_IsIntegerValue(idx)) init = float(_:init);
	ReplyToCommand(client, "[SM] GetAttrib got: %d %d ; %.4f, %.4f, %d, %d for attrib '%s' on %s%d", _:pAttrib, idx, result, init, TF2Attrib_GetRefundableCurrency(pAttrib), 0 /*TF2Attrib_GetIsSetBonus(pAttrib)*/, arg2, usePlayer ? "" : "active wep of ", target);//, target);
	return Plugin_Handled;
}
public Action:Command_GetAttrByID(client, args)
{
	decl String:arg1[32];
	decl String:arg2[128];
	decl String:arg3[32];
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_getattr <target> <attrib> [p/w]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	new index = StringToInt(arg2);
	if (args > 2) GetCmdArg(3, arg3, sizeof(arg3));
	else arg3 = "p";
	new bool:usePlayer = arg3[0] != 'w';
	new target = -1;
	if (arg1[0] == '#' && arg1[1] == '#')	//'##entindex' instead of target
	{
		target = StringToInt(arg1[2]);
	}
	else target = FindTarget(client, arg1, false, false);
	if (!IsValidEntity(target)) return Plugin_Handled;

	new wep = target;
	if (!usePlayer)
	{
		wep = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
		if (!IsValidEntity(wep))
		{
			usePlayer = true;
			wep = target;
		}
	}

	new Address:pAttrib = TF2Attrib_GetByDefIndex(wep, index);
	lastAddr[client] = pAttrib;
	if (Address:pAttrib < Address_MinimumValid)
	{
		ReplyToCommand(client, "[SM] GetAttrib got null attrib '%d' on %s%d", index, usePlayer ? "" : "active wep of ", target);//, target);
		return Plugin_Handled;
	}
	new Float:result = TF2Attrib_GetValue(pAttrib);
	new idx = TF2Attrib_GetDefIndex(pAttrib);
	if (TF2Attrib_IsIntegerValue(idx)) result = float(_:result);
	new Float:init;// = TF2Attrib_GetInitialValue(pAttrib);
	if (TF2Attrib_IsIntegerValue(idx)) init = float(_:init);
	ReplyToCommand(client, "[SM] GetAttrib got: %d %d ; %.4f, %.4f, %d, %d for attrib '%s' on %s%d", _:pAttrib, idx, result, init, TF2Attrib_GetRefundableCurrency(pAttrib), 0 /*TF2Attrib_GetIsSetBonus(pAttrib)*/, arg2, usePlayer ? "" : "active wep of ", target);//, target);
	return Plugin_Handled;
}
public Action:Command_GetAttrs(client, args)
{
	decl String:arg1[64];
	decl String:arg3[32];
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_getattrs <target> [p/w]");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	if (args > 1) GetCmdArg(2, arg3, sizeof(arg3));
	else arg3 = "p";
	new bool:usePlayer = arg3[0] != 'w';
	new target = -1;
	if (arg1[0] == '#' && arg1[1] == '#')	//'##entindex' instead of target
	{
		target = StringToInt(arg1[2]);
	}
	else target = FindTarget(client, arg1, false, false);
	if (!IsValidEntity(target)) return Plugin_Handled;

	new wep = target;
	if (!usePlayer)
	{
		wep = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
		if (!IsValidEntity(wep))
		{
			usePlayer = true;
			wep = target;
		}
	}

	new attriblist[16];
	arg1 = "[SM] ListDefIndices:";
	new count = TF2Attrib_ListDefIndices(wep, attriblist);
	for (new i = 0; i < count; i++)
	{
		Format(arg1, sizeof(arg1), "%s %d", arg1, attriblist[i]);
	}
	ReplyToCommand(client, "%s on %s%d", arg1, usePlayer ? "" : "active wep of ", target);//, target);
	return Plugin_Handled;
}
public Action:SetValueStuff(client, args)
{
	decl String:arg1[32];
	decl String:arg2[32];
	decl String:arg3[32];
	if (args < 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_attrset <address> <type> <val>");
		return Plugin_Handled;
	}
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	new Address:addr = Address:StringToInt(arg1);
	if (addr != lastAddr[client] || addr < Address_MinimumValid)
	{
		ReplyToCommand(client, "[SM] Unsafe address");
		return Plugin_Handled;
	}
	new type = StringToInt(arg2);
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
stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	return IsClientInGame(client);
}