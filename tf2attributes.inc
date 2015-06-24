#if defined _tf2attributes_included
  #endinput
#endif
#define _tf2attributes_included

/**
 * Sets an attribute's value on an entity, adding it if it isn't on the entity.
 *
 * @param iEntity		Entity index to set the attribute on. Must have m_AttributeList.
 * @param strAttrib		Name of the attribute, as from the "name" key in items_game.
 * @param flValue		Value to set the attribute to
 *
 * @return				True if the attribute was added successfully, false if entity does not have m_AttributeList.
 * @error				Invalid entity index or attribute name passed.
 */
native bool:TF2Attrib_SetByName(iEntity, String:strAttrib[], Float:flValue);

/**
 * Sets an attribute's value on an entity, adding it if it isn't on the entity.
 *
 * @param iEntity		Entity index to set the attribute on. Must have m_AttributeList.
 * @param iDefIndex		Definition index of the attribute, as from the number on the attribute entry in items_game.
 * @param flValue		Value to set the attribute to
 *
 * @return				True if the attribute was added successfully, false if entity does not have m_AttributeList.
 * @error				Invalid entity index or attribute name passed.
 */
native bool:TF2Attrib_SetByDefIndex(iEntity, iDefIndex, Float:flValue);

/**
 * Returns the address of an attribute on an entity.
 *
 * @param iEntity		Entity index to get attribute from. Must have m_AttributeList.
 * @param strAttrib		Name of the attribute, as from the "name" key in items_game.
 *
 * @return				Address of the attribute on the entity, or Address_Null if the attribute does not exist on the entity.
 * @error				Invalid entity index or attribute name passed.
 */
native Address:TF2Attrib_GetByName(iEntity, String:strAttrib[]);

/**
 * Returns the address of an attribute (by attribute index) on an entity.
 *
 * @param iEntity		Entity index to get attribute from. Must have m_AttributeList.
 * @param iDefIndex		Definition index of the attribute, as from the number on the attribute entry in items_game.
 *
 * @return				Address of the attribute on the entity, or Address_Null if the attribute does not exist on the entity.
 * @error				Invalid entity index or attribute index passed.
 */
native Address:TF2Attrib_GetByDefIndex(iEntity, iDefIndex);

/**
 * Removes an attribute from an entity.
 *
 * @param iEntity		Entity index to remove attribute from. Must have m_AttributeList.
 * @param strAttrib		Name of the attribute, as from the "name" key in items_game.
 *
 * @return				True if the SDKCall was made, false if entity had invalid address or m_AttributeList missing.
 * @error				Invalid entity index or attribute name passed.
 */
native bool:TF2Attrib_RemoveByName(iEntity, String:strAttrib[]);

/**
 * Removes an attribute from an entity.
 *
 * @param iEntity		Entity index to remove attribute from. Must have m_AttributeList.
 * @param iDefIndex		Definition index of the attribute, as from the number on the attribute entry in items_game.
 *
 * @return				True if the SDKCall was made, false if entity had invalid address or m_AttributeList missing.
 * @error				Invalid entity index or attribute index passed.
 */
native bool:TF2Attrib_RemoveByDefIndex(iEntity, iDefIndex);

/**
 * Removes all attributes from an entity.
 *
 * @param iEntity		Entity index to remove attribute from. Must have m_AttributeList.
 *
 * @return				True if the SDKCall was made, false if entity had invalid address or m_AttributeList missing.
 * @error				Invalid entity index passed.
 */
native bool:TF2Attrib_RemoveAll(iEntity);

/**
 * WARNING: Currently silently fails because I haven't tested it and I don't want it crashing.
 *
 * Clears and presumably rebuilds the attribute cache for an entity, 'refreshing' attributes.
 * Call this after making changes to an attribute with any of the TF2Attrib_Set*(Address:pAttrib, arg) natives below.
 * You may also need to call this on the entity's m_hOwnerEntity if it is a weapon or wearable.
 * You do NOT need to call this after calls to TF2Attrib_SetByName, TF2Attrib_Remove, and TF2Attrib_RemoveAll.
 *
 * @param iEntity		Entity index to remove attribute from. Must have m_AttributeList.
 *
 * @return				True if the SDKCall was made, false if entity had invalid address or m_AttributeList missing.
 * @error				Invalid entity index passed.
 */
native bool:TF2Attrib_ClearCache(iEntity);

/**
 * Sets the value of m_iAttributeDefinitionIndex (the attribute ID) on an attribute.
 * Warning, this changes what GetByName/ID and SetByName 'see' as the name of the attribute,
 * but will only change attribute's effects if TF2Attrib_ClearCache is called on the entity with the attribute after.
 *
 * @param pAttrib		Address of the attribute.
 * @param iDefIndex		Value to set m_iAttributeDefinitionIndex to.
 *
 * @noreturn
 */
native TF2Attrib_SetDefIndex(Address:pAttrib, iDefIndex);

/**
 * Returns the value of m_iAttributeDefinitionIndex (the attribute ID) on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 *
 * @return				The integer value of m_iAttributeDefinitionIndex on the attribute.
 */
native TF2Attrib_GetDefIndex(Address:pAttrib);

/**
 * Sets the value of m_flValue on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 * @param flValue		Value to set m_flValue to.
 *
 * @noreturn
 */
native TF2Attrib_SetValue(Address:pAttrib, Float:flValue);

/**
 * Returns the value of m_flValue on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 *
 * @return				The floating point value of m_flValue on the attribute.
 */
native Float:TF2Attrib_GetValue(Address:pAttrib);

/**
 * Sets the value of m_nRefundableCurrency on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 * @param nCurrency		Value to set m_nRefundableCurrency to.
 *
 * @noreturn
 */
native TF2Attrib_SetRefundableCurrency(Address:pAttrib, nCurrency);

/**
 * Returns the value of m_nRefundableCurrency on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 *
 * @return				The (unsigned) integer value of m_nRefundableCurrency on the attribute.
 */
native TF2Attrib_GetRefundableCurrency(Address:pAttrib);

/**
 * Returns the value of m_nRefundableCurrency on an attribute.
 *
 * @param iEntity		Entity index to get attribute list from. Must have m_AttributeList.
 * @param iDefIndices	Array (max size 16) of attribute definition indices found on the entity.
 *
 * @return				The number of attributes found on the entity's attribute list, or -1 if some error happened.
 * @error				Invalid entity index passed.
 */
native TF2Attrib_ListDefIndices(iEntity, iDefIndices[]);

//flInitialValue and bSetBonus don't exist anymore
/**
 * Sets the value of m_flInitialValue on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 * @param flValue		Value to set m_flInitialValue to.
 *
 * @noreturn
 */
//native TF2Attrib_SetInitialValue(Address:pAttrib, Float:flValue);

/**
 * Returns the value of m_flInitialValue on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 *
 * @return				The floating point value of m_flInitialValue on the attribute.
 */
//native Float:TF2Attrib_GetInitialValue(Address:pAttrib);

/**
 * Sets the boolean value of m_bSetBonus on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 * @param bSetBonus		Value to set m_bSetBonus to.
 *
 * @noreturn
 */
//native TF2Attrib_SetIsSetBonus(Address:pAttrib, bool:bSetBonus);

/**
 * Returns the boolean value of m_bSetBonus on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 *
 * @return				The boolean value of m_bSetBonus on the attribute.
 */
//native bool:TF2Attrib_GetIsSetBonus(Address:pAttrib);

/**
 * Gets whether an attribute is stored as an integer or as a float.
 * Use TF2Attrib_SetValue(attribute, Float:intValue) on attributes that store values as ints.
 * 
 * @param iDefIndex		Index of the attribute (as returned by TF2Attrib_GetDefIndex()).
 *
 * @return				True if attribute value is supposed to be an int, false if float.
 */
stock TF2Attrib_IsIntegerValue(iDefIndex)
{
	switch (iDefIndex)
	{
		case 133, 143, 147, 152, 184, 185, 186, 192, 193, 194, 198, 211, 214, 227, 228, 229, 262, 294, 302, 372, 373, 374, 379, 381, 383, 403, 420:
		{
			return true;
		}
	}
	return false;
}

public SharedPlugin:__pl_tf2attributes = 
{
	name = "tf2attributes",
	file = "tf2attributes.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_tf2attributes_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Attrib_SetByName");
	MarkNativeAsOptional("TF2Attrib_SetByDefIndex");
	MarkNativeAsOptional("TF2Attrib_GetByName");
	MarkNativeAsOptional("TF2Attrib_GetByDefIndex");
	MarkNativeAsOptional("TF2Attrib_RemoveByName");
	MarkNativeAsOptional("TF2Attrib_RemoveByDefIndex");
	MarkNativeAsOptional("TF2Attrib_RemoveAll");
	MarkNativeAsOptional("TF2Attrib_ClearCache");
	MarkNativeAsOptional("TF2Attrib_SetDefIndex");
	MarkNativeAsOptional("TF2Attrib_GetDefIndex");
	MarkNativeAsOptional("TF2Attrib_SetValue");
	MarkNativeAsOptional("TF2Attrib_GetValue");
	MarkNativeAsOptional("TF2Attrib_SetInitialValue");
	MarkNativeAsOptional("TF2Attrib_GetInitialValue");
	MarkNativeAsOptional("TF2Attrib_SetRefundableCurrency");
	MarkNativeAsOptional("TF2Attrib_GetRefundableCurrency");
	MarkNativeAsOptional("TF2Attrib_SetIsSetBonus");
	MarkNativeAsOptional("TF2Attrib_GetIsSetBonus");
	MarkNativeAsOptional("TF2Attrib_ListDefIndices");
}
#endif
