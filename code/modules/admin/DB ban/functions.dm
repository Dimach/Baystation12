datum/admins/proc/DB_staffwarn_record(var/ckey, var/reason)
	if(!check_rights((R_ADMIN|R_MOD), 0)) return
	if(!istext(reason)) return
	_DB_staffwarn_record(ckey, reason)

/proc/_DB_staffwarn_record(var/ckey, var/reason)
	if(usr && !check_rights((R_ADMIN|R_MOD), 0))
		return
	var/dbreason = sql_sanitize_text(reason)
	var/dbckey = sql_sanitize_text(ckey)

	establish_db_connection()
	if(!dbcon.IsConnected())
		to_chat(usr,"<span class='error'>Failed adding StaffWarn: db error</span>")
		return

	var/DBQuery/query = dbcon.NewQuery("SELECT ckey FROM erro_player WHERE ckey = '[dbckey]'")
	query.Execute()
	var/playerckey
	if(query.NextRow())
		playerckey = query.item[1]
	if(!playerckey)
		to_chat(usr,"<font color='red'>You've attempted to set staffwarn on [ckey], but they haven't been seen yet. Staffwarn can only be set on existing players.</font>")
		return
	query = dbcon.NewQuery("UPDATE erro_player SET staffwarn='[dbreason]' WHERE ckey = '[playerckey]'")
	query.Execute()
	to_chat(usr,"<span class='notice'>StaffWarn saved to DB</span>")

datum/admins/proc/DB_staffwarn_remove(var/ckey)
	if(!check_rights((R_ADMIN|R_MOD), 0)) return
	var/dbckey = sql_sanitize_text(ckey)

	establish_db_connection()
	if(!dbcon.IsConnected())
		to_chat(usr,"<span class='error'>Failed removing StaffWarn: db error</span>")
		return 0

	var/DBQuery/query = dbcon.NewQuery("UPDATE erro_player SET staffwarn=NULL WHERE ckey='[dbckey]'")
	query.Execute()
	if(query.RowsAffected() != 1)
		to_chat(usr,"<span class='error'>StaffWarn unable to be removed from DB</span>")
		return 0
	to_chat(usr,"<span class='notice'>StaffWarn removed from DB</span>")
	return 1

datum/admins/proc/DB_ban_record(var/bantype, var/mob/banned_mob, var/duration = -1, var/reason, var/job = "", var/rounds = 0, var/banckey = null, var/banip = null, var/bancid = null)
	if(!src || !src.owner)
		return
	_DB_ban_record(src.owner.ckey, src.owner.computer_id, src.owner.address, bantype, banned_mob, duration, reason, job, rounds, banckey, banip, bancid)

//Either pass the mob you wish to ban in the 'banned_mob' attribute, or the banckey, banip and bancid variables. If both are passed, the mob takes priority! If a mob is not passed, banckey is the minimum that needs to be passed! banip and bancid are optional.
/proc/_DB_ban_record(var/a_ckey, var/a_computerid, var/a_ip, var/bantype, var/mob/banned_mob, var/duration = -1, var/reason, var/role = "", var/rounds = 0, var/banckey = null, var/banip = null, var/bancid = null)

	if(usr)
		if(!check_rights(R_MOD,0) && !check_rights(R_BAN))	return

	establish_db_connection()
	if(!dbcon.IsConnected())
		return 0

	var/server_ip = world.internet_address
	var/server_port = world.port
	var/bantype_pass = 0
	var/bantype_str
	var/applies_to_admins = 1
	switch(bantype)
		if(BANTYPE_PERMA)
			bantype_str = "PERMABAN"
			role = "Server"
			duration = null
			bantype_pass = 1
		if(BANTYPE_TEMP)
			bantype_str = "TEMPBAN"
			role = "Server"
			bantype_pass = 1
		if(BANTYPE_JOB_PERMA)
			bantype_str = "JOB_PERMABAN"
			duration = null
			bantype_pass = 1
		if(BANTYPE_JOB_TEMP)
			bantype_str = "JOB_TEMPBAN"
			bantype_pass = 1
		if(BANTYPE_APPEARANCE)
			bantype_str = "APPEARANCE_BAN"
			bantype_pass = 1
			role = "Appearance"
		if(BANTYPE_ADMIN_PERMA)
			bantype_str = "ADMIN_PERMABAN"
			role = "Server"
			duration = null
			bantype_pass = 1
			applies_to_admins = 1
		if(BANTYPE_ADMIN_TEMP)
			bantype_str = "ADMIN_TEMPBAN"
			role = "Server"
			bantype_pass = 1
			applies_to_admins = 1

	if( !bantype_pass ) return 0
	if( !istext(reason) ) return 0

	var/ckey
	var/computerid
	var/ip

	if(ismob(banned_mob) && banned_mob.ckey)
		ckey = banned_mob.ckey
		if(banned_mob.client)
			computerid = banned_mob.client.computer_id
			ip = banned_mob.client.address
		else
			if(banned_mob.lastKnownIP)
				ip = banned_mob.lastKnownIP
			if(banned_mob.computer_id)
				computerid = banned_mob.computer_id
	else if(banckey)
		ckey = ckey(banckey)
		computerid = bancid
		ip = banip
		for (var/mob/M in SSmobs.mob_list)
			if (M.ckey == ckey)
				M.ckey = null
				break
	else if(ismob(banned_mob))
		message_admins("<font color='red'>[a_ckey] attempted to add a ban based on a ckey-less mob, with no ckey provided. Report this bug.")
		return
	else
		message_admins("<font color='red'>[a_ckey] attempted to add a ban based on a non-existent mob, with no ckey provided. Report this bug.")
		return

	var/who
	for(var/client/C in GLOB.clients)
		if(!who)
			who = "[C]"
		else
			who += ", [C]"

	var/adminwho
	for(var/client/C in GLOB.admins)
		if(!adminwho)
			adminwho = "[C]"
		else
			adminwho += ", [C]"

	var/reason_public = reason
	reason = sql_sanitize_text(reason)

//[INF]
	if(!computerid)
		computerid = "0"
	if(!ip)
		ip = "0.0.0.0"
//[/INF]

	var/sql = {"
		INSERT INTO [sqlfdbkdbutil].ban (`id`,`bantime`,`server_ip`,`server_port`,`role`,`reason`,`round_id`,`expiration_time`, `applies_to_admins`,`ckey`,`computerid`,`ip`,`a_ckey`,`a_computerid`,`a_ip`,`who`,`adminwho`,`edits`,`server`)
		VALUES (null, Now(), '[server_ip]', '[server_port]', '[role]', '[reason]', null, [duration ? "Now() + INTERVAL [duration] MINUTE" : "null"], '[applies_to_admins]', '[ckey]', '[computerid]', '[ip]', '[a_ckey]', '[a_computerid]', '[a_ip]', '[who]', '[adminwho]', '', '[sqlbansservername]')
	"}
	var/DBQuery/query_insert = dbcon.NewQuery(sql)
	query_insert.Execute()
	var/setter = a_ckey
	if(usr)
		to_chat(usr, "<span class='notice'>Ban saved to database.</span>")
		setter = key_name_admin(usr, 0)

	//[INF]
		if((bantype != BANTYPE_JOB_TEMP) && (bantype != BANTYPE_JOB_PERMA))
			var/banned_key = ckey
			if(ismob(banned_mob))
				banned_key = LAST_CKEY(banned_mob)
				if(banned_mob.client)
					banned_key = get_key(banned_mob)
			to_world_ban(bantype, get_key(usr), banned_key, reason_public, duration)
	//[/INF]

	message_admins("[setter] has added a [bantype_str] for [ckey] [(role)?"([role])":""] [(duration > 0)?"([minutes_to_readable(duration)])":""] with the reason: \"[reason]\" to the ban database.",1)
	return 1



datum/admins/proc/DB_ban_unban(var/ckey, var/bantype, var/role = "")

	if(!check_rights(R_BAN))	return

	if(!sqlbansmodifyfrom.len)
		to_chat(usr, "<span class='boldannounce'>This server not allowed to edit any bans!</span>")
		return

	var/bantype_str
	var/applies_to_admins = 0
	if(bantype)
		var/bantype_pass = 0
		switch(bantype)
			if(BANTYPE_PERMA)
				bantype_str = "PERMABAN"
				role = "Server"
				bantype_pass = 1
			if(BANTYPE_TEMP)
				bantype_str = "TEMPBAN"
				role = "Server"
				bantype_pass = 1
			if(BANTYPE_JOB_PERMA)
				bantype_str = "JOB_PERMABAN"
				bantype_pass = 1
			if(BANTYPE_JOB_TEMP)
				bantype_str = "JOB_TEMPBAN"
				bantype_pass = 1
			if(BANTYPE_APPEARANCE)
				bantype_str = "APPEARANCE_BAN"
				role = "Appearance"
				bantype_pass = 1
			if(BANTYPE_ADMIN_PERMA)
				bantype_str = "ADMIN_PERMABAN"
				role = "Server"
				bantype_pass = 1
				applies_to_admins = 1
			if(BANTYPE_ADMIN_TEMP)
				bantype_str = "ADMIN_TEMPBAN"
				role = "Server"
				bantype_pass = 1
				applies_to_admins = 1
			if(BANTYPE_ANY_FULLBAN)
				bantype_str = "ANY"
				bantype_pass = 1
		if( !bantype_pass ) return

	var/sql = "SELECT id FROM [sqlfdbkdbutil].ban WHERE ckey='[ckey]' AND (unbanned_datetime is null) AND (server IN ('[jointext(sqlbansmodifyfrom, "','")]'))"
	if(bantype_str == "ANY")
		sql += " AND (isnull(expiration_time) OR expiration_time > Now())"
	else
		sql += " AND applies_to_admins = [applies_to_admins]"
		if(role)
			sql += " AND role='[role]'"

	establish_db_connection()
	if(!dbcon.IsConnected())
		return

	var/ban_id
	var/ban_number = 0 //failsafe

	var/DBQuery/query = dbcon.NewQuery(sql)
	query.Execute()
	while(query.NextRow())
		ban_id = query.item[1]
		ban_number++;

	if(ban_number == 0)
		to_chat(usr, "<span class='warning'>Database update failed due to no bans fitting the search criteria. If this is not a legacy ban you should contact the database admin.</span>")
		return

	if(ban_number > 1)
		to_chat(usr, "<span class='warning'>Database update failed due to multiple bans fitting the search criteria. Note down the ckey, job and current time and contact the database admin.</span>")
		return

	if(istext(ban_id))
		ban_id = text2num(ban_id)
	if(!isnum(ban_id))
		to_chat(usr, "<span class='warning'>Database update failed due to a ban ID mismatch. Contact the database admin.</span>")
		return

	DB_ban_unban_by_id(ban_id)

datum/admins/proc/DB_ban_edit(var/banid = null, var/param = null)

	if(!check_rights(R_BAN))	return

	if(!isnum(banid) || !istext(param))
		to_chat(usr, "Cancelled")
		return

	if(!sqlbansmodifyfrom.len)
		to_chat(usr, "<span class='boldannounce'>This server not allowed to edit any bans!</span>")
		return

	var/DBQuery/query = dbcon.NewQuery("SELECT ckey, expiration_time, reason FROM [sqlfdbkdbutil].ban WHERE id=[banid] AND (server IN ('[jointext(sqlbansmodifyfrom, "','")]'))")
	query.Execute()

	var/eckey = usr.ckey	//Editing admin ckey
	var/pckey				//(banned) Player ckey
	var/expiration_time			//Old expiration time
	var/reason				//Old reason

	if(query.NextRow())
		pckey = query.item[1]
		expiration_time = query.item[2]
		reason = query.item[3]
	else
		to_chat(usr, "Invalid ban id. Contact the database admin")
		return

	reason = sql_sanitize_text(reason)
	var/value

	switch(param)
		if("reason")
			if(!value)
				value = sanitize(input("Insert the new reason for [pckey]'s ban", "New Reason", "[reason]", null) as null|text)
				value = sql_sanitize_text(value)
				if(!value)
					to_chat(usr, "Cancelled")
					return

			var/DBQuery/update_query = dbcon.NewQuery("UPDATE [sqlfdbkdbutil].ban SET reason = '[value]', edits = CONCAT(edits,'- [eckey] changed ban reason from <cite><b>\\\"[reason]\\\"</b></cite> to <cite><b>\\\"[value]\\\"</b></cite><BR>') WHERE id = [banid]")
			update_query.Execute()
			message_admins("[key_name_admin(usr)] has edited a ban for [pckey]'s reason from [reason] to [value]",1)
			to_world_ban("EDIT", get_key(usr), pckey, reason = "[reason]@#*$#@[value]")	// INF
		if("duration")
			if(!value)
				value = input("Insert the new duration (in minutes) for [pckey]'s ban", "New Duration", "1440", null) as null|num
				if(!isnum(value) || !value)
					to_chat(usr, "Cancelled")
					return

			var/DBQuery/update_query = dbcon.NewQuery("UPDATE [sqlfdbkdbutil].ban SET edits = CONCAT(edits,'- [eckey] changed ban duration from [expiration_time] to [value]<br>'), expiration_time = DATE_ADD(bantime, INTERVAL [value] MINUTE) WHERE id = [banid]")
			message_admins("[key_name_admin(usr)] has edited a ban for [pckey]'s duration from [expiration_time] to [value]",1)
			update_query.Execute()
			to_world_ban("EDIT", get_key(usr), pckey, duration = "[expiration_time] - [value]")	// INF
		if("unban")
			if(alert("Unban [pckey]?", "Unban?", "Yes", "No") == "Yes")
				DB_ban_unban_by_id(banid)
				to_world_ban("UNBAN", get_key(usr), pckey)	// INF
				return
			else
				to_chat(usr, "Cancelled")
				return
		else
			to_chat(usr, "Cancelled")
			return

datum/admins/proc/DB_ban_unban_by_id(var/id)

	if(!check_rights(R_BAN))	return

	establish_db_connection()
	if(!dbcon.IsConnected())
		return

	if(!sqlbansmodifyfrom.len)
		to_chat(usr, "<span class='boldannounce'>This server not allowed to edit any bans!</span>")
		return

	var/sql = "SELECT ckey FROM [sqlfdbkdbutil].ban WHERE id = [id] AND (server IN ('[jointext(sqlbansmodifyfrom, "','")]'))"

	var/ban_number = 0 //failsafe

	var/pckey
	var/DBQuery/query = dbcon.NewQuery(sql)
	query.Execute()
	while(query.NextRow())
		pckey = query.item[1]
		ban_number++;

	if(ban_number == 0)
		to_chat(usr, "<span class='warning'>Database update failed due to a ban id not being present in the database.</span>")
		return

	if(ban_number > 1)
		to_chat(usr, "<span class='warning'>Database update failed due to multiple bans having the same ID. Contact the database admin.</span>")
		return

	if(!src.owner || !istype(src.owner, /client))
		return

	var/unban_ckey = src.owner:ckey
	var/unban_computerid = src.owner:computer_id
	var/unban_ip = src.owner:address

	var/sql_update = "UPDATE [sqlfdbkdbutil].ban SET unbanned_datetime = Now(), unbanned_ckey = '[unban_ckey]', unbanned_computerid = '[unban_computerid]', unbanned_ip = '[unban_ip]' WHERE id = [id]"
	message_admins("[key_name_admin(usr)] has lifted [pckey]'s ban.",1)

	var/DBQuery/query_update = dbcon.NewQuery(sql_update)
	query_update.Execute()


/client/proc/DB_ban_panel()
	set category = "Admin"
	set name = "Banning Panel"
	set desc = "Edit admin permissions"

	if(!holder)
		return

	holder.DB_ban_panel()


/datum/admins/proc/DB_ban_panel(var/playerckey = null, var/adminckey = null, var/playerip = null, var/playercid = null, var/dbbantype = null, var/match = null)
	if(!usr.client)
		return

	if(!check_rights(R_BAN))	return

	establish_db_connection()
	if(!dbcon.IsConnected())
		to_chat(usr, "<span class='warning'>Failed to establish database connection</span>")
		return

	if(!sqlbansreadfrom.len)
		to_chat(usr, "<span class='boldannounce'>This server not allowed to display any bans!</span>")
		return

	var/output = "<div align='center'><table width='90%'><tr>"

	output += "<td width='35%' align='center'>"
	output += "<h1>Banning panel</h1>"
	output += "</td>"

	output += "<td width='65%' align='center' bgcolor='#f9f9f9'>"

	output += "<form method='GET' action='?src=\ref[src]'><b>Add custom ban:</b> (ONLY use this if you can't ban through any other method)"
	output += "<input type='hidden' name='src' value='\ref[src]'>"
	output += "<table width='100%'><tr>"
	output += "<td width='50%' align='right'><b>Ban type:</b><select name='dbbanaddtype'>"
	output += "<option value=''>--</option>"
	output += "<option value='[BANTYPE_PERMA]'>PERMABAN</option>"
	output += "<option value='[BANTYPE_TEMP]'>TEMPBAN</option>"
	output += "<option value='[BANTYPE_JOB_PERMA]'>JOB PERMABAN</option>"
	output += "<option value='[BANTYPE_JOB_TEMP]'>JOB TEMPBAN</option>"
	output += "<option value='[BANTYPE_ADMIN_PERMA]'>ADMIN PERMABAN</option>"
	output += "<option value='[BANTYPE_ADMIN_TEMP]'>ADMIN TEMPBAN</option>"
	output += "</select></td>"
	output += "<td width='50%' align='right'><b>Ckey:</b> <input type='text' name='dbbanaddckey'></td></tr>"
	output += "<tr><td width='50%' align='right'><b>IP:</b> <input type='text' name='dbbanaddip'></td>"
	output += "<td width='50%' align='right'><b>CID:</b> <input type='text' name='dbbanaddcid'></td></tr>"
	output += "<tr><td width='50%' align='right'><b>Duration:</b> <input type='text' name='dbbaddduration'></td>"
	output += "<td width='50%' align='right'><b>Job:</b><select name='dbbanaddjob'>"
	output += "<option value=''>--</option>"
	for(var/j in SSjobs.titles_to_datums)
		output += "<option value='[j]'>[j]</option>"
	for(var/j in SSjobs.titles_by_department(MSC))
		output += "<option value='[j]'>[j]</option>"
	var/list/bantypes = list("traitor","changeling","operative","revolutionary","cultist","wizard") //For legacy bans.
	var/list/all_antag_types = GLOB.all_antag_types_
	for(var/antag_type in all_antag_types) // Grab other bans.
		var/datum/antagonist/antag = all_antag_types[antag_type]
		bantypes |= antag.id
	for(var/j in bantypes)
		output += "<option value='[j]'>[j]</option>"
	output += "</select></td></tr></table>"
	output += "<b>Reason:<br></b><textarea name='dbbanreason' cols='50'></textarea><br>"
	output += "<input type='submit' value='Add ban'>"
	output += "</form>"

	output += "</td>"
	output += "</tr>"
	output += "</table>"

	output += "<form method='GET' action='?src=\ref[src]'><table width='60%'><tr><td colspan='2' align='left'><b>Search:</b>"
	output += "<input type='hidden' name='src' value='\ref[src]'></td></tr>"
	output += "<tr><td width='50%' align='right'><b>Ckey:</b> <input type='text' name='dbsearchckey' value='[playerckey]'></td>"
	output += "<td width='50%' align='right'><b>Admin ckey:</b> <input type='text' name='dbsearchadmin' value='[adminckey]'></td></tr>"
	output += "<tr><td width='50%' align='right'><b>IP:</b> <input type='text' name='dbsearchip' value='[playerip]'></td>"
	output += "<td width='50%' align='right'><b>CID:</b> <input type='text' name='dbsearchcid' value='[playercid]'></td></tr>"
	output += "<tr><td width='50%' align='right' colspan='2'><b>Ban type:</b><select name='dbsearchbantype'>"
	output += "<option value=''>--</option>"
	output += "<option value='[BANTYPE_PERMA]'>PERMABAN</option>"
	output += "<option value='[BANTYPE_TEMP]'>TEMPBAN</option>"
	output += "<option value='[BANTYPE_JOB_PERMA]'>JOB PERMABAN</option>"
	output += "<option value='[BANTYPE_JOB_TEMP]'>JOB TEMPBAN</option>"
	output += "<option value='[BANTYPE_ADMIN_PERMA]'>ADMIN PERMABAN</option>"
	output += "<option value='[BANTYPE_ADMIN_TEMP]'>ADMIN TEMPBAN</option>"
	output += "</select></td></tr></table>"
	output += "<br><input type='submit' value='search'><br>"
	output += "<input type='checkbox' value='[match]' name='dbmatch' [match? "checked=\"1\"" : null]> Match(min. 3 characters to search by key or ip, and 7 to search by cid)<br>"
	output += "</form>"
	output += "Please note that all jobban bans or unbans are in-effect the following round.<br>"
	output += "This search shows only last 100 bans."

	if(adminckey || playerckey || playerip || playercid || dbbantype)

		adminckey = ckey(adminckey)
		playerckey = ckey(playerckey)
		playerip = sql_sanitize_text(playerip)
		playercid = sql_sanitize_text(playercid)

		if(adminckey || playerckey || playerip || playercid || dbbantype)

			var/blcolor = "#ffeeee" //banned light
			var/bdcolor = "#ffdddd" //banned dark
			var/ulcolor = "#eeffee" //unbanned light
			var/udcolor = "#ddffdd" //unbanned dark
			var/alcolor = "#eeeeff" // auto-unbanned light
			var/adcolor = "#ddddff" // auto-unbanned dark

			output += "<table width='90%' bgcolor='#e3e3e3' cellpadding='5' cellspacing='0' align='center'>"
			output += "<tr>"
			output += "<th width='25%'><b>TYPE</b></th>"
			output += "<th width='20%'><b>CKEY</b></th>"
			output += "<th width='20%'><b>TIME APPLIED</b></th>"
			output += "<th width='20%'><b>ADMIN</b></th>"
			output += "<th width='15%'><b>OPTIONS</b></th>"
			output += "</tr>"

			var/adminsearch = ""
			var/playersearch = ""
			var/ipsearch = ""
			var/cidsearch = ""
			var/bantypesearch = ""

			if(!match)
				if(adminckey)
					adminsearch = "AND a_ckey = '[adminckey]' "
				if(playerckey)
					playersearch = "AND ckey = '[playerckey]' "
				if(playerip)
					ipsearch  = "AND ip = '[playerip]' "
				if(playercid)
					cidsearch  = "AND computerid = '[playercid]' "
			else
				if(adminckey && length(adminckey) >= 3)
					adminsearch = "AND a_ckey LIKE '[adminckey]%' "
				if(playerckey && length(playerckey) >= 3)
					playersearch = "AND ckey LIKE '[playerckey]%' "
				if(playerip && length(playerip) >= 3)
					ipsearch  = "AND ip LIKE '[playerip]%' "
				if(playercid && length(playercid) >= 7)
					cidsearch  = "AND computerid LIKE '[playercid]%' "

			if(dbbantype)
				switch(dbbantype)
					if(BANTYPE_TEMP)
						bantypesearch = "AND expiration_time != null AND applies_to_admins = 0 AND role = 'Server'"
					if(BANTYPE_JOB_PERMA)
						bantypesearch = "AND expiration_time = null AND applies_to_admins = 0 AND role != 'Server' AND role != 'Appearance'"
					if(BANTYPE_JOB_TEMP)
						bantypesearch = "AND expiration_time != null AND applies_to_admins = 0 AND role != 'Server' AND role != 'Appearance'"
					if(BANTYPE_ADMIN_PERMA)
						bantypesearch = "AND expiration_time = null AND applies_to_admins = 0 AND role = 'Server'"
					if(BANTYPE_ADMIN_TEMP)
						bantypesearch = "AND expiration_time != null AND applies_to_admins = 1 AND role = 'Server'"
					else
						bantypesearch = "AND expiration_time = null AND applies_to_admins = 0 AND role = 'Server'"

			var/DBQuery/select_query = dbcon.NewQuery({"
			SELECT id, bantime, reason, role, expiration_time, ckey, a_ckey, unbanned_ckey, unbanned_datetime, edits, ip, computerid, applies_to_admins, server
			FROM [sqlfdbkdbutil].ban WHERE (server IN ('[jointext(sqlbansreadfrom, "','")]')) [playersearch] [adminsearch] [ipsearch] [cidsearch] [bantypesearch] ORDER BY bantime DESC LIMIT 100"})
			select_query.Execute()

			var/now = time2text(world.realtime, "YYYY-MM-DD hh:mm:ss") // MUST BE the same format as SQL gives us the dates in, and MUST be least to most specific (i.e. year, month, day not day, month, year)

			while(select_query.NextRow())
				var/banid = select_query.item[1]
				var/bantime = select_query.item[2]
				var/reason = select_query.item[3]
				var/role = select_query.item[4]
				var/expiration = select_query.item[5]
				var/ckey = select_query.item[6]
				var/ackey = select_query.item[7]
				var/unbanckey = select_query.item[8]
				var/unbantime = select_query.item[9]
				var/edits = select_query.item[10]
				var/ip = select_query.item[11]
				var/cid = select_query.item[12]
				var/applies_to_admins = select_query.item[13]
				var/server_name = select_query.item[14]

				var/can_edit = sqlbansmodifyfrom.Find(server_name)
				var/lcolor = blcolor
				var/dcolor = bdcolor
				if(unbantime)
					lcolor = ulcolor
					dcolor = udcolor

				var/list/ban_titles = list()
				if (applies_to_admins)
					ban_titles.Add("ADMIN")

				ban_titles.Add(isnull(expiration) ? "PERMABAN" : "TEMPBAN")

				if(role == "Appearance")
					ban_titles.Add("APPEARANCEBAN")
				else if (role != "Server")
					ban_titles.Add("JOBBAN")

				var/ban_title_text = ban_titles.Join(" ")
				var/typedesc =""
				if (isnull(expiration))
					typedesc = "<font color='red'><b>[ban_title_text]</b></font>"
				else
					typedesc = "<b>[ban_title_text]</b><br><font size='2'>[role]<br>[(unbantime || !can_edit) ? "" : "(<a href=\"byond://?src=\ref[src];dbbanedit=duration;dbbanid=[banid]\">Edit</a>)"]<br>Expires [expiration]</font>"

				output += "<tr bgcolor='[dcolor]'>"
				output += "<td align='center'>[typedesc]</td>"
				output += "<td align='center'><b>[ckey]</b></td>"
				output += "<td align='center'>[bantime]</td>"
				output += "<td align='center'><b>[ackey]</b></td>"
				output += "<td align='center'>[(unbantime || !can_edit) ? "" : "<b><a href=\"byond://?src=\ref[src];dbbanedit=unban;dbbanid=[banid]\">Unban</a></b>"]</td>"
				output += "</tr>"
				output += "<tr bgcolor='[dcolor]'>"
				output += "<td align='center' colspan='2' bgcolor=''><b>IP:</b> [ip]</td>"
				output += "<td align='center' colspan='3' bgcolor=''><b>CIP:</b> [cid]</td>"
				output += "</tr>"
				output += "<tr bgcolor='[lcolor]'>"
				output += "<td align='center' colspan='5'><b>Reason: [(unbantime || !can_edit) ? "" : "(<a href=\"byond://?src=\ref[src];dbbanedit=reason;dbbanid=[banid]\">Edit</a>)"]</b> <cite>\"[reason]\"</cite></td>"
				output += "</tr>"
				if(edits)
					output += "<tr bgcolor='[dcolor]'>"
					output += "<td align='center' colspan='5'><b>EDITS</b></td>"
					output += "</tr>"
					output += "<tr bgcolor='[lcolor]'>"
					output += "<td align='center' colspan='5'><font size='2'>[edits]</font></td>"
					output += "</tr>"
				if(unbantime)
					output += "<tr bgcolor='[dcolor]'>"
					output += "<td align='center' colspan='5' bgcolor=''><b>UNBANNED by admin [unbanckey] on [unbantime]</b></td>"
					output += "</tr>"
				else if(expiration && now > expiration)
					output += "<tr bgcolor='[dcolor]'>"
					output += "<td align='center' colspan='5' bgcolor=''><b>EXPIRED at [expiration]</b></td>"
					output += "</tr>"
				output += "<tr>"
				output += "<td colspan='5' bgcolor='white'>&nbsp</td>"
				output += "</tr>"

			output += "</table></div>"

	show_browser(usr, output,"window=lookupbans;size=900x700")
