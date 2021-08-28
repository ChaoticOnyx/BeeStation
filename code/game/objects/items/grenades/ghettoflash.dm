/obj/item/grenade/flashbang/beer_keg
	name = "Beer Keg Grenade"
	desc = "Looks like it's going to explode"
	w_class = WEIGHT_CLASS_BULKY
	icon = 'icons/Crimson Dragon/beer_keg.dmi'
	icon_state = "beer_keg_grenade"
	item_state = "beer_keg"
	lefthand_file = 'icons/Crimson Dragon/items_lefthand.dmi'
	righthand_file = 'icons/Crimson Dragon/items_righthand.dmi'
	flashbang_range = 7 //how many tiles away the mob will be stunned.

/obj/item/grenade/flashbang/beer_keg/preprime(mob/user, delayoverride, msg = TRUE, volume = 60)
	det_time = rand(30,60)
	var/turf/T = get_turf(src)
	log_grenade(user, T) //Inbuilt admin procs already handle null users
	if(user)
		add_fingerprint(user)
		if(msg)
			to_chat(user, "<span class='warning'>You prime [src]! It will explode in a random amount of time! </span>")
	if(shrapnel_type && shrapnel_radius)
		shrapnel_initialized = TRUE
		AddComponent(/datum/component/pellet_cloud, projectile_type=shrapnel_type, magnitude=shrapnel_radius)
	playsound(src, 'sound/effects/zzzt.ogg', volume, 1)
	active = TRUE
	icon_state = initial(icon_state) + "_active"
	SEND_SIGNAL(src, COMSIG_GRENADE_ARMED, det_time, delayoverride)
	addtimer(CALLBACK(src, .proc/prime), isnull(delayoverride)? det_time : delayoverride)

/obj/item/grenade/flashbang/beer_keg/bang(turf/T , mob/living/M)
	if(M.stat == DEAD)	//They're dead!
		return
	M.show_message("<span class='warning'>BANG</span>", MSG_AUDIBLE)
	var/distance = max(0,get_dist(get_turf(src),T))

//Bang
	if(!distance || loc == M || loc == M.loc)	//Stop allahu akbarring rooms with this.
		M.Paralyze(20)
		M.Knockdown(200)
		M.soundbang_act(1, 200, 10, 15)
	else
		if(distance <= 1)
			M.Paralyze(5)
			M.Knockdown(30)
		M.soundbang_act(1, max(200/max(1,distance), 60), rand(0, 5))

/obj/item/grenade/flashbang/beer_keg/attackby(obj/item/W, mob/user, params)
	if(W.tool_behaviour == TOOL_SCREWDRIVER)
		to_chat(user, "<span class='notice'>You can't adjust detonation time on [name]</span>")
		add_fingerprint(user)
	else
		return ..()
