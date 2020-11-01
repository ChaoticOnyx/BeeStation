//These mutations change your overall "form" somehow, like size

//Epilepsy gives a very small chance to have a seizure every life tick, knocking you unconscious.
/datum/mutation/human/epilepsy
	name = "Epilepsy"
	desc = "A genetic defect that sporadically causes seizures."
	quality = NEGATIVE
	text_gain_indication = "<span class='danger'>У вас начались головные боли.</span>"
	synchronizer_coeff = 1
	power_coeff = 1

/datum/mutation/human/epilepsy/on_life()
	if(prob(1 * GET_MUTATION_SYNCHRONIZER(src)) && owner.stat == CONSCIOUS)
		owner.visible_message("<span class='danger'>[owner] ловит припадок!</span>", "<span class='userdanger'>У вас начался припадок!</span>")
		owner.Unconscious(200 * GET_MUTATION_POWER(src))
		owner.Jitter(1000 * GET_MUTATION_POWER(src))
		SEND_SIGNAL(owner, COMSIG_ADD_MOOD_EVENT, "epilepsy", /datum/mood_event/epilepsy)
		addtimer(CALLBACK(src, .proc/jitter_less), 90)

/datum/mutation/human/epilepsy/proc/jitter_less()
	if(owner)
		owner.jitteriness = 10


//Unstable DNA induces random mutations!
/datum/mutation/human/bad_dna
	name = "Unstable DNA"
	desc = "Strange mutation that causes the holder to randomly mutate."
	quality = NEGATIVE
	text_gain_indication = "<span class='danger'>Вы ощущаете себя странно.</span>"
	locked = TRUE

/datum/mutation/human/bad_dna/on_acquiring(mob/living/carbon/human/owner)
	if(..())
		return
	to_chat(owner, text_gain_indication)
	var/mob/new_mob
	if(prob(95))
		if(prob(50))
			new_mob = owner.easy_randmut(NEGATIVE + MINOR_NEGATIVE)
		else
			new_mob = owner.randmuti()
	else
		new_mob = owner.easy_randmut(POSITIVE)
	if(new_mob && ismob(new_mob))
		owner = new_mob
	. = owner
	on_losing(owner)


//Cough gives you a chronic cough that causes you to drop items.
/datum/mutation/human/cough
	name = "Cough"
	desc = "A chronic cough."
	quality = MINOR_NEGATIVE
	text_gain_indication = "<span class='danger'>Вы начали кашлять.</span>"
	synchronizer_coeff = 1
	power_coeff = 1

/datum/mutation/human/cough/on_life()
	if(prob(5 * GET_MUTATION_SYNCHRONIZER(src)) && owner.stat == CONSCIOUS)
		owner.drop_all_held_items()
		owner.emote("cough")
		if(GET_MUTATION_POWER(src) > 1)
			var/cough_range = GET_MUTATION_POWER(src) * 4
			var/turf/target = get_ranged_target_turf(owner, turn(owner.dir, 180), cough_range)
			owner.throw_at(target, cough_range, GET_MUTATION_POWER(src))

/datum/mutation/human/paranoia
	name = "Paranoia"
	desc = "Subject is easily terrified, and may suffer from hallucinations."
	quality = NEGATIVE
	text_gain_indication = "<span class='danger'>Вы чувствуете, как крики разносятся эхом в вашей голове ...</span>"
	text_lose_indication = "<span class'notice'>Крики в вашей голове прекратились.</span>"

/datum/mutation/human/paranoia/on_life()
	if(prob(5) && owner.stat == CONSCIOUS)
		owner.emote("scream")
		if(prob(25))
			owner.hallucination += 20

//Dwarfism shrinks your body and lets you pass tables.
/datum/mutation/human/dwarfism
	name = "Dwarfism"
	desc = "A mutation believed to be the cause of dwarfism."
	quality = POSITIVE
	difficulty = 16
	instability = 5
	conflicts = list(GIGANTISM)
	locked = TRUE    // Default intert species for now, so locked from regular pool.

/datum/mutation/human/dwarfism/on_acquiring(mob/living/carbon/human/owner)
	if(..())
		return
	owner.transform = owner.transform.Scale(1, 0.8)
	passtable_on(owner, GENETIC_MUTATION)
	owner.visible_message("<span class='danger'>[owner] внезапно уменьшается!</span>", "<span class='notice'>Всё вокруг вас внезапно увеличилось...</span>")

/datum/mutation/human/dwarfism/on_losing(mob/living/carbon/human/owner)
	if(..())
		return
	owner.transform = owner.transform.Scale(1, 1.25)
	passtable_off(owner, GENETIC_MUTATION)
	owner.visible_message("<span class='danger'>[owner] внезапно увеличивается!</span>", "<span class='notice'>Всё вокруг вас внезапно уменьшилось...</span>")


//Clumsiness has a very large amount of small drawbacks depending on item.
/datum/mutation/human/clumsy
	name = "Clumsiness"
	desc = "A genome that inhibits certain brain functions, causing the holder to appear clumsy. Honk"
	quality = MINOR_NEGATIVE
	text_gain_indication = "<span class='danger'>Ваша голова кружится.</span>"

/datum/mutation/human/clumsy/on_acquiring(mob/living/carbon/human/owner)
	if(..())
		return
	ADD_TRAIT(owner, TRAIT_CLUMSY, GENETIC_MUTATION)

/datum/mutation/human/clumsy/on_losing(mob/living/carbon/human/owner)
	if(..())
		return
	REMOVE_TRAIT(owner, TRAIT_CLUMSY, GENETIC_MUTATION)


//Tourettes causes you to randomly stand in place and shout.
/datum/mutation/human/tourettes
	name = "Tourette's Syndrome"
	desc = "A chronic twitch that forces the user to scream bad words." //definitely needs rewriting
	quality = NEGATIVE
	text_gain_indication = "<span class='danger'>Вы дёрнулись</span>"
	synchronizer_coeff = 1

/datum/mutation/human/tourettes/on_life()
	if(prob(10 * GET_MUTATION_SYNCHRONIZER(src)) && owner.stat == CONSCIOUS && !owner.IsStun())
		owner.Stun(20)
		switch(rand(1, 3))
			if(1)
				owner.emote("дёргается.")
			if(2 to 3)
				owner.say("[prob(50) ? ";" : ""][pick("ДЕРЬМО", "ЖОПА", "БЛЯТЬ", "ПИЗДЕЦ", "МУДИЛА", "УБЛЮДОК", "ХУЙНЯ")]", forced="tourette's syndrome")
		var/x_offset_old = owner.pixel_x
		var/y_offset_old = owner.pixel_y
		var/x_offset = owner.pixel_x + rand(-2,2)
		var/y_offset = owner.pixel_y + rand(-1,1)
		animate(owner, pixel_x = x_offset, pixel_y = y_offset, time = 1)
		animate(owner, pixel_x = x_offset_old, pixel_y = y_offset_old, time = 1)


//Deafness makes you deaf.
/datum/mutation/human/deaf
	name = "Deafness"
	desc = "The holder of this genome is completely deaf."
	quality = NEGATIVE
	text_gain_indication = "<span class='danger'>Вы перестали что либо слышать.</span>"

/datum/mutation/human/deaf/on_acquiring(mob/living/carbon/human/owner)
	if(..())
		return
	ADD_TRAIT(owner, TRAIT_DEAF, GENETIC_MUTATION)

/datum/mutation/human/deaf/on_losing(mob/living/carbon/human/owner)
	if(..())
		return
	REMOVE_TRAIT(owner, TRAIT_DEAF, GENETIC_MUTATION)


//Monified turns you into a monkey.
/datum/mutation/human/race
	name = "Monkified"
	desc = "A strange genome, believing to be what differentiates monkeys from humans."
	quality = NEGATIVE
	time_coeff = 2
	locked = TRUE //Species specific, keep out of actual gene pool

/datum/mutation/human/race/on_acquiring(mob/living/carbon/human/owner)
	if(..())
		return
	. = owner.monkeyize(TR_KEEPITEMS | TR_KEEPIMPLANTS | TR_KEEPORGANS | TR_KEEPDAMAGE | TR_KEEPVIRUS | TR_KEEPSE)

/datum/mutation/human/race/on_losing(mob/living/carbon/monkey/owner)
	if(owner && istype(owner) && owner.stat != DEAD && (owner.dna.mutations.Remove(src)))
		. = owner.humanize(TR_KEEPITEMS | TR_KEEPIMPLANTS | TR_KEEPORGANS | TR_KEEPDAMAGE | TR_KEEPVIRUS | TR_KEEPSE)

/datum/mutation/human/glow
	name = "Glowy"
	desc = "You permanently emit a light with a random color and intensity."
	quality = POSITIVE
	text_gain_indication = "<span class='notice'>Ваша кожа начала светиться.</span>"
	instability = 5
	var/obj/effect/dummy/luminescent_glow/glowth //shamelessly copied from luminescents
	var/glow = 2.5
	var/range = 2.5
	power_coeff = 1
	conflicts = list(/datum/mutation/human/glow/anti)

/datum/mutation/human/glow/on_acquiring(mob/living/carbon/human/owner)
	. = ..()
	if(.)
		return
	glowth = new(owner)
	modify()

/datum/mutation/human/glow/modify()
	if(!glowth)
		return
	var/power = GET_MUTATION_POWER(src)
	glowth.set_light(range * power, glow * power, "#[dna.features["mcolor"]]")

/datum/mutation/human/glow/on_losing(mob/living/carbon/human/owner)
	. = ..()
	if(.)
		return
	QDEL_NULL(glowth)

/datum/mutation/human/glow/anti
	name = "Anti-Glow"
	desc = "Your skin seems to attract and absorb nearby light creating 'darkness' around you."
	text_gain_indication = "<span class='notice'>Вы чувствуете, как всё вокруг вас погружается во тьму.</span>"
	glow = -3.5 //Slightly stronger, since negating light tends to be harder than making it.
	conflicts = list(/datum/mutation/human/glow)
	locked = TRUE

/datum/mutation/human/strong
	name = "Strength"
	desc = "The user's muscles slightly expand."
	quality = POSITIVE
	text_gain_indication = "<span class='notice'>Вы чувствуете силу.</span>"
	difficulty = 16

/datum/mutation/human/insulated
	name = "Insulated"
	desc = "The affected person does not conduct electricity."
	quality = POSITIVE
	text_gain_indication = "<span class='notice'>Кончики ваших пальцев онемели.</span>"
	text_lose_indication = "<span class='notice'>Чувствительность вернулась к вашим пальцам.</span>"
	difficulty = 16
	instability = 25

/datum/mutation/human/insulated/on_acquiring(mob/living/carbon/human/owner)
	if(..())
		return
	ADD_TRAIT(owner, TRAIT_SHOCKIMMUNE, "genetics")

/datum/mutation/human/insulated/on_losing(mob/living/carbon/human/owner)
	if(..())
		return
	REMOVE_TRAIT(owner, TRAIT_SHOCKIMMUNE, "genetics")

/datum/mutation/human/fire
	name = "Fiery Sweat"
	desc = "The user's skin will randomly combust, but is generally alot more resilient to burning."
	quality = NEGATIVE
	text_gain_indication = "<span class='warning'>Вам жарко.</span>"
	text_lose_indication = "<span class'notice'>Вы почувствовали прохладу.</span>"
	difficulty = 14
	synchronizer_coeff = 1
	power_coeff = 1

/datum/mutation/human/fire/on_life()
	if(prob((1+(100-dna.stability)/10)) * GET_MUTATION_SYNCHRONIZER(src))
		owner.adjust_fire_stacks(2 * GET_MUTATION_POWER(src))
		owner.IgniteMob()

/datum/mutation/human/fire/on_acquiring(mob/living/carbon/human/owner)
	if(..())
		return
	owner.physiology.burn_mod *= 0.5

/datum/mutation/human/fire/on_losing(mob/living/carbon/human/owner)
	if(..())
		return
	owner.physiology.burn_mod *= 2

/datum/mutation/human/badblink
	name = "Spatial Instability"
	desc = "The victim of the mutation has a very weak link to spatial reality, and may be displaced. Often causes extreme nausea."
	quality = NEGATIVE
	text_gain_indication = "<span class='warning'>Вас начало тошнить.</span>"
	text_lose_indication = "<span class'notice'>Похоже, тошнота исчезла.</span>"
	difficulty = 18//high so it's hard to unlock and abuse
	instability = 10
	synchronizer_coeff = 1
	energy_coeff = 1
	power_coeff = 1
	var/warpchance = 0

/datum/mutation/human/badblink/on_life()
	if(prob(warpchance))
		var/warpmessage = pick(
		"<span class='warning'>После тошнотворного разворота на 720 градусов, [owner] растворяется в воздухе.</span>",
		"<span class='warning'>[owner] делает странное сальто в другое измерение. Выглядело довольно болезненно.</span>",
		"<span class='warning'>[owner] делает прыжок влево, шаг вправо и исчезает в никуда.</span>",
		"<span class='warning'>Прежде чем исчезнуть, [owner] выворачивается наизнанку.</span>",
		"<span class='warning'>В какой то момент [owner] показывается перед вами на секунду. Через момент человек исчезает.</span>")
		owner.visible_message(warpmessage, "<span class='userdanger'>После очередного межпространственного прыжка вас затошнило.</span>")
		var/warpdistance = rand(10,15) * GET_MUTATION_POWER(src)
		do_teleport(owner, get_turf(owner), warpdistance, channel = TELEPORT_CHANNEL_FREE)
		owner.adjust_disgust(GET_MUTATION_SYNCHRONIZER(src) * (warpchance * warpdistance))
		warpchance = 0
		owner.visible_message("<span class='danger'>[owner] появляется из ниоткуда!</span>")
	else
		warpchance += 0.25 * GET_MUTATION_ENERGY(src)

/datum/mutation/human/acidflesh
	name = "Acidic Flesh"
	desc = "Subject has acidic chemicals building up underneath their skin. This is often lethal."
	quality = NEGATIVE
	text_gain_indication = "<span class='userdanger'>Вы ощутили адское жжение по всему телу. Кислотные нарывы начали разрастаться по всему телу!</span>"
	text_lose_indication = "<span class'notice'>Жжение прекратилось.</span>"
	difficulty = 18//high so it's hard to unlock and use on others
	var/msgcooldown = 0

/datum/mutation/human/acidflesh/on_life()
	if(prob(25))
		if(world.time > msgcooldown)
			to_chat(owner, "<span class='danger'>Ваша кожа начала пузыриться...</span>")
			msgcooldown = world.time + 200
		if(prob(15))
			owner.acid_act(rand(30,50), 10)
			owner.visible_message("<span class='warning'>Кожа на теле [owner] начала пузыриться и лопаться, извергая кислоту.</span>", "<span class='userdanger'>Кислотные нарывы на вашем теле начали лопаться! Жжётся!</span>")
			playsound(owner,'sound/weapons/sear.ogg', 50, 1)

/datum/mutation/human/gigantism
	name = "Gigantism"//negative version of dwarfism
	desc = "The cells within the subject spread out to cover more area, making them appear larger."
	quality = MINOR_NEGATIVE
	difficulty = 12
	conflicts = list(DWARFISM)

/datum/mutation/human/gigantism/on_acquiring(mob/living/carbon/human/owner)
	if(..())
		return
	owner.resize = 1.25
	owner.update_transform()
	owner.visible_message("<span class='danger'>[owner] внезапно увеличивается!</span>", "<span class='notice'>Всё вокруг вас внезапно уменьшилось..</span>")

/datum/mutation/human/gigantism/on_losing(mob/living/carbon/human/owner)
	if(..())
		return
	owner.resize = 0.8
	owner.update_transform()
	owner.visible_message("<span class='danger'>[owner] внезапно уменьшается!</span>", "<span class='notice'>Всё вокруг вас внезапно увеличилось..</span>")

/datum/mutation/human/spastic
	name = "Spastic"
	desc = "Subject suffers from muscle spasms."
	quality = NEGATIVE
	text_gain_indication = "<span class='warning'>Вы вздрогнули.</span>"
	text_lose_indication = "<span class'notice'>Ваша дрожь утихла.</span>"
	difficulty = 16

/datum/mutation/human/spastic/on_acquiring()
	if(..())
		return
	owner.apply_status_effect(STATUS_EFFECT_SPASMS)

/datum/mutation/human/spastic/on_losing()
	if(..())
		return
	owner.remove_status_effect(STATUS_EFFECT_SPASMS)

/datum/mutation/human/extrastun
	name = "Two Left Feet"
	desc = "A mutation that replaces the right foot with another left foot. It makes standing up after getting knocked down very difficult."
	quality = NEGATIVE
	text_gain_indication = "<span class='warning'>Ваша правая нога стала ощущаться как... левая?</span>"
	text_lose_indication = "<span class'notice'>Ваша правая нога снова стала правой.</span>"
	difficulty = 16
	var/stun_cooldown = 0

/datum/mutation/human/extrastun/on_life()
	if(world.time > stun_cooldown)
		if(owner.AmountKnockdown() || owner.AmountStun())
			owner.SetKnockdown(owner.AmountKnockdown()*2)
			owner.SetStun(owner.AmountStun()*2)
			owner.visible_message("<span class='danger'>[owner] пытается встать, но спотыкается!</span>", "<span class='userdanger'>Вы спотыкаетесь о собственную ногу!</span>")
			stun_cooldown = world.time + 300
