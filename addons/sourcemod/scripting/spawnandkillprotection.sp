
// enforce semicolons after each code statement
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <smlib>

#define PLUGIN_VERSION "1.3.0 (ph)"

#define PROTECTED_HEALTH 500

#define KILLPROTECTION_DISABLE_BUTTONS (IN_ATTACK | IN_JUMP | IN_DUCK | IN_FORWARD | IN_BACK | IN_USE | IN_LEFT | IN_RIGHT | IN_MOVELEFT | IN_MOVERIGHT | IN_ATTACK2 | IN_RUN | IN_SPEED | IN_WALK | IN_GRENADE1 | IN_GRENADE2)
#define SHOOT_DISABLE_BUTTONS (IN_ATTACK | IN_ATTACK2)

/*****************************************************************


		P L U G I N   I N F O


*****************************************************************/

public Plugin:myinfo = {
	name = "Spawn & Kill protection (ph edition)",
	author = "Berni, Chanz",
	description = "Spawnprotection and Chat Kill Protection (ph edition)",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=901294"
}



/*****************************************************************


		G L O B A L   V A R S


*****************************************************************/

// ConVar Handles
new Handle:version				= INVALID_HANDLE;
new Handle:enabled				= INVALID_HANDLE;
new Handle:walltime				= INVALID_HANDLE;
new Handle:takedamage			= INVALID_HANDLE;
new Handle:punishmode			= INVALID_HANDLE;
new Handle:notify				= INVALID_HANDLE;
new Handle:noblock				= INVALID_HANDLE;
new Handle:disableonmoveshoot	= INVALID_HANDLE;
new Handle:disabletime			= INVALID_HANDLE;
new Handle:disabletime_team1	= INVALID_HANDLE;
new Handle:disabletime_team2	= INVALID_HANDLE;
new Handle:keypressignoretime	= INVALID_HANDLE;
new Handle:keypressignoretime_team1	= INVALID_HANDLE;
new Handle:keypressignoretime_team2	= INVALID_HANDLE;
new Handle:maxspawnprotection	= INVALID_HANDLE;
new Handle:maxspawnprotection_team1	= INVALID_HANDLE;
new Handle:maxspawnprotection_team2	= INVALID_HANDLE;
new Handle:fadescreen			= INVALID_HANDLE;
new Handle:hidehud				= INVALID_HANDLE;
new Handle:player_color_r		= INVALID_HANDLE;
new Handle:player_color_g		= INVALID_HANDLE;
new Handle:player_color_b		= INVALID_HANDLE;
new Handle:player_color_a		= INVALID_HANDLE;

// Misc
new bool:isKillProtected[MAXPLAYERS+1]		= { false, ... };
new bool:isSpawnKillProtected[MAXPLAYERS+1]	= { false, ... };
new bool:isWallKillProtected[MAXPLAYERS+1]	= { false, ... };
new Handle:activeDisableTimer[MAXPLAYERS+1] = { INVALID_HANDLE, ... };
new Float:keyPressOnTime[MAXPLAYERS+1]		= { 0.0, ... };
new timeLookingAtWall[MAXPLAYERS+1]			= { 0, ... };
new lastPlayerHealth[MAXPLAYERS+1]			= { 0, ... };
new Handle:hudSynchronizer					= INVALID_HANDLE;



/*****************************************************************


		F O R W A R D   P U B L I C S


*****************************************************************/

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{	
   CreateNative("SAKP_IsClientProtected", Native_IsClientProtected);
   return APLRes_Success;
}

public OnPluginStart()
{	
	// ConVars
	version = CreateConVar("sakp_version", PLUGIN_VERSION, "Spawn & Kill Protection plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	// Set it to the correct version, in case the plugin gets updated...
	SetConVarString(version, PLUGIN_VERSION);

	enabled				= CreateConVar("sakp_enabled",				"1",	"Spawn & Kill Protection enabled", FCVAR_PLUGIN);
	HookConVarChange(enabled, ConVarChange_Enabled);
	walltime			= CreateConVar("sakp_walltime",				"4",	"How long a player has to look at a wall to get kill protection activated, set to -1 to disable", FCVAR_PLUGIN);
	takedamage			= CreateConVar("sakp_takedamage",			"5",	"The amount of health to take from the player when shooting at protected players (when punishmode = 2)", FCVAR_PLUGIN);
	punishmode			= CreateConVar("sakp_punishmode",			"0",	"0 = off, 1 = slap, 2 = decrease health 3 = slay, 4 = apply damage done to enemy", FCVAR_PLUGIN);
	notify				= CreateConVar("sakp_notify",				"4",	"0 = off, 1 = HUD message, 2 = center message, 3 = chat message, 4 = auto", FCVAR_PLUGIN);
	HookConVarChange(notify, ConVarChange_Notify);
	noblock				= CreateConVar("sakp_noblock",				"1",	"1 = enable noblock when protected, 0 = disabled feature", FCVAR_PLUGIN);
	disableonmoveshoot	= CreateConVar("sakp_disableonmoveshoot",	"1",	"0 = don't disable, 1 = disable the spawnprotection when player moves or shoots, 2 = disable the spawn protection when shooting only", FCVAR_PLUGIN);
	disabletime			= CreateConVar("sakp_disabletime",			"0",	"Time in seconds until the protection is removed after the player moved and/or shooted, 0 = immediately", FCVAR_PLUGIN);
	disabletime_team1	= CreateConVar("sakp_disabletime_team1",	"-1",	"same as sakp_disabletime, but for team 2 only (overrides sakp_disabletime if not set to -1)", FCVAR_PLUGIN);
	disabletime_team2	= CreateConVar("sakp_disabletime_team2",	"-1",	"same as sakp_disabletime, but for team 2 only (overrides sakp_disabletime if not set to -1)", FCVAR_PLUGIN);
	keypressignoretime	= CreateConVar("sakp_keypressignoretime",	"0.8",	"The amount of time in seconds pressing any keys will not turn off spawn protection", FCVAR_PLUGIN);
	keypressignoretime_team1	= CreateConVar("sakp_keypressignoretime_team1",	"-1",	"same as sakp_keypressignoretime, but for team 1 only (overrides sakp_keypressignoretime if not set to -1)", FCVAR_PLUGIN);
	keypressignoretime_team2	= CreateConVar("sakp_keypressignoretime_team2",	"-1",	"same as sakp_keypressignoretime, but for team 1 only (overrides sakp_keypressignoretime if not set to -1)", FCVAR_PLUGIN);
	maxspawnprotection	= CreateConVar("sakp_maxspawnprotection",	"0",	"max timelimit in seconds the spawnprotection stays, 0 = no limit",	FCVAR_PLUGIN);
	maxspawnprotection_team1 = CreateConVar("sakp_maxspawnprotection_team1",	"-1",	"same as sakp_maxspawnprotection, but for team 1 only (overrides sakp_maxspawnprotection if not set to -1)",	FCVAR_PLUGIN);
	maxspawnprotection_team2 = CreateConVar("sakp_maxspawnprotection_team2",	"-1",	"same as sakp_maxspawnprotection, but for team 2 only (overrides sakp_maxspawnprotection if not set to -1)",	FCVAR_PLUGIN);
	fadescreen			= CreateConVar("sakp_fadescreen",			"1",	"Fade screen to black", FCVAR_PLUGIN);
	hidehud				= CreateConVar("sakp_hidehud"	,			"1",	"Set to 1 to hide the HUD when being protected", FCVAR_PLUGIN);
	player_color_r		= CreateConVar("sakp_player_color_red",		"255",	"amount of red when a player is protected 0-255", FCVAR_PLUGIN);
	player_color_g		= CreateConVar("sakp_player_color_green",	"0",	"amount of green when a player is protected 0-255", FCVAR_PLUGIN);
	player_color_b		= CreateConVar("sakp_player_color_blue",	"0",	"amount of blue when a player is protected 0-255", FCVAR_PLUGIN);
	player_color_a		= CreateConVar("sakp_player_alpha",			"50",	"alpha amount of a protected player 0-255", FCVAR_PLUGIN);

	AutoExecConfig(true);
	File_LoadTranslations("spawnandkillprotection.phrases");

	HookEvent("player_spawn", Event_PlayerSpawn);
	
	// Hooking the existing clients in case of lateload
	for (new client=1; client <= MaxClients; client++) {

		if (!IsClientInGame(client)) {
			continue;
		}

		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	
	new value = GetConVarInt(notify);

	if (value == 1 || value == 4) {
		CreateTestHudSynchronizer();
	}
}

public OnMapStart() 
{	
	CreateTimer(1.0, Timer_CheckWall, INVALID_HANDLE, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnMapEnd()
{
	DisableKillProtectionAll();
}

public OnPluginEnd()
{	
	DisableKillProtectionAll();
}

public OnClientPutInServer(client)
{	
	isKillProtected[client] = false;
	isSpawnKillProtected[client] = false;
	isWallKillProtected[client] = false;
	keyPressOnTime[client] = 0.0;
	timeLookingAtWall[client] = 0;
	lastPlayerHealth[client] = 0;
	activeDisableTimer[client] = INVALID_HANDLE;

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnGameFrame() 
{	
	for (new client=1; client <= MaxClients; client++) {
		
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client)) {
			continue;
		}

		if (isKillProtected[client]) {
			
			if (activeDisableTimer[client] != INVALID_HANDLE) {
				continue;
			}

			new clientButtons = Client_GetButtons(client);
			
			if (!(clientButtons & KILLPROTECTION_DISABLE_BUTTONS)) {
				continue;
			}

			if (GetGameTime() < keyPressOnTime[client]) {
				continue;
			}
			
			if (isSpawnKillProtected[client]) {
				
				if (GetConVarInt(disableonmoveshoot) == 0) {
					continue;
				}
				
				if (GetConVarInt(disableonmoveshoot) == 2 && !(clientButtons & SHOOT_DISABLE_BUTTONS)) {
					continue;
				}
			}

			new Float:disabletime_value = GetDisableTime(client);
			if (disabletime_value > 0.0) {
				activeDisableTimer[client] = CreateTimer(disabletime_value, Timer_DisableSpawnProtection, client, TIMER_FLAG_NO_MAPCHANGE);
			}
			else {
				DisableKillProtection(client);
			}
		}
	}
}



/****************************************************************


		C A L L B A C K   F U N C T I O N S


****************************************************************/

public ConVarChange_Notify(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if (StringToInt(oldValue) == 1) {
		CloseHandle(hudSynchronizer);
		hudSynchronizer = INVALID_HANDLE;
	}
	
	new value = StringToInt(newValue);
	if (value == 1 || value == 4) {
		CreateTestHudSynchronizer();
	}
}

public ConVarChange_Enabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0) {
		DisableKillProtectionAll();
	}
}

public Action:Timer_EnableSpawnProtection(Handle:timer, any:client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
		return Plugin_Stop;
	}
	
	isSpawnKillProtected[client] = true;
	EnableKillProtection(client);
	
	return Plugin_Stop;
}

public Action:Timer_DisableSpawnProtection(Handle:timer, any:client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
		return Plugin_Stop;
	}

	activeDisableTimer[client] = INVALID_HANDLE;
	isSpawnKillProtected[client] = false;
	DisableKillProtection(client);
	
	return Plugin_Stop;
}

public Action:Timer_CheckWall(Handle:timer)
{
	if (!GetConVarBool(enabled) || (GetConVarInt(walltime) == -1)) {
		return Plugin_Continue;
	}
	
	for (new client=1; client<=MaxClients; client++) {
		
		if (!IsClientInGame(client) || IsFakeClient(client)) {
			continue;
		}
		
		if (Client_IsLookingAtWall(client) && !(Client_GetButtons(client) & KILLPROTECTION_DISABLE_BUTTONS)) {
			
			if (!isWallKillProtected[client] && timeLookingAtWall[client] >= GetConVarInt(walltime)) {
				
				if (activeDisableTimer[client] != INVALID_HANDLE) {
					KillTimer(activeDisableTimer[client]);	
					activeDisableTimer[client] = INVALID_HANDLE;
				}
				
				isWallKillProtected[client] = true;
				EnableKillProtection(client);
			}
			
			timeLookingAtWall[client]++;
		}
		else {
			
			timeLookingAtWall[client] = 0;
			
			if (isKillProtected[client] && activeDisableTimer[client] != INVALID_HANDLE) {
				
				if (isWallKillProtected[client]) {
					
					isWallKillProtected[client] = false;
					
					new Float:disabletime_value = GetDisableTime(client);
					if (disabletime_value > 0.0) {
						activeDisableTimer[client] = CreateTimer(disabletime_value, Timer_DisableSpawnProtection, client, TIMER_FLAG_NO_MAPCHANGE);
					}
					else {
						DisableKillProtection(client);
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:broadcast)
{
	if (!GetConVarBool(enabled)) {
		return;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsFakeClient(client)) {
		return;
	}

	isSpawnKillProtected[client] = true;
	CreateTimer(0.1, Timer_EnableSpawnProtection, client, TIMER_FLAG_NO_MAPCHANGE);

	new Float:maxspawnprotection_value = GetMaxSpawnProtectionTime(client);

	if (maxspawnprotection_value > 0.0) {
		CreateTimer(maxspawnprotection_value + 0.1, Timer_DisableSpawnProtection, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:OnTakeDamage(client, &inflictor, &attacker, &Float:damage, &damageType)
{
	if (IsFakeClient(client)) {
		return Plugin_Continue;
	}
	
	if (isKillProtected[client]) {
		
		ProtectedPlayerHurted(client, inflictor, RoundToFloor(damage));
	
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}



/*****************************************************************


		P L U G I N   F U N C T I O N S


*****************************************************************/

Float:GetMaxSpawnProtectionTime(client)
{
	new Float:maxspawnprotection_value = 0.0;

	switch (GetClientTeam(client)) {
		case 2: {
			maxspawnprotection_value = GetConVarFloat(maxspawnprotection_team1);		
		}
		case 3: {
			maxspawnprotection_value = GetConVarFloat(maxspawnprotection_team2);
		}
	}
	
	if (maxspawnprotection_value < 0.0) {
		maxspawnprotection_value = GetConVarFloat(maxspawnprotection);
	}
	
	return maxspawnprotection_value;
}

Float:GetDisableTime(client)
{
	new Float:disabletime_value = 0.0;

	switch (GetClientTeam(client)) {
		case 2: {
			disabletime_value = GetConVarFloat(disabletime_team1);		
		}
		case 3: {
			disabletime_value = GetConVarFloat(disabletime_team2);
		}
	}
	
	if (disabletime_value < 0.0) {
		disabletime_value = GetConVarFloat(disabletime);
	}
	
	return disabletime_value;
}

Float:GetKeyPressIgnoreTime(client)
{
	new Float:keypressignoretime_value = 0.0;

	switch (GetClientTeam(client)) {
		case 2: {
			keypressignoretime_value = GetConVarFloat(keypressignoretime_team1);		
		}
		case 3: {
			keypressignoretime_value = GetConVarFloat(keypressignoretime_team2);
		}
	}
	
	if (keypressignoretime_value < 0.0) {
		keypressignoretime_value = GetConVarFloat(keypressignoretime);
	}
	
	return keypressignoretime_value;
}

public Native_IsClientProtected(Handle:plugin, numParams)
{
	new bool:isClientProtected = GetNativeCell(1);

	return isKillProtected[isClientProtected];
}

CreateTestHudSynchronizer()
{	
	hudSynchronizer = CreateHudSynchronizer();
	
	if (hudSynchronizer == INVALID_HANDLE) {
		PrintToServer("[Spawn & Kill Protection] %t", "server_warning_notify");
		SetConVarInt(notify, 3);
	}
	else {
		SetConVarInt(notify, 1);
	}
}

stock ProtectedPlayerHurted(client, inflictor, damage)
{	
	if (!Client_IsValid(inflictor, false)) {
		return;
	}

	new punishmode_value = GetConVarInt(punishmode);

	if (punishmode_value) {

		switch (punishmode_value) {

			case 2: { // Decrase Health
				Entity_TakeHealth(inflictor, GetConVarInt(takedamage));
			}
			case 3: { // Slay
				ForcePlayerSuicide(inflictor);
			}
			case 4: { // Damage done to enemy
				Entity_TakeHealth(inflictor, damage);
			}
			case 1: { //case 1: Slap
				SlapPlayer(inflictor, GetConVarInt(takedamage));
			}
		}
	}
}

EnableKillProtection(client) {
	
	if (!IsPlayerAlive(client) || IsFakeClient(client)) {
		return;
	}

	isKillProtected[client] =  true;
	keyPressOnTime[client] = GetGameTime() + GetKeyPressIgnoreTime(client);
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, GetConVarInt(player_color_r), GetConVarInt(player_color_g), GetConVarInt(player_color_b), GetConVarInt(player_color_a));

	if (GetConVarBool(hidehud)) {
		Client_SetHideHud(client, HIDEHUD_ALL);
	}

	if (GetConVarBool(noblock)) {
		Entity_SetCollisionGroup(client, COLLISION_GROUP_DEBRIS);
	}
	
	lastPlayerHealth[client] = Entity_GetHealth(client);
	Entity_SetHealth(client, PROTECTED_HEALTH, true);
		
	if (GetConVarBool(fadescreen)) {
		Client_ScreenFade(client, 0, FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE, -1, 0, 0, 0, 240);
	}

	NotifyClientEnableProtection(client);
}

DisableKillProtection(client) {
	
	if (IsFakeClient(client)) {
		return;
	}
	
	if (!isKillProtected[client]) {
		return;
	}

	isKillProtected[client] =  false;
	isSpawnKillProtected[client] = false;
	isWallKillProtected[client] = false;
	timeLookingAtWall[client] = 0;
	keyPressOnTime[client] = 0.0;

	if (IsPlayerAlive(client)) {
		SetEntityRenderColor(client, 255, 255, 255, 255);
		
		if (GetConVarBool(hidehud)) {
			Client_SetHideHud(client, 0);
		}

		if (GetConVarBool(noblock)) {
			Entity_SetCollisionGroup(client, COLLISION_GROUP_PLAYER);
		}

		Entity_SetHealth(client, lastPlayerHealth[client], true);
	}
	
	if (GetConVarBool(fadescreen)) {
		Client_ScreenFade(client, 0, FFADE_IN | FFADE_PURGE, -1, 0, 0, 0, 0);
	}
	
	NotifyClientDisableProtection(client);
}

DisableKillProtectionAll() {

	for (new client=1; client <= MaxClients; client++) {

		if (!IsClientInGame(client) || !IsPlayerAlive(client) || !isKillProtected[client]) {
			continue;
		}

		DisableKillProtection(client);
	}
}

NotifyClientEnableProtection(client) {
	
	new notify_value = GetConVarInt(notify);

	if (!notify_value) {
		return;
	}
	
	if (isSpawnKillProtected[client]) {

		switch (notify_value) {
			
			case 2: {
				PrintCenterText(client, "%t", "Spawnprotection Enabled");
			}
			case 3: {
				PrintToChat(client, "\x04[SAKP] \x01%t", "Spawnprotection Enabled");
			}
			default: { // case 1
				SetHudTextParams(-1.0, -1.0, 99999999.0, 255, 0, 0, 255, 0, 6.0, 0.1, 0.2);
				ShowSyncHudText(client, hudSynchronizer, "%t", "Spawnprotection Enabled");
			}
		}
	}
	else {

		switch (notify_value) {
			
			case 2: {
				PrintCenterText(client, "%t", "Killprotection Enabled");
			}
			case 3: {
				PrintToChat(client, "\x04[SAKP] \x01%t", "Killprotection Enabled");
			}
			default: { // case 1
				SetHudTextParams(-1.0, -1.0, 99999999.0, 255, 0, 0, 255, 0, 6.0, 0.1, 0.2);
				ShowSyncHudText(client, hudSynchronizer, "%t", "Killprotection Enabled");
			}
		}
	}

}

NotifyClientDisableProtection(client) {
	
	new notify_value = GetConVarInt(notify);
	
	if (isSpawnKillProtected[client]) {
		
		switch (notify_value) {
			
			case 2: {
				PrintCenterText(client, "%t", "Spawnprotection Disabled");
			}
			case 3: {
				PrintToChat(client, "\x04[SAKP] \x01%t", "Spawnprotection Disabled");
			}
		}
	}
	else {
		
		switch (notify_value) {
			
			case 2: {
				PrintCenterText(client, "%t", "Killprotection Disabled");
			}
			case 3: {
				PrintToChat(client, "\x04[SAKP] \x01%t", "Killprotection Disabled");
			}
		}
	}
	
	if(hudSynchronizer != INVALID_HANDLE) {
		ClearSyncHud(client, hudSynchronizer);
	}
}
