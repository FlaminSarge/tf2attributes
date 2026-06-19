#pragma semicolon 1
#pragma newdecls required

#include <tf2_stocks>
#include <tf2attributes>

public Plugin myinfo =
{
	name		= "TF2Attributes Test",
	author		= "Malifox",
	description = "Automated tests for tf2attributes",
	version		= "1.0.0",
	url			= ""
}

#define LOG_PREFIX "[TF2Attributes Test] "
#define LOG_PREFIX_START LOG_PREFIX ... "Starting: "
#define LOG_PREFIX_PASS LOG_PREFIX ... "Passed: "
#define LOG_PREFIX_FAIL LOG_PREFIX ... "***FAILED*** "
#define LOG_PREFIX_WARN LOG_PREFIX ... "**WARNING** "
#define LOG_PREFIX_INFO LOG_PREFIX ... "--- "

#define ATTR_CUSTOM_NAME_ATTR 500 // ""custom_name_attr"
#define ATTR_HEALTH_REGEN 57 // "health regen"

#define ATTR_MAJOR_MOVE_SPEED_BONUS 442 // "major move speed bonus"
#define MAJOR_MOVE_SPEED_BONUS_VALUE 3.0

#define ATTR_DAMAGE_CAUSES_AIRBLAST 522

#define ATTR_MIN_VIEWMODEL_OFFSET 796 // "min_viewmodel_offset", "string" type that generally all weapons have

enum LogType
{
	LogType_Start = 0,
	LogType_Passed,
	LogType_Failed,
	LogType_Warn,
	LogType_Info
}

int g_iTestsTotal;
int g_iTestsPassed;
int g_iTestWarnings;

// items_game.txt: "stored_as_integer"	"1"
static const char g_sTestAttribNameInt[] = "damage causes airblast";
const int g_iTestAttribDefIndexInt = ATTR_DAMAGE_CAUSES_AIRBLAST;

// items_game.txt: "stored_as_integer"	"0"
static const char g_sTestAttribNameFloat[] = "major move speed bonus";
static const char g_sTestAttribClassFloat[] = "mult_player_movespeed"; // Needs to be multiplicative for test to pass
const int g_iTestAttribDefIndexFloat = ATTR_MAJOR_MOVE_SPEED_BONUS;
const float g_fTestAttribValue = MAJOR_MOVE_SPEED_BONUS_VALUE;
char g_sTestAttribValue[18];

static const char g_sTestAttribNameString[] = "start drop date"; // items_game.txt: "attribute_type"	"string"

public void OnPluginStart()
{
	FloatToString(g_fTestAttribValue, g_sTestAttribValue, sizeof(g_sTestAttribValue));

	RegAdminCmd("sm_test_tf2attributes", Command_TestTF2Attributes, ADMFLAG_ROOT, "Full automated test. Equip name tagged primary weapon if possible.");
}

Action Command_TestTF2Attributes(int client, int args)
{
	// Untested scenarios: TF2Attrib_UnsafeGetStringValue reading SOC attribute string values

	if (!client || !IsPlayerAlive(client))
	{
		ReplyToCommand(client, "You must be alive to run this command.");
		return Plugin_Handled;
	}

	int iWeapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);

	if (iWeapon == -1)
	{
		ReplyToCommand(client, "You must have a primary weapon to run this command.");
		return Plugin_Handled;
	}

	g_iTestsTotal = g_iTestsPassed = g_iTestWarnings = 0;

	Test_TF2Attrib_IsValidAttributeName(client); // TF2Attrib_IsValidAttributeName
	Test_TF2Attrib_IsIntegerValue(client); // TF2Attrib_IsIntegerValue
	Test_TF2Attrib_SetByName(client, iWeapon); // TF2Attrib_SetByName, TF2Attrib_GetByName, TF2Attrib_GetValue, TF2Attrib_RemoveByName
	Test_TF2Attrib_SetByDefIndex(client, iWeapon); // TF2Attrib_SetByDefIndex, TF2Attrib_GetByDefIndex, TF2Attrib_ListDefIndices, TF2Attrib_RemoveByDefIndex
	Test_TF2Attrib_GetStaticAttribs(client, iWeapon); // TF2Attrib_GetStaticAttribs
	Test_TF2Attrib_GetSOCAttribs(client, iWeapon); // TF2Attrib_GetSOCAttribs
	Test_TF2Attrib_AddCustomPlayerAttribute(client); // TF2Attrib_AddCustomPlayerAttribute, TF2Attrib_RemoveCustomPlayerAttribute
	Test_TF2Attrib_HookValueFloat(client, iWeapon); // TF2Attrib_HookValueFloat
	Test_TF2Attrib_HookValueInt(client, iWeapon); // TF2Attrib_HookValueInt
	Test_TF2Attrib_HookValueString(client, iWeapon); // TF2Attrib_HookValueString
	Test_TF2Attrib_SetFromStringValue(client, iWeapon); // TF2Attrib_SetFromStringValue, TF2Attrib_UnsafeGetStringValue
	Test_TF2Attrib_SetRefundableCurrency(client, iWeapon); // TF2Attrib_SetRefundableCurrency, TF2Attrib_GetRefundableCurrency
	Test_TF2Attrib_SetGet_ClearCache(client, iWeapon); // TF2Attrib_SetDefIndex, TF2Attrib_GetDefIndex, TF2Attrib_SetValue, TF2Attrib_ClearCache
	Test_TF2Attrib_MultipleAttributes(client, iWeapon); // TF2Attrib_SetByDefIndex, TF2Attrib_ListDefIndices, TF2Attrib_GetByDefIndex with multiple runtime attributes
	Test_TF2Attrib_HookValueStress(client, iWeapon); // TF2Attrib_HookValueFloat, TF2Attrib_HookValueString repeated-call stress
	Test_TF2Attrib_RemoveAll(client, iWeapon); // TF2Attrib_RemoveAll

	char sSummaryFormat[] = LOG_PREFIX ... "Summary: Passed: %d/%d, Warnings: %d";
	char sSummary[sizeof(sSummaryFormat)];
	FormatEx(sSummary, sizeof(sSummary), sSummaryFormat, g_iTestsPassed, g_iTestsTotal, g_iTestWarnings);

	LogToGame(sSummary);
	PrintToConsole(client, sSummary);

	return Plugin_Handled;
}

void Test_TF2Attrib_IsValidAttributeName(int client)
{
	char sTest[] = "TF2Attrib_IsValidAttributeName";
	LogTest(client, LogType_Start, sTest);

	if (!TF2Attrib_IsValidAttributeName(g_sTestAttribNameFloat))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_IsValidAttributeName returned false for valid attribute name '%s'", g_sTestAttribNameFloat);
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_IsIntegerValue(int client)
{
	char sTest[] = "TF2Attrib_IsIntegerValue";
	LogTest(client, LogType_Start, sTest);

	bool bIsIntTestFloat = TF2Attrib_IsIntegerValue(g_iTestAttribDefIndexFloat);
	bool bIsIntTestInt = TF2Attrib_IsIntegerValue(g_iTestAttribDefIndexInt);

	if (bIsIntTestFloat || !bIsIntTestInt)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_IsIntegerValue returned incorrect values: " ...
			"%s = %d(expected 0), %s = %d(expected 1)", g_sTestAttribNameFloat, bIsIntTestFloat, g_sTestAttribNameInt, bIsIntTestInt);
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_SetByName(int client, int entity)
{
	char sTest[] = "TF2Attrib_SetByName, TF2Attrib_GetByName, TF2Attrib_GetValue, TF2Attrib_RemoveByName";
	LogTest(client, LogType_Start, sTest);

	LogTest(client, LogType_Info, "TF2Attrib_SetByName '%s' to value %f", g_sTestAttribNameFloat, g_fTestAttribValue);
	if (!TF2Attrib_SetByName(entity, g_sTestAttribNameFloat, g_fTestAttribValue))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetByName");
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_GetByName '%s'", g_sTestAttribNameFloat);
	Address pCEconItemAttribute = TF2Attrib_GetByName(entity, g_sTestAttribNameFloat);

	if (!pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetByName returned Address_Null");
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_GetValue virtual address 0x%lX", pCEconItemAttribute);
	float fValue = TF2Attrib_GetValue(pCEconItemAttribute);

	if (fValue != g_fTestAttribValue)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetValue returned %f, expected %f", fValue, g_fTestAttribValue);
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_RemoveByName '%s'", g_sTestAttribNameFloat);
	if (!TF2Attrib_RemoveByName(entity, g_sTestAttribNameFloat))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveByName returned false");
		return;
	}

	pCEconItemAttribute = TF2Attrib_GetByName(entity, g_sTestAttribNameFloat);

	if (pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveByName failed, attribute still present");
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_SetByDefIndex(int client, int entity)
{
	char sTest[] = "TF2Attrib_SetByDefIndex, TF2Attrib_GetByDefIndex, TF2Attrib_ListDefIndices, TF2Attrib_RemoveByDefIndex";
	LogTest(client, LogType_Start, sTest);

	LogTest(client, LogType_Info, "TF2Attrib_SetByDefIndex %d to value %f", g_iTestAttribDefIndexFloat, g_fTestAttribValue);
	if (!TF2Attrib_SetByDefIndex(entity, g_iTestAttribDefIndexFloat, g_fTestAttribValue))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetByDefIndex");
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_GetByDefIndex %d", g_iTestAttribDefIndexFloat);
	Address pCEconItemAttribute = TF2Attrib_GetByDefIndex(entity, g_iTestAttribDefIndexFloat);

	if (!pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetByDefIndex returned Address_Null");
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_GetValue virtual address 0x%lX", pCEconItemAttribute);
	float fValue = TF2Attrib_GetValue(pCEconItemAttribute);

	if (fValue != g_fTestAttribValue)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetValue returned %f, expected %f", fValue, g_fTestAttribValue);
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_ListDefIndices entity %d", entity);
	int iAttribIndices[TF2ATTRIB_MAX_ITEM_ATTRIBUTES];
	int iNumAttr = TF2Attrib_ListDefIndices(entity, iAttribIndices);

	if (iNumAttr <= 0)
	{
		if (iNumAttr == -1)
			LogTest(client, LogType_Failed, "TF2Attrib_ListDefIndices failed with return -1");
		else
			LogTest(client, LogType_Failed, "TF2Attrib_ListDefIndices returned 0 attributes, " ...
				"should have at least the current test attribute");
	}
	else
	{
		LogTest(client, LogType_Info, "TF2Attrib_ListDefIndices iNumAttr: %d", iNumAttr);
		bool bHasTestAttrib;

		for (int i = 0; i < iNumAttr; i++)
		{
			LogTest(client, LogType_Info, "TF2Attrib_ListDefIndices Attrib %d: %d", i, iAttribIndices[i]);

			if (iAttribIndices[i] == g_iTestAttribDefIndexFloat)
				bHasTestAttrib = true;
		}

		if (!bHasTestAttrib)
			LogTest(client, LogType_Failed, "TF2Attrib_ListDefIndices did not find the current test attribute");
	}

	LogTest(client, LogType_Info, "TF2Attrib_RemoveByDefIndex %d", g_iTestAttribDefIndexFloat);
	if (!TF2Attrib_RemoveByDefIndex(entity, g_iTestAttribDefIndexFloat))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveByDefIndex failed, further tests will be tainted");
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_GetByDefIndex %d", g_iTestAttribDefIndexFloat);
	pCEconItemAttribute = TF2Attrib_GetByDefIndex(entity, g_iTestAttribDefIndexFloat);

	if (pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveByDefIndex failed, attribute still present");
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_GetStaticAttribs(int client, int iWeapon)
{
	char sTest[] = "TF2Attrib_GetStaticAttribs";
	LogTest(client, LogType_Start, sTest);

	int iItemDef = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");

	int iAttribIndices[TF2ATTRIB_MAX_ITEM_ATTRIBUTES];
	float fAttribValues[TF2ATTRIB_MAX_ITEM_ATTRIBUTES];

	LogTest(client, LogType_Info, "TF2Attrib_GetStaticAttribs on iItemDef %d", iItemDef);
	int iNumAttr = TF2Attrib_GetStaticAttribs(iItemDef, iAttribIndices, fAttribValues);

	if (iNumAttr <= 0)
	{
		if (iNumAttr == -1)
			LogTest(client, LogType_Failed, "TF2Attrib_GetStaticAttribs returned -1: no schema or item definition found");
		else
			LogTest(client, LogType_Failed, "TF2Attrib_GetStaticAttribs returned 0 attributes");

		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_GetStaticAttribs iNumAttr: %d", iNumAttr);

	bool bHasMinViewmodelOffsetAttr;

	for (int i = 0; i < iNumAttr; i++)
	{
		if (iAttribIndices[i] == ATTR_MIN_VIEWMODEL_OFFSET)
			bHasMinViewmodelOffsetAttr = true;

		LogTest(client, LogType_Info, "TF2Attrib_GetStaticAttribs Attrib %d: %d = %f", i, iAttribIndices[i], fAttribValues[i]);
	}

	if (!bHasMinViewmodelOffsetAttr)
		LogTest(client, LogType_Warn, "Tested item does not have 'min_viewmodel_offset' static attribute, which all weapons should have");

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_GetSOCAttribs(int client, int iWeapon)
{
	char sTest[] = "TF2Attrib_GetSOCAttribs";
	LogTest(client, LogType_Start, sTest);

	int iAttribIndices[TF2ATTRIB_MAX_ITEM_ATTRIBUTES];
	float fAttribValues[TF2ATTRIB_MAX_ITEM_ATTRIBUTES];

	int iNumAttr = TF2Attrib_GetSOCAttribs(iWeapon, iAttribIndices, fAttribValues);

	if (iNumAttr <= 0)
	{
		if (iNumAttr == -1)
			LogTest(client, LogType_Failed, "TF2Attrib_GetSOCAttribs returned error, attributes = -1");
		else
			LogTest(client, LogType_Failed, "TF2Attrib_GetSOCAttribs returned 0 attributes. " ...
				"This test expects the tested weapon to have come from the item server. " ...
				"Treat as hard failure if it did. TF2Attrib_HookValueString will have a warning.");
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_GetSOCAttribs iNumAttr: %d", iNumAttr);

	bool bHasCustomNameAttr;

	for (int i = 0; i < iNumAttr; i++)
	{
		LogTest(client, LogType_Info, "TF2Attrib_GetSOCAttribs Attrib %d: %d = %f", i, iAttribIndices[i], fAttribValues[i]);

		if (iAttribIndices[i] == ATTR_CUSTOM_NAME_ATTR)
			bHasCustomNameAttr = true;
	}

	if (!bHasCustomNameAttr)
		LogTest(client, LogType_Warn, "Tested item does not have 'custom_name_attr' attribute (name tag). " ...
			"TF2Attrib_HookValueString will have a warning.");

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_AddCustomPlayerAttribute(int client)
{
	char sTest[] = "TF2Attrib_AddCustomPlayerAttribute, TF2Attrib_RemoveCustomPlayerAttribute (Duration not automatically tested)";
	LogTest(client, LogType_Start, sTest);

	LogTest(client, LogType_Info, "TF2Attrib_AddCustomPlayerAttribute '%s' to value %f", g_sTestAttribNameFloat, g_fTestAttribValue);
	TF2Attrib_AddCustomPlayerAttribute(client, g_sTestAttribNameFloat, g_fTestAttribValue, 4.0);

	Address pCEconItemAttribute = TF2Attrib_GetByName(client, g_sTestAttribNameFloat);

	if (!pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetByName returned Address_Null");
		return;
	}

	float fValue = TF2Attrib_GetValue(pCEconItemAttribute);

	if (fValue != g_fTestAttribValue)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetValue returned %f, expected %f", fValue, g_fTestAttribValue);
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_RemoveCustomPlayerAttribute '%s'", g_sTestAttribNameFloat);
	TF2Attrib_RemoveCustomPlayerAttribute(client, g_sTestAttribNameFloat);

	pCEconItemAttribute = TF2Attrib_GetByName(client, g_sTestAttribNameFloat);

	if (pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveCustomPlayerAttribute failed, attribute still present");
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_HookValueFloat(int client, int entity)
{
	char sTest[] = "TF2Attrib_HookValueFloat";
	LogTest(client, LogType_Start, sTest);

	if (!TF2Attrib_SetByName(entity, g_sTestAttribNameFloat, g_fTestAttribValue))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetByName returned false");
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_HookValueFloat on attribute_class '%s'", g_sTestAttribClassFloat);
	float fInitial = 2.0; // Actually 1.0, but 2.0 tests better
	float fValue = TF2Attrib_HookValueFloat(fInitial, g_sTestAttribClassFloat, entity);

	if (!TF2Attrib_RemoveByName(entity, g_sTestAttribNameFloat))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveByName returned false");
		return;
	}

	float fExpected = fInitial * g_fTestAttribValue;

	if (fValue != fExpected)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_HookValueFloat returned %f, expected %f", fValue, fExpected);
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_HookValueInt(int client, int entity)
{
	char sTest[] = "TF2Attrib_HookValueInt";
	LogTest(client, LogType_Start, sTest);

	if (!TF2Attrib_SetByName(entity, g_sTestAttribNameFloat, g_fTestAttribValue))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetByName returned false");
		return;
	}

	// the hooked result must differ from the initial for this to test anything, so use a non-zero initial with
	// a multiplicative attribute; that also exercises the float-to-int conversion the int native does on the way out
	LogTest(client, LogType_Info, "TF2Attrib_HookValueInt on attribute_class '%s'", g_sTestAttribClassFloat);
	int iInitial = 2;
	int iValue = TF2Attrib_HookValueInt(iInitial, g_sTestAttribClassFloat, entity);

	if (!TF2Attrib_RemoveByName(entity, g_sTestAttribNameFloat))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveByName returned false");
		return;
	}

	int iExpected = RoundToNearest(float(iInitial) * g_fTestAttribValue);
	if (iValue != iExpected)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_HookValueInt returned %d, expected %d", iValue, iExpected);
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_HookValueString(int client, int iWeapon)
{
	char sTest[] = "TF2Attrib_HookValueString";
	LogTest(client, LogType_Start, sTest);

	char sInitial[] = " yip!";

	LogTest(client, LogType_Info, "TF2Attrib_HookValueString on 'custom_name_attr'");
	char sNameTag[64];
	int iLen = TF2Attrib_HookValueString(sInitial, "custom_name_attr", iWeapon, sNameTag, sizeof(sNameTag));

	if (!iLen)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_HookValueString failed, returned length 0. " ...
			"Should at least return sInitial length(%d) if tested on item without 'custom_name_attr' attribute (name tag)", sizeof(sInitial) - 1);
		return;
	}

	if (!strncmp(sNameTag, sInitial, sizeof(sInitial) - 1))
	{
		LogTest(client, LogType_Warn, "TF2Attrib_HookValueString output matches initial string. " ...
			"This should only happen if tested on an item without 'custom_name_attr' attribute (name tag), " ...
			"probably fine though if so and no crash");
	}
	else
	{
		LogTest(client, LogType_Info, "TF2Attrib_HookValueString returned name tag '%s'", sNameTag);
	}

	// This just checks that passing an empty initial string doesn't trigger the null address error: "NULL Address not allowed"
	LogTest(client, LogType_Info, "TF2Attrib_HookValueString with empty initial string passed in");
	TF2Attrib_HookValueString("", "custom_name_attr", iWeapon, sNameTag, sizeof(sNameTag));

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_SetRefundableCurrency(int client, int entity)
{
	char sTest[] = "TF2Attrib_SetRefundableCurrency, TF2Attrib_GetRefundableCurrency";
	LogTest(client, LogType_Start, sTest);

	if (!TF2Attrib_SetByDefIndex(entity, g_iTestAttribDefIndexFloat, g_fTestAttribValue))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetByDefIndex");
		return;
	}

	Address pCEconItemAttribute = TF2Attrib_GetByDefIndex(entity, g_iTestAttribDefIndexFloat);

	if (!pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetByDefIndex returned Address_Null");
		return;
	}

	int iSetCurrency = 150;

	LogTest(client, LogType_Info, "TF2Attrib_SetRefundableCurrency to %d", iSetCurrency);
	TF2Attrib_SetRefundableCurrency(pCEconItemAttribute, iSetCurrency);

	LogTest(client, LogType_Info, "TF2Attrib_GetRefundableCurrency on virtual address 0x%lX", pCEconItemAttribute);
	int iCurrency = TF2Attrib_GetRefundableCurrency(pCEconItemAttribute);

	if (iCurrency != iSetCurrency)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetRefundableCurrency returned %d, expected %d", iCurrency, iSetCurrency);
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_SetGet_ClearCache(int client, int entity)
{
	char sTest[] = "TF2Attrib_SetDefIndex, TF2Attrib_GetDefIndex, TF2Attrib_SetValue, TF2Attrib_ClearCache";
	LogTest(client, LogType_Start, sTest);

	if (!TF2Attrib_SetByDefIndex(entity, g_iTestAttribDefIndexFloat, g_fTestAttribValue))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetByDefIndex");
		return;
	}

	Address pCEconItemAttribute = TF2Attrib_GetByDefIndex(entity, g_iTestAttribDefIndexFloat);

	if (!pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetByDefIndex returned Address_Null");
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_GetDefIndex virtual address 0x%lX", pCEconItemAttribute);
	int iDefIndex = TF2Attrib_GetDefIndex(pCEconItemAttribute);

	if (iDefIndex != g_iTestAttribDefIndexFloat)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetDefIndex returned %d, expected %d", iDefIndex, g_iTestAttribDefIndexFloat);
		return;
	}

	int iNewDefIndex = ATTR_HEALTH_REGEN;

	LogTest(client, LogType_Info, "TF2Attrib_SetDefIndex to %d", iNewDefIndex);
	TF2Attrib_SetDefIndex(pCEconItemAttribute, iNewDefIndex);
	iDefIndex = TF2Attrib_GetDefIndex(pCEconItemAttribute);

	if (iDefIndex != iNewDefIndex)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetDefIndex failed, expected %d but got %d", iNewDefIndex, iDefIndex);
		return;
	}

	float fSetValue = 10.0;
	TF2Attrib_SetValue(pCEconItemAttribute, fSetValue);
	float fGetValue = TF2Attrib_GetValue(pCEconItemAttribute);

	if (fGetValue != fSetValue)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetValue/GetValue returned %f, expected %f", fGetValue, fSetValue);
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_ClearCache");
	if (!TF2Attrib_ClearCache(entity))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_ClearCache returned false, entity had invalid address or m_AttributeList missing");
		return;
	}

	if (!TF2Attrib_RemoveByDefIndex(entity, iNewDefIndex))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveByDefIndex failed, further tests will be tainted");
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_SetFromStringValue(int client, int entity)
{
	char sTest[] = "TF2Attrib_SetFromStringValue, TF2Attrib_UnsafeGetStringValue";
	LogTest(client, LogType_Start, sTest);

	LogTest(client, LogType_Info, "TF2Attrib_SetFromStringValue networked '%s' to value '%s'", g_sTestAttribNameFloat, g_sTestAttribValue);
	if (!TF2Attrib_SetFromStringValue(entity, g_sTestAttribNameFloat, g_sTestAttribValue))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetFromStringValue returned false for float attribute");
		return;
	}

	Address pCEconItemAttribute = TF2Attrib_GetByName(entity, g_sTestAttribNameFloat);

	if (!pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetByName returned Address_Null");
		return;
	}

	float fValue = TF2Attrib_GetValue(pCEconItemAttribute);

	if (fValue != g_fTestAttribValue)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetFromStringValue resulted in value %f, expected %f", fValue, g_fTestAttribValue);
		return;
	}

	if (!TF2Attrib_RemoveByName(entity, g_sTestAttribNameFloat))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveByName failed");
		return;
	}

	char sTestStringValue[] = "2007-10-10 21:09:46";
	char sSValue[sizeof(sTestStringValue)];

	if (Address_PointerSize == view_as<Address>(8))
	{
		// non-networked string attributes can't be stored in the runtime list on 64-bit
		LogTest(client, LogType_Info, "Skipping non-networked string attribute on 64-bit (set throws, raw reads are unsupported)");
		LogTest(client, LogType_Passed, sTest);
		return;
	}

	LogTest(client, LogType_Info, "TF2Attrib_SetFromStringValue non-networked '%s' to value '%s'", g_sTestAttribNameString, sTestStringValue);
	bool bSet = TF2Attrib_SetFromStringValue(entity, g_sTestAttribNameString, sTestStringValue);

	if (!bSet)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetFromStringValue returned false for string attribute");
		return;
	}

	pCEconItemAttribute = TF2Attrib_GetByName(entity, g_sTestAttribNameString);

	if (!pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_GetByName returned Address_Null for string attribute");
		return;
	}

	fValue = TF2Attrib_GetValue(pCEconItemAttribute);

	// on 32-bit the runtime m_flValue holds the heap pointer, reconstruct it as an Address
	Address pRawValue = view_as<Address>(view_as<int>(fValue)) & ((view_as<Address>(1) << 32) - view_as<Address>(1));
	LogTest(client, LogType_Info, "TF2Attrib_UnsafeGetStringValue on runtime m_flValue, which is storing virtual address 0x%lX", pRawValue);
	TF2Attrib_UnsafeGetStringValue(pRawValue, sSValue, sizeof(sSValue));

	if (strncmp(sSValue, sTestStringValue, sizeof(sTestStringValue)) != 0)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetFromStringValue resulted in string value '%s', expected '%s'", sSValue, sTestStringValue);
		return;
	}

	TF2Attrib_SetFromStringValue(entity, g_sTestAttribNameString, "");

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_MultipleAttributes(int client, int entity)
{
	char sTest[] = "Multiple runtime attributes (TF2Attrib_ListDefIndices stride, CUtlVector growth)";
	LogTest(client, LogType_Start, sTest);

	// storing several runtime attributes at once exercises reading past the first list element, covering the
	// CEconItemAttribute stride and the CUtlVector growth path rather than just the single-element case
	int iDefIndices[] = { ATTR_MAJOR_MOVE_SPEED_BONUS, ATTR_DAMAGE_CAUSES_AIRBLAST, ATTR_HEALTH_REGEN };
	float fValues[] = { 3.0, 1.0, 5.0 };
	int iCount = sizeof(iDefIndices);

	for (int i = 0; i < iCount; i++)
	{
		if (!TF2Attrib_SetByDefIndex(entity, iDefIndices[i], fValues[i]))
		{
			LogTest(client, LogType_Failed, "TF2Attrib_SetByDefIndex returned false for %d", iDefIndices[i]);
			TF2Attrib_RemoveAll(entity);
			return;
		}
	}

	int iAttribIndices[TF2ATTRIB_MAX_ITEM_ATTRIBUTES];
	int iNumAttr = TF2Attrib_ListDefIndices(entity, iAttribIndices);
	LogTest(client, LogType_Info, "TF2Attrib_ListDefIndices iNumAttr: %d", iNumAttr);

	for (int i = 0; i < iCount; i++)
	{
		// every attribute we set must come back from ListDefIndices, which walks the list by element
		// stride; a wrong stride reads garbage for everything past the first entry
		bool bListed = false;
		for (int j = 0; j < iNumAttr; j++)
		{
			if (iAttribIndices[j] == iDefIndices[i])
			{
				bListed = true;
				break;
			}
		}

		if (!bListed)
		{
			LogTest(client, LogType_Failed, "TF2Attrib_ListDefIndices did not return attribute %d", iDefIndices[i]);
			TF2Attrib_RemoveAll(entity);
			return;
		}

		Address pCEconItemAttribute = TF2Attrib_GetByDefIndex(entity, iDefIndices[i]);
		if (!pCEconItemAttribute)
		{
			LogTest(client, LogType_Failed, "TF2Attrib_GetByDefIndex returned Address_Null for %d", iDefIndices[i]);
			TF2Attrib_RemoveAll(entity);
			return;
		}

		float fValue = TF2Attrib_GetValue(pCEconItemAttribute);
		if (fValue != fValues[i])
		{
			LogTest(client, LogType_Failed, "TF2Attrib_GetValue for %d returned %f, expected %f", iDefIndices[i], fValue, fValues[i]);
			TF2Attrib_RemoveAll(entity);
			return;
		}

		LogTest(client, LogType_Info, "TF2Attrib_GetByDefIndex %d = %f", iDefIndices[i], fValue);
	}

	TF2Attrib_RemoveAll(entity);

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_HookValueStress(int client, int entity)
{
	char sTest[] = "TF2Attrib_HookValue repeated-call stress";
	LogTest(client, LogType_Start, sTest);

	if (!TF2Attrib_SetByName(entity, g_sTestAttribNameFloat, g_fTestAttribValue))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetByName returned false");
		return;
	}

	// hammer the hooks to shake out a calling-convention or stack imbalance and pooled-string leaks that a
	// single call hides, mainly the windows64 hidden-return-pointer path used by the string hook
	int iIterations = 1000;
	float fExpected = 2.0 * g_fTestAttribValue;
	char sNameTag[64];

	for (int i = 0; i < iIterations; i++)
	{
		float fValue = TF2Attrib_HookValueFloat(2.0, g_sTestAttribClassFloat, entity);
		if (fValue != fExpected)
		{
			LogTest(client, LogType_Failed, "TF2Attrib_HookValueFloat returned %f on iteration %d, expected %f", fValue, i, fExpected);
			TF2Attrib_RemoveByName(entity, g_sTestAttribNameFloat);
			return;
		}

		TF2Attrib_HookValueString(" yip!", "custom_name_attr", entity, sNameTag, sizeof(sNameTag));
	}

	if (!TF2Attrib_RemoveByName(entity, g_sTestAttribNameFloat))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveByName returned false");
		return;
	}

	LogTest(client, LogType_Info, "Completed %d hook iterations with no errors or crash", iIterations);
	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Attrib_RemoveAll(int client, int entity)
{
	char sTest[] = "TF2Attrib_RemoveAll";
	LogTest(client, LogType_Start, sTest);

	if (!TF2Attrib_SetByDefIndex(entity, g_iTestAttribDefIndexFloat, g_fTestAttribValue))
	{
		LogTest(client, LogType_Failed, "TF2Attrib_SetByDefIndex");
		return;
	}

	TF2Attrib_RemoveAll(entity);

	Address pCEconItemAttribute = TF2Attrib_GetByDefIndex(entity, g_iTestAttribDefIndexFloat);

	if (pCEconItemAttribute)
	{
		LogTest(client, LogType_Failed, "TF2Attrib_RemoveAll failed, test attribute still present");
		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void LogTest(int client, LogType logType, const char[] sFormat, any ...)
{
	static const char sLogPrefix[LogType][] =
	{
		LOG_PREFIX_START,
		LOG_PREFIX_PASS,
		LOG_PREFIX_FAIL,
		LOG_PREFIX_WARN,
		LOG_PREFIX_INFO
	};

	static char sBuffer[256];
	VFormat(sBuffer, sizeof(sBuffer), sFormat, 4);

	LogToGame("%s%s", sLogPrefix[logType], sBuffer);
	PrintToConsole(client, "%s%s", sLogPrefix[logType], sBuffer);

	switch (logType)
	{
		case LogType_Start:
			++g_iTestsTotal;
		case LogType_Passed:
			++g_iTestsPassed;
		case LogType_Warn:
			++g_iTestWarnings;
	}
}