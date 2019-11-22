// This file is part of OpenCollar.
// Copyright (c) 2018 - 2019 Tashia Redrose, Silkie Sabra, lillith xue                            
// Licensed under the GPLv2.  See LICENSE for full details. 


string g_sParentMenu = "Apps";
string g_sSubMenu = "Attachments";


//MESSAGE MAP
//integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_RLV_RELAY = 507;
integer CMD_SAFEWORD = 510;
integer CMD_RELAY_SAFEWORD = 511;

integer NOTIFY = 1002;

integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LINK_AUTH = -15;
integer REBOOT = -1000;

integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved
//str must be in form of "token=value"
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the settings script sends responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from settings
integer LM_SETTING_EMPTY = 2004;//sent when a token has no value

integer AUTH_REQUEST = 600;
integer AUTH_REPLY = 601;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
string UPMENU = "BACK";
string ALL = "ALL";
string g_sChecked = "☑";
string g_sUnChecked = "☐";

integer g_iNCLine;
key g_kNCQuery;
string g_sNCName = "Collar Pose";

string g_sLockSound="dec9fb53-0fef-29ae-a21d-b3047525d312";
string g_sUnlockSound="82fa6d06-b494-f97c-2908-84009380c8d1";

key g_kChainTexture = "4cde01ac-4279-2742-71e1-47ff81cc3529";
key g_kRopeTexture = "9a342cda-d62a-ae1f-fc32-a77a24a85d73";

// Chain Style
key g_kTexture = "4cde01ac-4279-2742-71e1-47ff81cc3529";
float g_fSize = 0.04;
float g_fGravity = 0.01;
float g_fRed = 1;
float g_fGreen = 1;
float g_fBlue = 1;
integer g_bRibbon = TRUE;

integer g_bMoveLock = FALSE;

integer g_iChan_ocCmd = -1;
list g_lCollarPoses = [];
list g_lPoses = [];
list g_lActivePoses = [];
list g_lSelectedPose = [];
integer g_bRLV = FALSE;
string g_sCurrentCollarPose = "";

integer g_bLocked = FALSE;
integer g_bSyncLock = TRUE;
integer g_bHidden = FALSE;
key g_kWearer;
list g_lMenuIDs;
integer g_iMenuStride;

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

Menu(key kID, integer iAuth) {
    string sPrompt = "\n[Cuff Menu]";
    
    list lButtons = ["Poses"];
    
    if (g_bLocked) lButtons += [g_sChecked+"Locked"];
    else lButtons += [g_sUnChecked+"Locked"];
    if (iAuth == CMD_OWNER || iAuth == CMD_WEARER) lButtons += ["Settings"];
    if (iAuth != CMD_WEARER) lButtons += ["Clear All"];
    
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~Cuffs");
}

PosesMenu(key kID, integer iAuth){
    string sPrompt = "\n[Cuff Poses]";
    list lButtons = [];
    integer i;
    for (i=0; i<llGetListLength(g_lPoses);++i) {
        list lPose = llParseString2List(llList2String(g_lPoses,i),["|"],[]);
        if (llListFindList(lButtons,[llList2String(lPose,0)]) == -1) lButtons+=[llList2String(lPose,0)];
    }
    
    if (iAuth == CMD_WEARER) sPrompt += "\n \n!! WARNING !! \n \n You will not be able to stop Poses by yourself!";
    
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~CuffPoses");
}

SettingsMenu(key kID, integer iAuth, string sTarget)
{
    string sPrompt = "[Cuff-Settings]";
    list lButtons =  [];
    if (sTarget == "Settings") {
        lButtons = ["Chains","Sync"];
        if (g_bHidden) lButtons += [g_sChecked+"Hide"];
        else lButtons += [g_sUnChecked+"Hide"];
    } else if (sTarget == "Chains") {
        if (g_kTexture == g_kChainTexture) lButtons = [g_sChecked+"Chain",g_sUnChecked+"Rope"];
        else lButtons = [g_sUnChecked+"Chain",g_sChecked+"Rope"];
        
    } else if (sTarget == "Sync") {
        if (g_bSyncLock) lButtons = [g_sChecked+"Sync Lock"];
        else lButtons = [g_sUnChecked+"Sync Lock"];
        lButtons += "ReSync Now";
    }
    
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~CuffSettings");
}


AnimMenu(key kID, integer iAuth, string sTarget){
    string sPrompt = "/n ["+sTarget+" Poses]";
    list lButtons = [];
    list lUtility = [UPMENU];
    integer i;
    for (i=0;i<llGetListLength(g_lPoses);++i) {
        list lPose = llParseString2List(llList2String(g_lPoses,i),["|"],[]);
        if (llList2String(lPose,0) == sTarget) {
            if (llListFindList(g_lActivePoses,[llList2String(g_lPoses,i)]) > -1) lButtons += [g_sChecked+llList2String(lPose,1)];
            else lButtons += [g_sUnChecked+llList2String(lPose,1)];
        }
    }
    
    Dialog(kID, sPrompt, lButtons, lUtility, 0, iAuth, "Menu~"+sTarget);
}

UserCommand(integer iNum, string sStr, key kID) {
    if (iNum<CMD_OWNER || iNum>CMD_EVERYONE) return;
    if (llSubStringIndex(sStr,"amenu") && sStr != "menu "+g_sSubMenu) return;

    if (sStr=="cuff" || sStr == "menu "+g_sSubMenu) Menu(kID, iNum);
    //else if (iNum!=CMD_OWNER && iNum!=CMD_TRUSTED && kID!=g_kWearer) RelayNotify(kID,"Access denied!",0);
    else {
        integer iWSuccess = 0; 
        string sChangetype = llList2String(llParseString2List(sStr, [" "], []),0);
        string sChangevalue = llList2String(llParseString2List(sStr, [" "], []),1);
        string sText;
        
    }
}

lock(integer bEnable, integer bSave)
{
    if (bEnable) {
        llRegionSayTo(g_kWearer,g_iChan_ocCmd,(string)g_kWearer + ":lock"); //Lock our attachments**
        if (g_bLocked !=bEnable) llPlaySound(g_sLockSound, 1.0);
    } else {
        llRegionSayTo(g_kWearer,g_iChan_ocCmd,(string)g_kWearer + ":unlock"); //Unlock our attachments**
        if (g_bLocked !=bEnable) llPlaySound(g_sUnlockSound, 1.0);
    }
    g_bLocked = bEnable;
    
    if (bSave) llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "Cuffs_lock="+(string)bEnable, NULL_KEY);
}

string getCategoryPose(string sCategory)
{
    integer i;
    for (i=0;i<llGetListLength(g_lActivePoses);++i){
        list lPose = llParseString2List(llList2String(g_lActivePoses,i),["|"],[]);
        if (llList2String(lPose,0) == sCategory){
            return llList2String(g_lActivePoses,i);
        }
    }
    return "";
}

doClearAllPoses() {
    integer i;
    list lAPoses = g_lActivePoses;
    for (i=0;i<llGetListLength(lAPoses);++i){
        llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":clearpose:"+llList2String(lAPoses,i));
    }
    g_lActivePoses = [];
    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "Cuffs_Poses="+llDumpList2String(g_lActivePoses,","), NULL_KEY);
}


applyRLV(string sNewPose){
    integer iIndex = llListFindList(g_lCollarPoses,[g_sCurrentCollarPose]); // Remove old Restrictions
    if (iIndex > -1) {
            if (llList2String(g_lCollarPoses,iIndex+2) != ""){
            list lRestList = llParseString2List(llList2String(g_lCollarPoses,iIndex+2),[","],[]);
            list lRestrctions = [];
            integer i;
            for (i=0; i<llGetListLength(lRestList);++i){
                if (llList2String(lRestList,i) == "move"){
                    g_bMoveLock = FALSE;
                } else lRestrctions += [llList2String(lRestList,i)+"=y"];
            }
            llMessageLinked(LINK_SET,RLV_CMD,llDumpList2String(lRestrctions,","),"Collar Pose");
            llRequestPermissions(g_kWearer,PERMISSION_TAKE_CONTROLS);
        }
    }
    
    iIndex = llListFindList(g_lCollarPoses,[sNewPose]); // Add new restrictions
    if (iIndex > -1) {
        if (llList2String(g_lCollarPoses,iIndex+2) != ""){
            list lRestList = llParseString2List(llList2String(g_lCollarPoses,iIndex+2),[","],[]);
            list lRestrctions = [];
            integer i;
            for (i=0; i<llGetListLength(lRestList);++i){
                if (llList2String(lRestList,i) == "move"){
                    g_bMoveLock = TRUE;
                } else lRestrctions += [llList2String(lRestList,i)+"=n"];
            }
            llMessageLinked(LINK_SET,RLV_CMD,llDumpList2String(lRestrctions,","),"Collar Pose");
            llRequestPermissions(g_kWearer,PERMISSION_TAKE_CONTROLS);
        }
    }
}

default
{
    on_rez(integer t){
        llRegionSayTo(g_kWearer,g_iChan_ocCmd,(string)g_kWearer+":collarping");
        if(llGetOwner()!=g_kWearer) llResetScript();
    }
    state_entry()
    {
        integer iPrimNum = llGetNumberOfPrims();
        integer i;
        for (i=1; i<iPrimNum;++i)
        {
            llLinkParticleSystem(i,[]);
        }
    
        g_kWearer = llGetOwner();
        g_iChan_ocCmd = (integer)("0x"+llGetSubString((string)g_kWearer,3,8)) + 0xCC0CC;
        if (g_iChan_ocCmd>0) g_iChan_ocCmd=g_iChan_ocCmd*(-1);
        if (g_iChan_ocCmd > -10000) g_iChan_ocCmd -= 30000;
        llListen(g_iChan_ocCmd,"",NULL_KEY,"");
        llRegionSayTo(g_kWearer,g_iChan_ocCmd,(string)g_kWearer+":collarping");
        g_lCollarPoses = [];
        
        llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "Cuffs_chaintex",g_kWearer);
        llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "global_locked",g_kWearer);
        llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "Cuffs_Poses",g_kWearer);
        llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "Cuffs_lock",g_kWearer);
        
        if (llGetInventoryType(g_sNCName) == INVENTORY_NOTECARD)
        {
            g_iNCLine = 0;
            g_kNCQuery = llGetNotecardLine(g_sNCName,g_iNCLine);
        } else llOwnerSay("ERROR: Notecard '"+g_sNCName+"' not found!");
    }
    
    run_time_permissions(integer iPerm){
        if (iPerm & PERMISSION_TAKE_CONTROLS){
            if (g_bMoveLock)llTakeControls(CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_UP|CONTROL_DOWN,TRUE,FALSE);
            else llReleaseControls();
        }
    }
    
    dataserver(key kQuery, string sData){
        if (kQuery == g_kNCQuery) {
            if (sData != EOF) {
                if (llGetSubString(sData,0,0) != "#" && sData != "") {
                    list lAnim = llParseString2List(sData,[":"],[]);
                    string sCMD = llList2String(lAnim,0);
                    if (llToLower(sCMD) == "anim"){
                        if (llGetListLength(g_lSelectedPose) == 3) {
                            g_lCollarPoses += g_lSelectedPose;
                        }else if (llGetListLength(g_lSelectedPose) > 0) llOwnerSay("Error: pose '"+llList2String(lAnim,2)+"' is missing some parameters! Ignoring...");
                        g_lSelectedPose =[llList2String(lAnim,1)];
                    } else if (llToLower(sCMD) == "chains"){
                        g_lSelectedPose +=[llList2String(lAnim,1)];
                    } else if (llToLower(sCMD) == "restrictions"){
                        g_lSelectedPose +=[llList2String(lAnim,1)];
                    } else llOwnerSay("Syntax error: Unknown command '"+sCMD+"' at line "+(string)g_iNCLine);
                    
                }
                g_kNCQuery = llGetNotecardLine("Collar Pose",++g_iNCLine);
            } else {
            llOwnerSay("Finished Reading Notecard. "+(string)llGetFreeMemory()+"kb free.");
            }
        }
    }
    
    link_message(integer iSender,integer iNum,string sStr,key kID){
        if(iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sStr, kID);
        else if(iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu+"|"+ g_sSubMenu,"");
        else if(iNum == DIALOG_RESPONSE){
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if(iMenuIndex!=-1){
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"],[]);
                key kAv = llList2Key(lMenuParams,0);
                string sMsg = llList2String(lMenuParams,1);
                integer iAuth = llList2Integer(lMenuParams,3);
                
                if(sMenu == "Menu~Cuffs"){
                    if(sMsg == UPMENU) llMessageLinked(LINK_SET, iAuth, "menu "+g_sParentMenu, kAv);
                    else if (sMsg == "Settings") SettingsMenu(kAv,iAuth,sMsg);
                    else if (sMsg == g_sChecked+"Locked") { 
                        if (iAuth != CMD_WEARER) {
                            lock(FALSE, TRUE);
                            llMessageLinked(LINK_ALL_OTHERS, NOTIFY, "0"+"Attachments are now Unlocked", kAv);
                            llMessageLinked(LINK_ALL_OTHERS, NOTIFY, "0"+"Your Attachments are now Unlocked", g_kWearer);
                        } else llMessageLinked(LINK_ALL_OTHERS, NOTIFY, "0"+"%NOACCESS%", kAv);
                        Menu(kAv, iAuth);
                    } else if (sMsg == g_sUnChecked+"Locked") {
                        lock(TRUE, TRUE);
                        llMessageLinked(LINK_ALL_OTHERS, NOTIFY, "0"+"Attachments are now Locked", kAv);
                        llMessageLinked(LINK_ALL_OTHERS, NOTIFY, "0"+"Your Attachments are now Locked", g_kWearer);
                        Menu(kAv, iAuth);
                    } else if (sMsg == "Poses") PosesMenu(kAv,iAuth);
                    else if (sMsg == "Clear All") {
                        doClearAllPoses();
                        Menu(kAv, iAuth);
                    }
                } else if (sMenu == "Menu~CuffPoses") {
                    if (sMsg == UPMENU) Menu(kAv,iAuth);
                    else  AnimMenu(kAv,iAuth,sMsg);
                } else if (sMenu == "Menu~CuffSettings") {
                    if (sMsg == UPMENU) Menu(kAv,iAuth);
                    else if (sMsg == g_sChecked+"Hide") {
                        g_bHidden = FALSE;
                        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "Cuffs_hide="+(string)g_bHidden, NULL_KEY);
                        SettingsMenu(kAv,iAuth,"Settings");
                    } else if (sMsg == g_sUnChecked+"Hide") {
                        g_bHidden = TRUE;
                        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "Cuffs_hide="+(string)g_bHidden, NULL_KEY);
                        SettingsMenu(kAv,iAuth,"Settings");
                    } else if (sMsg == "Chains") SettingsMenu(kAv,iAuth,sMsg);
                    else if (sMsg == "Sync") SettingsMenu(kAv,iAuth,sMsg);
                    else if (sMsg == g_sChecked+"Sync Lock") {
                        g_bSyncLock = FALSE;
                        SettingsMenu(kAv,iAuth,"Sync");
                    } else if (sMsg == g_sUnChecked+"Sync Lock") {
                        g_bSyncLock = TRUE;
                        SettingsMenu(kAv,iAuth,"Sync");
                    } else if (sMsg == "ReSync Now"){
                        llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "Cuffs_chaintex",g_kWearer);
                        llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "global_locked",g_kWearer);
                        llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "Cuffs_Poses",g_kWearer);
                        llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "Cuffs_lock",g_kWearer);
                        if (g_bRLV) llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":RLV:1");
                        else llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":RLV:0");
                         SettingsMenu(kAv,iAuth,"Sync");
                    } else if (sMsg == g_sUnChecked+"Chain") {
                        g_kTexture = g_kChainTexture;
                        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "Cuffs_chaintex="+(string)g_kTexture, NULL_KEY);
                        SettingsMenu(kAv,iAuth,"Chains");
                    } else if (sMsg == g_sUnChecked+"Rope") {
                        g_kTexture = g_kRopeTexture;
                        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "Cuffs_chaintex="+(string)g_kTexture, NULL_KEY);
                        SettingsMenu(kAv,iAuth,"Chains");
                    } else if (sMsg == g_sChecked+"Chain" || sMsg == g_sChecked+"Rope") SettingsMenu(kAv,iAuth,"Chains");
                } else {
                    if (sMsg == UPMENU) PosesMenu(kAv,iAuth);
                    else {
                        sMsg = llGetSubString(sMsg,1,-1);
                        list lMenuSplit = llParseString2List(sMenu,["~"],[]);
                        string sCategory = llList2String(lMenuSplit,1);
                        string sAnimation = sMsg;
                        string sStopPose = getCategoryPose(sCategory);
                    if (llGetListLength(g_lActivePoses) > 0 && iAuth == CMD_WEARER && sStopPose != "") llMessageLinked(LINK_ALL_OTHERS, NOTIFY, "0"+"%NOACCESS%", kAv);
                        else {
                            integer iActiveIndex = llListFindList(g_lActivePoses,[sCategory+"|"+sAnimation]);
                            if (iActiveIndex > -1) {
                                llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":clearpose:"+sCategory+"|"+sAnimation);
                                g_lActivePoses = llDeleteSubList(g_lActivePoses,iActiveIndex,iActiveIndex);
                                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "Cuffs_Poses="+llDumpList2String(g_lActivePoses,","), NULL_KEY);
                            } else {
                                if (sStopPose != "") {
                                    llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":clearpose:"+sStopPose);
                                    integer iStopPoseIndex = llListFindList(g_lActivePoses,[sStopPose]);
                                    if (iStopPoseIndex > -1) g_lActivePoses = llDeleteSubList(g_lActivePoses,iStopPoseIndex,iStopPoseIndex);
                                }
                                g_lActivePoses += [sCategory+"|"+sAnimation];
                                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "Cuffs_Poses="+llDumpList2String(g_lActivePoses,","), NULL_KEY);
                            }
                            if (g_sCurrentCollarPose != "") { // Reapply curren Collar pose Chains
                                integer iIndex = llListFindList(g_lCollarPoses,[g_sCurrentCollarPose]);
                                llRegionSayTo(g_kWearer,g_iChan_ocCmd,(string)g_kWearer+":occhains:"+llList2String(g_lCollarPoses,iIndex+1));
                                llMessageLinked(LINK_THIS,g_iChan_ocCmd,(string)g_kWearer+":occhains:"+llList2String(g_lCollarPoses,iIndex+1),"");
                            }
                        }
                        AnimMenu(kAv,iAuth,sCategory);
                    }
                }
            }
        } else if(iNum == LINK_UPDATE){
            if(sStr == "LINK_DIALOG") LINK_DIALOG=iSender;
            if(sStr == "LINK_RLV") LINK_RLV=iSender;
            if(sStr == "LINK_SAVE") LINK_SAVE = iSender;
            if(sStr == "LINK_AUTH") LINK_AUTH = iSender;
        } else if(iNum == LM_SETTING_RESPONSE){
            // Detect here the Settings
            list lSettings = llParseString2List(sStr, ["_","="],[]);
            if(llList2String(lSettings,0)=="global"){
                if(llList2String(lSettings,1)=="locked") if (g_bSyncLock) lock(TRUE,TRUE);
            }else if (llList2String(lSettings,0)=="Cuffs") {
                if(llList2String(lSettings,1)=="lock") lock(llList2Integer(lSettings,2),FALSE);
                else if (llList2String(lSettings,1)=="Poses") {
                    llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":activeposes:"+llList2String(lSettings,2));
                    g_lActivePoses = llParseString2List(llList2String(lSettings,2),[","],[]);
                } else if (llList2String(lSettings,1) == "chaintex") {
                    g_kTexture = llList2Key(lSettings,2);
                    llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":chaintex:"+(string)g_kTexture);
                } else if (llList2String(lSettings,1) == "hide") {
                    g_bHidden = llList2Integer(lSettings,2);
                    llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":hide:"+(string)g_bHidden);
                }
            }else {
                list lParam = llParseString2List(sStr, ["="], []);
                integer h = llGetListLength(lParam);
                string sMsg1a= llList2String(lParam, 0);
                if (sMsg1a == "anim_currentpose") {
                    string sAnimName = llList2String(llParseString2List(llList2String(lParam, 1),[","],[]),0);
                    integer iIndex = llListFindList(g_lCollarPoses,[sAnimName]);
                    if (iIndex > -1) {
                        llRegionSayTo(g_kWearer,g_iChan_ocCmd,(string)g_kWearer+":clearchain:all");
                        llMessageLinked(LINK_THIS,g_iChan_ocCmd,(string)g_kWearer+":clearchain:all","");
                        llRegionSayTo(g_kWearer,g_iChan_ocCmd,(string)g_kWearer+":occhains:"+llList2String(g_lCollarPoses,iIndex+1));
                        llMessageLinked(LINK_THIS,g_iChan_ocCmd,(string)g_kWearer+":occhains:"+llList2String(g_lCollarPoses,iIndex+1),"");
                        applyRLV(sAnimName);
                        g_sCurrentCollarPose = sAnimName;
                    } else {
                        llRegionSayTo(g_kWearer,g_iChan_ocCmd,(string)g_kWearer+":clearchain:all");
                        applyRLV("");
                        g_sCurrentCollarPose = "";
                    }
                }
            }
        } else if(iNum == LM_SETTING_DELETE){
            // This is recieved back from settings when a setting is deleted
            list lSettings = llParseString2List(sStr, ["_"],[]);
            if(llList2String(lSettings,0)=="global") {
                if(llList2String(lSettings,1) == "locked") if (g_bSyncLock) lock(FALSE,TRUE);
            } else if (llList2String(lSettings,0)=="anim") {
                if (llList2String(lSettings,1) == "currentpose") {
                    llRegionSayTo(g_kWearer,g_iChan_ocCmd,(string)g_kWearer+":clearchain:all");
                    llMessageLinked(LINK_THIS,g_iChan_ocCmd,(string)g_kWearer+":clearchain:all","");
                    applyRLV("");
                    g_sCurrentCollarPose = "";
                }
            }
        } else if (iNum == AUTH_REPLY){
            list lResponse = llParseString2List(sStr,["|"], []);
            if (llList2String(lResponse,0) == "AuthReply"){
                if ((string)kID =="cuffmenu" && llList2Integer(lResponse,2) <= CMD_EVERYONE) Menu(llList2Key(lResponse,1),llList2Integer(lResponse,2));
                else if (llList2Integer(lResponse,2) > CMD_EVERYONE) llMessageLinked(LINK_ALL_OTHERS, NOTIFY, "0"+"%NOACCESS%", llList2Key(lResponse,1));
            }
        } else if (iNum == CMD_SAFEWORD || iNum == RLV_CLEAR) {
            doClearAllPoses();
        } else if (iNum == RLV_ON) {
            g_bRLV = TRUE;
             llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":RLV:1");
        } else if (iNum == RLV_OFF) {
            g_bRLV = FALSE;
             llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":RLV:0");
        }
    }
    
    changed (integer iChange){
        if (iChange & CHANGED_INVENTORY) llResetScript();
    }
    
    listen(integer iChan, string sName, key kID, string sMsg) {
        if (iChan == g_iChan_ocCmd){
            list lCMD = llParseString2List(sMsg,[":"],[]);
            key kCmdTarget = llList2Key(lCMD,0);
            if (kCmdTarget == g_kWearer) {
                string sCMD = llList2String(lCMD,1);
                string sParam = llList2String(lCMD,2);
                
                if (sCMD == "addposes") {
                    list lPoseList = llParseString2List(sParam,[","],[]);
                    integer i;
                    for (i=0; i<llGetListLength(lPoseList);++i){
                        if (llListFindList(g_lPoses,[llList2String(lPoseList,i)]) == -1) g_lPoses += [llList2String(lPoseList,i)];
                    }
                } else if (sCMD == "remposes") {
                    list lPoseList = llParseString2List(sParam,[","],[]);
                    integer i;
                    for (i=0; i<llGetListLength(lPoseList);++i){
                        integer iDelIndex = llListFindList(g_lPoses,[llList2String(lPoseList,i)]);
                        if (iDelIndex > -1) g_lPoses = llDeleteSubList(g_lPoses,iDelIndex,iDelIndex);
                    }
                } else if (sCMD == "rlvcmd") {
                    llMessageLinked(LINK_SET,RLV_CMD,llList2String(lCMD,3),sParam);
                } else if (sCMD == "ping") {
                    llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "Cuffs_chaintex",g_kWearer);
                    llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "global_locked",g_kWearer);
                    llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "Cuffs_Poses",g_kWearer);
                    llMessageLinked(LINK_ALL_OTHERS, LM_SETTING_REQUEST, "Cuffs_lock",g_kWearer);
                    if (g_bRLV) llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":RLV:1");
                    else llRegionSayTo(g_kWearer, g_iChan_ocCmd, (string)g_kWearer+":RLV:0");
                } else if (sCMD == "menu") llMessageLinked(LINK_AUTH,AUTH_REQUEST,"cuffmenu",(key)sParam); // Check auth before opening the Menu
            }
        }
    }
}
