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
native bool TF2Attrib_SetByName(int iEntity, const char[] strAttrib, float flValue);

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
native bool TF2Attrib_SetByDefIndex(int iEntity, int iDefIndex, float flValue);

/**
 * Parses the attribute name and value strings and applies it on the entity.  This parses
 * numeric and string attributes.
 * 
 * If you use this on a non-numeric attribute, make sure that only the server reads off of that
 * attribute.  Non-primitive values aren't replicated correctly between the client and the
 * server; the client will read garbage and may crash!
 * 
 * @param iEntity		Entity index to set the attribute on. Must have m_AttributeList.
 * @param strAttrib		Name of the attribute, as from the "name" key in items_game.
 * @param strValue		Value to set the attribute to.
 * 
 * @return				True if the attribute was added successfully, false if the attribute name was invalid.
 * @error				Invalid entity index or entity does not have m_AttributeList.
 */
native bool TF2Attrib_SetFromStringValue(int iEntity, const char[] strAttrib, const char[] strValue);

/**
 * Returns the address of an attribute on an entity.
 *
 * @param iEntity		Entity index to get attribute from. Must have m_AttributeList.
 * @param strAttrib		Name of the attribute, as from the "name" key in items_game.
 *
 * @return				Address of the attribute on the entity, or Address_Null if the attribute does not exist on the entity.
 * @error				Invalid entity index or attribute name passed.
 */
native Address TF2Attrib_GetByName(int iEntity, const char[] strAttrib);

/**
 * Returns the address of an attribute (by attribute index) on an entity.
 *
 * @param iEntity		Entity index to get attribute from. Must have m_AttributeList.
 * @param iDefIndex		Definition index of the attribute, as from the number on the attribute entry in items_game.
 *
 * @return				Address of the attribute on the entity, or Address_Null if the attribute does not exist on the entity.
 * @error				Invalid entity index or attribute index passed.
 */
native Address TF2Attrib_GetByDefIndex(int iEntity, int iDefIndex);

/**
 * Removes an attribute from an entity.
 *
 * @param iEntity		Entity index to remove attribute from. Must have m_AttributeList.
 * @param strAttrib		Name of the attribute, as from the "name" key in items_game.
 *
 * @return				True if the SDKCall was made, false if entity had invalid address or m_AttributeList missing.
 * @error				Invalid entity index or attribute name passed.
 */
native bool TF2Attrib_RemoveByName(int iEntity, const char[] strAttrib);

/**
 * Removes an attribute from an entity.
 *
 * @param iEntity		Entity index to remove attribute from. Must have m_AttributeList.
 * @param iDefIndex		Definition index of the attribute, as from the number on the attribute entry in items_game.
 *
 * @return				True if the SDKCall was made, false if entity had invalid address or m_AttributeList missing.
 * @error				Invalid entity index or attribute index passed.
 */
native bool TF2Attrib_RemoveByDefIndex(int iEntity, int iDefIndex);

/**
 * Removes all attributes from an entity.
 *
 * @param iEntity		Entity index to remove attribute from. Must have m_AttributeList.
 *
 * @return				True if the SDKCall was made, false if entity had invalid address or m_AttributeList missing.
 * @error				Invalid entity index passed.
 */
native bool TF2Attrib_RemoveAll(int iEntity);

/**
 * Clears and presumably rebuilds the attribute cache for an entity, 'refreshing' attributes.
 * Call this after making changes to an attribute with any of the TF2Attrib_Set*(Address pAttrib, arg) natives below.
 * You may also need to call this on the entity's m_hOwnerEntity if it is a weapon or wearable.
 * You do NOT need to call this after calls to TF2Attrib_SetByName, TF2Attrib_Remove, and TF2Attrib_RemoveAll.
 *
 * @param iEntity		Entity index to remove attribute from. Must have m_AttributeList.
 *
 * @return				True if the SDKCall was made, false if entity had invalid address or m_AttributeList missing.
 * @error				Invalid entity index passed.
 */
native bool TF2Attrib_ClearCache(int iEntity);

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
native void TF2Attrib_SetDefIndex(Address pAttrib, int iDefIndex);

/**
 * Returns the value of m_iAttributeDefinitionIndex (the attribute ID) on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 *
 * @return				The integer value of m_iAttributeDefinitionIndex on the attribute.
 */
native int TF2Attrib_GetDefIndex(Address pAttrib);

/**
 * Sets the value of m_flValue on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 * @param flValue		Value to set m_flValue to.
 *
 * @noreturn
 */
native void TF2Attrib_SetValue(Address pAttrib, float flValue);

/**
 * Returns the value of m_flValue on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 *
 * @return				The floating point value of m_flValue on the attribute.
 */
native float TF2Attrib_GetValue(Address pAttrib);

/**
 * Returns the string data from its raw value representation (a CAttribute_String instance).
 * 
 * WARNING: This dereferences the input value!  Feeding it values that aren't CAttribute_String pointers will result in unexpected behavior, potentially crashing the server.
 * In the case where you only want the currently active value, use TF2Attrib_HookValueString instead.
 * 
 * @param pRawValue		Raw attribute value.  You can get this value with either TF2Attrib_GetValue, TF2Attrib_GetSOCAttribs, or TF2Attrib_GetStaticAttribs.
 * @param buffer		Buffer to store the resulting string to.
 * @param maxlen		Maximum length of the buffer.
 * 
 * @return Number of bytes written.
 */
native int TF2Attrib_UnsafeGetStringValue(any pRawValue, char[] buffer, int maxlen);

/**
 * Sets the value of m_nRefundableCurrency on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 * @param nCurrency		Value to set m_nRefundableCurrency to.
 *
 * @noreturn
 */
native void TF2Attrib_SetRefundableCurrency(Address pAttrib, int nCurrency);

/**
 * Returns the value of m_nRefundableCurrency on an attribute.
 *
 * @param pAttrib		Address of the attribute.
 *
 * @return				The (unsigned) integer value of m_nRefundableCurrency on the attribute.
 */
native int TF2Attrib_GetRefundableCurrency(Address pAttrib);

/**
 * Returns an array containing the attributes (as indices) present on an entity.
 *
 * @param iEntity		Entity index to get attribute list from. Must have m_AttributeList.
 * @param iDefIndices	Array of attribute definition indices found on the entity.
 * @param iMaxLen		Max length of the iDefIndices array, default 20. Does not affect the return value.
 *
 * @return				The number of attributes found on the entity's attribute list (max 20 as of Oct 2017), or -1 if some error happened.
 * @error				Invalid iEntity or iMaxLen.
 */
native int TF2Attrib_ListDefIndices(int iEntity, int[] iDefIndices, int iMaxLen=20);

/**
 * Returns arrays containing the static attributes and their values present on an item definition.
 *
 * @param iItemDefIndex		Item definition index (e.g. 7 for Shovel) to get static attribute list from.
 * @param iAttribIndices	Array of attribute definition indices found on the item definition.
 * @param flAttribValues	Array of attribute values found on the item definition, corresponding to the indices.
 * @param iMaxLen			Max length of the two arrays passed in, default 16. Does not affect the return value.
 *
 * @return					The number of attributes found on the item definition's static attribute list (max 16 as of June 2017), or -1 if no schema or item definition found.
 * @error					Invalid iMaxLen, or gamedata for this function failed to load.
 */
native int TF2Attrib_GetStaticAttribs(int iItemDefIndex, int[] iAttribIndices, float[] flAttribValues, int iMaxLen=16);

/**
 * Returns arrays containing the item server (SOC) attributes and their values present on an item definition.
 *
 * @param iEntity			Entity index to get the item server attribute list from.
 * @param iAttribIndices	Array of attribute definition indices found.
 * @param flAttribValues	Array of attribute values found, corresponding to the indices.
 * @param iMaxLen			Max length of the two arrays passed in, default 16. Does not affect the return value.
 *
 * @return					The number of attributes found on the item's SOC attribute list (max 16 as of June 2017), or -1 if some error happened.
 * @error					Invalid iEntity or iMaxLen, or gamedata for this function failed to load.
 */
native int TF2Attrib_GetSOCAttribs(int iEntity, int[] iAttribIndices, float[] flAttribValues, int iMaxLen=16);

/**
 * Gets whether an attribute is stored as an integer or as a float.
 * Use TF2Attrib_SetValue(attribute, view_as<float>(intValue)) on attributes that store values as ints
 *   to avoid compiler tag mismatch warnings.
 *
 * @param iDefIndex		Index of the attribute (as returned by TF2Attrib_GetDefIndex()).
 *
 * @return				True if attribute value is supposed to be an int, false if float.
 */
native bool TF2Attrib_IsIntegerValue(int iDefIndex);

/**
 * Returns true if an attribute with the specified name exists.
 *
 * @param strAttrib			Name of the attribute, as from the "name" key in items_game.
 *
 * @return					True if the attribute exists, false otherwise.
 */
native bool TF2Attrib_IsValidAttributeName(const char[] strAttrib);

/** 
 * Adds a custom, potentially temporary attribute to a player.
 * 
 * @param client			Client index to set the attribute on.
 * @param strAttrib			Name of the attribute, as from the "name" key in items_game.
 * @param flValue			Value to set m_flValue to.
 * @param flDuration		Duration of the attribute.  If less than 0, the attribute will not be automatically removed.
 * 
 * @noreturn
 */
native void TF2Attrib_AddCustomPlayerAttribute(int client, const char[] strAttrib, float flValue, float flDuration = -1.0);

/**
 * Removes a previously applied custom attribute on a player.
 *
 * @param client			Client index to remove the attribute from.
 * @param strAttrib			Name of the attribute, as from the "name" key in items_game.
 *
 * @noreturn
 */
native void TF2Attrib_RemoveCustomPlayerAttribute(int client, const char[] strAttrib);

/**
 * Applies a transformation to the given initial value, following the rules according to the given attribute class.
 * 
 * @param flInitial			Initial float value.
 * @param attrClass			The attribute class, as from the "attribute_class" key in items_game.
 * @param iEntity			The entity that should be checked.  Checking players also checks their equipped items.
 * 
 * @return					Transformed initial value.
 */
native float TF2Attrib_HookValueFloat(float flInitial, const char[] attrClass, int iEntity);

/**
 * Applies a transformation to the given initial value, following the rules according to the given attribute class.
 * 
 * @param nInitial			Initial integer value.
 * @param attrClass			The attribute class, as from the "attribute_class" key in items_game.
 * @param iEntity			The entity that should be checked.  Checking players also checks their equipped items.
 * 
 * @return					Transformed initial value.
 */
native int TF2Attrib_HookValueInt(int nInitial, const char[] attrClass, int iEntity);

/**
 * Applies a transformation to the given initial value, following the rules according to the given attribute class.
 * 
 * @param initial			Initial string value.  (This appears to only be returned if the entity doesn't have the attribute.)
 * @param attrClass			The attribute class, as from the "attribute_class" key in items_game.
 * @param iEntity			The entity that should be checked.  Checking players also checks their equipped items.
 * @param buffer			Transformed initial value.
 * @param maxlen			Buffer size.
 * 
 * @return					Number of bytes written.
 */
native int TF2Attrib_HookValueString(const char[] initial, const char[] attrClass, int iEntity, char[] buffer, int maxlen);

/**
 * Gets whether the plugin loaded without ANY errors.
 * For the purpose of allowing dependencies to ignore the plugin if this returns false.
 * Check in OnAllPluginsLoaded() or something. I dunno.
 *
 * @return				True if no errors while loading, false otherwise.
 */
native bool TF2Attrib_IsReady();

public SharedPlugin __pl_tf2attributes =
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
public void __pl_tf2attributes_SetNTVOptional()
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
	MarkNativeAsOptional("TF2Attrib_SetRefundableCurrency");
	MarkNativeAsOptional("TF2Attrib_GetRefundableCurrency");
	MarkNativeAsOptional("TF2Attrib_ListDefIndices");
	MarkNativeAsOptional("TF2Attrib_GetStaticAttribs");
	MarkNativeAsOptional("TF2Attrib_GetSOCAttribs");
	MarkNativeAsOptional("TF2Attrib_ListDefIndices");
	MarkNativeAsOptional("TF2Attrib_IsIntegerValue");
	MarkNativeAsOptional("TF2Attrib_IsValidAttributeName");
	MarkNativeAsOptional("TF2Attrib_AddCustomPlayerAttribute");
	MarkNativeAsOptional("TF2Attrib_RemoveCustomPlayerAttribute");
	MarkNativeAsOptional("TF2Attrib_HookValueFloat");
	MarkNativeAsOptional("TF2Attrib_HookValueInt");
	
	MarkNativeAsOptional("TF2Attrib_IsReady");
}
#endif
