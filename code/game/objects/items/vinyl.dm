/obj/item/vinyl
	name = "vinyl"
	desc = "And let the music sound!"
	icon = 'icons/Crimson Dragon/vinyl.dmi'
	icon_state = "vinyl"
	w_class = WEIGHT_CLASS_TINY
	var/track = null
	var/random_color = TRUE
	var/picked_color = COLOR_WHITE

/obj/item/vinyl/Initialize()
	. = ..()
	if(random_color)
		picked_color = pick(COLOR_RED_LIGHT, COLOR_MAROON, COLOR_YELLOW, COLOR_OLIVE, COLOR_GREEN, COLOR_MAGENTA, COLOR_PURPLE, COLOR_ORANGE, COLOR_BLUE_LIGHT, COLOR_BROWN)
		if(prob(5))
			icon_state = "vinyl_broken"
			var/image/I = image('icons/Crimson Dragon/vinyl.dmi', "vinyl_broken_colored")
			I.color = picked_color
			overlays += I
		else
			var/image/I = image('icons/Crimson Dragon/vinyl.dmi', "vinyl_colored")
			I.color = picked_color
			overlays += I

/obj/item/vinyl/custom
	name = "new vinyl"
	desc = "Music has not yet been recorded. It seems that it's time for you to decide the fate of this vinyl!"

/obj/item/vinyl/custom/Initialize()
	. = ..()
	if(random_color)
		icon_state = "vinyl_new_closed"
		var/image/I = image('icons/Crimson Dragon/vinyl.dmi', "vinyl_new_closed_colored")
		I.color = picked_color
		overlays += I

/obj/item/vinyl/custom/attack_self(mob/user)
	if(track)
		return
	var/new_sound = input(user, "Выберите файл для загрузки. Вы можете загрузить mp3, ogg и другие аудиоформаты, поддерживаемые Бьёндом.", "Выбор песни для загрузки") as null|sound
	if(isnull(new_sound))
		return

	var/new_name = input(user, "Выберите название для пластинки:", "Выбор названия", "Без названия") as null|text
	if(isnull(new_name))
		return
	new_name = sanitize(new_name)
	name = "vinyl \"[new_name]\""

	var/new_length = input(user, "Укажите, сколько секунд длится ваша песня. Ваша песня будет играть именно столько, сколько секунд вы указали:", "Указание длины песни", "0") as null|text
	if(isnull(new_length))
		return
	new_length = text2num(new_length) * 10

	var/new_song_beat = input(user, "Укажите бит вашей песни:", "Указание бита", "5") as null|text
	if(isnull(new_song_beat))
		return
	new_song_beat = text2num(new_song_beat)

	if(new_sound && new_name && new_length && new_song_beat && !track)
		var/datum/track/T = new()
		T.song_path = new_sound
		T.song_name = new_name
		T.song_length = new_length
		T.song_beat = new_song_beat
		track = T
		icon_state = "vinyl_new_open"
		var/image/I = image('icons/Crimson Dragon/vinyl.dmi', "vinyl_new_open_colored")
		I.color = picked_color
		overlays = null
		overlays += I
		return