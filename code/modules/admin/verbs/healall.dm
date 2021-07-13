/client/proc/healall()
	set name = "Heal Everybody"
	set desc = "Heals every mob in the game"
	set category = "Fun"
	if(!src.holder)
		to_chat(src, "Only administrators may use this command.", confidential = TRUE)
		return
	if(!check_rights(R_FUN))
		to_chat(src, "You need the fun permission to use this command.", confidential = TRUE)
		return
	if(alert(src, "Confirm Heal All?","Are you sure?","Yes","No") == "No")
		return
	message_admins("[key_name_admin(usr)] healed all living mobs")
	log_admin("[key_name_admin(usr)] healed all living mobs")
	to_chat(world, "<b>The gods have miraculously given everyone new life!</b>", confidential = TRUE)
	for(var/mob/living/M in GLOB.mob_living_list)
		M.revive(TRUE, TRUE)
