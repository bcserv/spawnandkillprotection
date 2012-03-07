/** Double-include prevention */
#if defined _sakprotection_included_
  #endinput
#endif
#define _sakprotection_included_


public SharedPlugin:__pl_sakprotection = 
{
	name = "Spawn & Kill protection",
	file = "spawnandkillprotection.smx",
	required = 0
};


public __pl_sakprotection_SetNTVOptional()
{
	MarkNativeAsOptional("SAKP_IsClientProtected");
}



/**
 * Returns if a client is currently protected.
 *
 * @param client    Client index.
 * @return          Returns true if the client is protected otherwise false.
 */
native bool:SAKP_IsClientProtected(client);