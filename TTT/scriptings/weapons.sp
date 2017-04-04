#pragma newdecls required

#include <sdktools>

Handle g_hDataBase
Handle g_hKv;
Handle g_hSpawnTimer;
bool g_bKvCached;
int g_iWeaponCount = -1;
int g_iLastType;
char g_szMap[256];
char FilePath[128];
char g_szLastWeapon[32];


public Plugin myinfo = 
{
	name		= "[CG] TTT - Map Weapons",
	author		= "Kyle",
	description = "map weapon 4 ttt",
	version		= "3.0",
	url			= "http://steamcommunity.com/id/_xQy_/"
}

public void OnPluginStart()
{
	BuildPath(Path_SM, FilePath, 256, "configs/weapons.txt");
	
	RegAdminCmd("sm_pw", Command_WeaponMenu, ADMFLAG_CUSTOM3);
	RegAdminCmd("sm_nw", Command_FastMenu, ADMFLAG_CUSTOM3);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

	char fmt[256];
	g_hDataBase = SQL_Connect("weapons", false, fmt, 256);
	if(g_hDataBase != INVALID_HANDLE)
	{
		Format(fmt, 256, "CREATE TABLE IF NOT EXISTS `ttt_weapon` (					\
							`Id` int(11) NOT NULL AUTO_INCREMENT,					\
							`map` varchar(128) DEFAULT NULL,						\
							`weapon` varchar(32) DEFAULT NULL,						\
							`location` varchar(128) DEFAULT NULL,					\
							PRIMARY KEY (`Id`)										\
							) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;");
							
		SQL_FastQuery(g_hDataBase, fmt);
	}
	else 
		SetFailState("[Weapons] Unable to connect to the database (%s)", fmt);
}

public void OnMapStart()
{
	g_bKvCached = false;
	g_iWeaponCount = -1;
	GetCurrentMap(g_szMap, 256);
	
	QueryDataFromDatabase();
}

public void OnMapEnd()
{
	if(g_hKv != INVALID_HANDLE)
	{
		CloseHandle(g_hKv);
		g_hKv = INVALID_HANDLE;
	}
}

public void QueryDataFromDatabase()
{
	if(g_hDataBase == INVALID_HANDLE)
		return;

	g_hKv = CreateKeyValues("weapon", "", "");
	KeyValuesToFile(g_hKv, FilePath);

	char m_sQuery[255];
	Format(m_sQuery, 255, "SELECT weapon,location FROM `ttt_weapon` WHERE `map` = '%s'", g_szMap);
	SQL_TQuery(g_hDataBase, SQLCallback_FetchKv, m_sQuery);
}

public void SQLCallback_FetchKv(Handle owner, Handle hndl, const char[] error, any unused)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Error happened: %s", error);
		return;
	}
	
	if(SQL_GetRowCount(hndl))
	{
		g_iWeaponCount = 0;
		char sCount[4], sWeapon[32], sLocation[256];
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sWeapon, 32);
			SQL_FetchString(hndl, 1, sLocation, 256); 
			IntToString(g_iWeaponCount++, sCount, 16);		

			if(KvJumpToKey(g_hKv, sCount, true))
			{
				KvSetString(g_hKv, "weapon", sWeapon);
				KvSetString(g_hKv, "location", sLocation);
				KvRewind(g_hKv);
			}
			
			if(g_iWeaponCount > 200)
				break;
		}
		g_bKvCached = true;
		KeyValuesToFile(g_hKv, FilePath);
	}
	else
	{
		KeyValuesToFile(g_hKv, FilePath);
		//CloseHandle(g_hKv);
	}
}

public void SQLCallback_UpdateWeapon(Handle owner, Handle hndl, const char[] error, int client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Error happened: %s", error);
		PrintToChat(client, "[\x0CCG\x01]  sync failed");
		return;
	}
	
	PrintToChat(client, "[\x0CCG\x01]  synced!");
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bKvCached) 
	{
		KvRewind(g_hKv);
		KvGotoFirstSubKey(g_hKv);
		g_hSpawnTimer = CreateTimer(0.0, Timer_SpawnWeapon);
	}
}

public Action Timer_SpawnWeapon(Handle timer, any unused)
{
	char buffer[256], weaponname[256];
	float spawnposition[3]
	int spawnnum = 10;
	while(spawnnum--)
	{
		KvGetSectionName(g_hKv, buffer, 256);
		KvGetVector(g_hKv, "location", spawnposition);
		KvGetString(g_hKv, "weapon", weaponname, 256, "NULL");
		
		if(!StrEqual(weaponname, "NULL", false))
		{
			int entity = CreateEntityByName(weaponname);
			if(entity != -1)
			{
				if(strncmp(weaponname, "light", 5, false) == 0)
				{
					DispatchKeyValue(entity, "_light", "255 255 255");
					DispatchKeyValue(entity, "brightness", "3");
					DispatchKeyValue(entity, "spotlight_radius", "1000");
					DispatchKeyValue(entity, "pitch", "-90");
					DispatchKeyValue(entity, "distance", "300");
					AcceptEntityInput(entity, "TurnOn");
				}
				
				TeleportEntity(entity, spawnposition, NULL_VECTOR, NULL_VECTOR);
				DispatchSpawn(entity);
				SetEntData(entity, GetEntSendPropOffs(entity, "movetype"), 0, 1, true);
			}
		}
		
		if(!KvGotoNextKey(g_hKv))
		{
			KillTimer(g_hSpawnTimer);
			g_hSpawnTimer = INVALID_HANDLE;
			KvRewind(g_hKv);
			return Plugin_Continue;
		}
	}
	if(KvGotoNextKey(g_hKv))
	{
		g_hSpawnTimer = CreateTimer(0.1, Timer_SpawnWeapon)
	}
	else
	{
		KillTimer(g_hSpawnTimer);
		g_hSpawnTimer = INVALID_HANDLE;
		KvRewind(g_hKv);
	}

	return Plugin_Continue;
}


public Action Command_WeaponMenu(int client, int args)
{
	Handle menu = CreateMenu(WeaponMenuHandler);
	SetMenuTitle(menu, "[CSGOGAMERS.COM]  Weapons Menu");
	
	AddMenuItem(menu, "pistol", "Pistol");
	AddMenuItem(menu, "smg", "SMG");
	AddMenuItem(menu, "shotgun", "Heavy");
	AddMenuItem(menu, "rifle", "Rifle");
	AddMenuItem(menu, "item", "Item");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 8);
}

public Action Command_FastMenu(int client, int args)
{
	float cleyepos[3], cleyeangle[3], resultposition[3], normalvector[3];
		
	GetClientEyePosition(client, cleyepos); 
	GetClientEyeAngles(client, cleyeangle);
		
	Handle traceresulthandle = TR_TraceRayFilterEx(cleyepos, cleyeangle, MASK_SOLID, RayType_Infinite, tracerayfilternoplayer, client);
	
	if(TR_DidHit(traceresulthandle) == true)
	{
		TR_GetEndPosition(resultposition, traceresulthandle);
		TR_GetPlaneNormal(traceresulthandle, normalvector);
			
		NormalizeVector(normalvector, normalvector);
		ScaleVector(normalvector, 5.0);
		AddVectors(resultposition, normalvector, resultposition);

		char m_sNumBuffer[32];
		Format(m_sNumBuffer, 256, "%i", ++g_iWeaponCount);
		KvJumpToKey(g_hKv, m_sNumBuffer, true);
			
		KvSetVector(g_hKv, "location", resultposition);
		KvSetString(g_hKv, "weapon", g_szLastWeapon);	
		KvRewind(g_hKv);
			
		int entity = CreateEntityByName(g_szLastWeapon);
		if(StrContains(g_szLastWeapon, "light", false) == 0)
		{
			DispatchKeyValue(entity, "_light", "255 255 255");
			DispatchKeyValue(entity, "brightness", "3");
			DispatchKeyValue(entity, "spotlight_radius", "1000");
			DispatchKeyValue(entity, "pitch", "-90");
			DispatchKeyValue(entity, "distance", "300");
		}
			
		DispatchSpawn(entity);
			
		if(StrContains(g_szLastWeapon, "light", false) == 0)
			AcceptEntityInput(entity, "TurnOn");
			
		TeleportEntity(entity, resultposition, NULL_VECTOR, NULL_VECTOR);
			
		PrintToChatAll("[\x0CCG\x01]  \x08Admin Spawn weapon at [\x04%s\x01]", g_szLastWeapon);

		UpdateWeaponToDataBase(g_szLastWeapon, resultposition, client);
	}
}

public int WeaponMenuHandler(Handle menu, MenuAction action, int client, int itemNum)
{
	if(action == MenuAction_Select) 
	{
		char info[32];
		GetMenuItem(menu, itemNum, info, 32);
		
		if(StrEqual(info, "pistol", false))
			ShowPistolMenu(client);
		else if(StrEqual(info, "smg", false))
			ShowSMGMenu(client);
		else if(StrEqual(info, "shotgun", false))
			ShowShotgunMenu(client);
		else if(StrEqual(info, "rifle", false))
			ShowRifleMenu(client);
		else if(StrEqual(info, "item", false))
			ShowItemMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

void ShowPistolMenu(int client)
{
	Handle menu = CreateMenu(SelectMenuHandler);
	SetMenuTitle(menu, "[CSGOGAMERS.COM]  Pistols"); 
  
	AddMenuItem(menu, "weapon_hkp2000", "P2000");
	AddMenuItem(menu, "weapon_glock", "Glock");
	AddMenuItem(menu, "weapon_usp_silencer", "USP");
	AddMenuItem(menu, "weapon_p250", "P250");
	AddMenuItem(menu, "weapon_fiveseven", "FiveSeven");
	AddMenuItem(menu, "weapon_deagle", "Deagle");
	AddMenuItem(menu, "weapon_tec9", "Tec9");
	AddMenuItem(menu, "weapon_elite", "Elite");
	AddMenuItem(menu, "weapon_cz75a", "CZ75");
	AddMenuItem(menu, "weapon_revolver", "R8");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);
	
	g_iLastType = 1;
}

void ShowSMGMenu(int client)
{
	Handle menu = CreateMenu(SelectMenuHandler);
	SetMenuTitle(menu, "[CSGOGAMERS.COM]  SMGs"); 
  
	AddMenuItem(menu, "weapon_mac10", "MAC10");
	AddMenuItem(menu, "weapon_mp9", "MP9");
	AddMenuItem(menu, "weapon_mp7", "MP7");
	AddMenuItem(menu, "weapon_ump45", "UMP45");
	AddMenuItem(menu, "weapon_bizon", "PPBIZON");
	AddMenuItem(menu, "weapon_p90", "P90");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);
	
	g_iLastType = 2;
}

void ShowShotgunMenu(int client)
{
	Handle menu = CreateMenu(SelectMenuHandler);
	SetMenuTitle(menu, "[CSGOGAMERS.COM]  Heavy"); 
  
	AddMenuItem(menu, "weapon_nova", "NOVA");
	AddMenuItem(menu, "weapon_xm1014", "XM1014");
	AddMenuItem(menu, "weapon_sawedoff", "SwadeOff");
	AddMenuItem(menu, "weapon_mag7", "MAG-7");
	AddMenuItem(menu, "weapon_m249", "M249");
	AddMenuItem(menu, "weapon_negev", "Negev");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);
	
	g_iLastType = 3;
}
 
void ShowRifleMenu(int client)
{
	Handle menu = CreateMenu(SelectMenuHandler);
	SetMenuTitle(menu, "[CSGOGAMERS.COM]  Rifle"); 
  
	AddMenuItem(menu, "weapon_famas", "Famas");
	AddMenuItem(menu, "weapon_galilar", "Galilar");
	AddMenuItem(menu, "weapon_m4a1", "M4A4");
	AddMenuItem(menu, "weapon_ak47", "AK47");
	AddMenuItem(menu, "weapon_m4a1_silencer", "M4A1");
	AddMenuItem(menu, "weapon_sg556", "SG556");
	AddMenuItem(menu, "weapon_aug", "AUG");
	AddMenuItem(menu, "weapon_ssg08", "SSG08");
	AddMenuItem(menu, "weapon_awp", "AWP");
	AddMenuItem(menu, "weapon_g3sg1", "G3SG1");
	AddMenuItem(menu, "weapon_scar20", "SCAR20");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);
	
	g_iLastType = 4;
}

void ShowItemMenu(int client)
{
	Handle menu = CreateMenu(SelectMenuHandler);
	SetMenuTitle(menu, "[CSGOGAMERS.COM]  Items"); 
  
	AddMenuItem(menu, "weapon_hegrenade", "HE");
	AddMenuItem(menu, "weapon_flashbang", "flashbang");
	AddMenuItem(menu, "weapon_smokegrenade", "Smokegrenade");
	AddMenuItem(menu, "weapon_decoy", "decoy");
	AddMenuItem(menu, "weapon_incgrenade", "incgrenade");
	AddMenuItem(menu, "weapon_molotov", "molotov");
	AddMenuItem(menu, "weapon_knife", "knife");
	AddMenuItem(menu, "weapon_taser", "taser");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);
	
	g_iLastType = 5;
}

public int SelectMenuHandler(Handle menu, MenuAction action, int client, int itemNum)
{
	if(action == MenuAction_Select) 
	{
		char info[32];
		GetMenuItem(menu, itemNum, info, 32);
		
		float cleyepos[3], cleyeangle[3], resultposition[3], normalvector[3];
		
		GetClientEyePosition(client, cleyepos); 
		GetClientEyeAngles(client, cleyeangle);
		
		Handle traceresulthandle = TR_TraceRayFilterEx(cleyepos, cleyeangle, MASK_SOLID, RayType_Infinite, tracerayfilternoplayer, client);
	
		if(TR_DidHit(traceresulthandle) == true)
		{
			TR_GetEndPosition(resultposition, traceresulthandle);
			TR_GetPlaneNormal(traceresulthandle, normalvector);
			
			NormalizeVector(normalvector, normalvector);
			ScaleVector(normalvector, 5.0);
			AddVectors(resultposition, normalvector, resultposition);

			char m_sNumBuffer[32];
			Format(m_sNumBuffer, 256, "%i", ++g_iWeaponCount);
			KvJumpToKey(g_hKv, m_sNumBuffer, true);
			
			KvSetVector(g_hKv, "location", resultposition);
			KvSetString(g_hKv, "weapon", info);	
			KvRewind(g_hKv);
			
			int entity = CreateEntityByName(info);
			if(StrContains(info, "light", false) == 0)
			{
				DispatchKeyValue(entity, "_light", "255 255 255");
				DispatchKeyValue(entity, "brightness", "3");
				DispatchKeyValue(entity, "spotlight_radius", "1000");
				DispatchKeyValue(entity, "pitch", "-90");
				DispatchKeyValue(entity, "distance", "300");
			}
			
			DispatchSpawn(entity);
			
			if(StrContains(info, "light", false) == 0)
				AcceptEntityInput(entity, "TurnOn");
			
			TeleportEntity(entity, resultposition, NULL_VECTOR, NULL_VECTOR);
			
			PrintToChatAll("[\x0CCG\x01]  \x08Admin Spawn weapon at [\x04%s\x01]", info);
			
			g_szLastWeapon = info;
			
			if(g_iLastType == 1)
				ShowPistolMenu(client);
			else if(g_iLastType == 2)
				ShowSMGMenu(client);
			else if(g_iLastType == 3)
				ShowShotgunMenu(client);
			else if(g_iLastType == 4)
				ShowRifleMenu(client);
			else if(g_iLastType == 5)
				ShowItemMenu(client);
			
			UpdateWeaponToDataBase(info, resultposition, client);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

void UpdateWeaponToDataBase(char[] weapon, float loc[3], int client)
{
	char m_sQuery[256];
	Format(m_sQuery, 256, "INSERT INTO `ttt_weapon` (map, weapon, location) VALUES ('%s', '%s', '%f %f %f')", g_szMap, weapon, loc[0], loc[1], loc[2]);
	SQL_TQuery(g_hDataBase, SQLCallback_UpdateWeapon, m_sQuery, client);
}

public bool tracerayfilternoplayer(int entity, int mask, any data)
{	
	return !IsValidClient(entity);
}

bool IsValidClient(int client)
{
	if(!(1 <= client <= MaxClients))
		return false;
	
	return IsClientInGame(client);
}