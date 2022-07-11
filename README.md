# tf2attributes

TF2Attributes SourceMod plugin

https://forums.alliedmods.net/showthread.php?t=210221

## Differences from FlaminSarge's upstream

This fork provides the following new functionality:

Add / remove temporary attributes on the player (using the game's own time-based expiry
mechanism for it).

```sourcepawn
// replicates the temporary health bonus granted by the Dalokohs Bar:
TF2Attrib_AddCustomPlayerAttribute(client, "hidden maxhealth non buffed", 50.0, 30.0);
```

Adds the game's "attribute hook" mechanism that collates values using an attribute class:

```sourcepawn
// computes the final damage multiplier based on the given item and owner's attributes:
float damageBonus = TF2Attrib_HookValueFloat(1.0, "mult_dmg", weapon);
```

Support for setting / getting attribute values via strings:

```sourcepawn
// set an entity's custom projectile model:
TF2Attrib_SetFromStringValue(entity, "custom projectile model", "models/weapons/c_models/c_grenadelauncher/c_grenadelauncher.mdl");

// get the name from an item:
TF2Attrib_HookValueString("NO NAME", "custom_name_attr", entity, buffer, sizeof(buffer));
```

Setting custom names / descriptions is not possible.  String values that are set by this plugin
are not replicated to the client &mdash; this is fine for attributes that are only accessed on
the server, but if you set any that the client will read, the client will crash on access.

## Installing or migrating

This fork is forward compatible with FlaminSarge/tf2attributes &mdash; all plugins compiled for
their version should continue to work with this one.  The installation instructions remain the
same.

1. Download all the non-source code files in [the latest release][].
2. Copy `tf2attributes.smx` to `addons/sourcemod/plugins/`.
3. Copy `tf2.attributes.txt` to `addons/sourcemod/gamedata/`.
4. If you're a developer, copy `tf2attributes.inc` to `addons/sourcemod/scripting/include/`
(or the appropriate path for your compiler toolchain / project).

[the latest release]: https://github.com/nosoop/tf2attributes/releases
