/** Double-include prevention */
#if defined _sakprotection_included_
  #endinput
#endif
#define _sakprotection_included_

public SharedPlugin:__pl_sakprotection = 
{
	name = "sakprotection",
	file = "spawnandkillprotection.smx",

#if (defined REQUIRE_PLUGIN)
	required = 1
#else
	required = 0
#endif // REQUIRE_PLUGIN
};

#if (!defined REQUIRE_PLUGIN)
public __pl_sakprotection_SetNTVOptional()
{
	MarkNativeAsOptional("SAKP_IsClientProtected");
}
#endif // !REQUIRE_PLUGIN

/**
 * Returns if a client is currently protected.
 *
 * @param client    Client index.
 * @param wall      True if client is wall-protected, false otherwise.
 * @return          Returns true if the client is protected otherwise false.
 */
native bool:SAKP_IsClientProtected(client, &bool:wall = false);
