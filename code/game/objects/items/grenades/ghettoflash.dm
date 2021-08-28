/obj/item/grenade/flashbang/beer_keg
	name = "Beer Keg Grenade"
	icon = 'icons/obj/beer_keg.dmi'
	icon_state = "beer_keg_grenade"
	item_state = "beer_keg"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	flashbang_range = 7 //how many tiles away the mob will be stunned.

/obj/item/grenade/flashbang/bang(turf/T , mob/living/M)
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

/obj/item/grenade/attackby(obj/item/W, mob/user, params)
	if(W.tool_behaviour == TOOL_SCREWDRIVER)
		to_chat(user, "<span class='notice'>You can't adjust detonation time on [name]</span>")
		add_fingerprint(user)
	else
		return ..()
