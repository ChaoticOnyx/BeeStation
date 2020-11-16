/obj/item/music_tape
	name = "tape"
	desc = "And let the music sound!"
	icon = 'icons/obj/device.dmi'
	icon_state = "tape_white"
	w_class = WEIGHT_CLASS_TINY
	var/track = null
	var/random_color = TRUE

/obj/item/music_tape/Initialize()
	. = ..()
	if(random_color)
		icon_state = "tape_[pick("white", "blue", "red", "yellow", "purple")]"

/obj/item/music_tape/custom
	name = "new tape"
	desc = "Music has not yet been recorded. It seems that it's time for you to decide the fate of this tape!"

/obj/item/music_tape/custom/attack_self(mob/user)
	var/new_sound = input(user, "Выберите файл для загрузки. Вы можете загрузить mp3, ogg и другие аудиоформаты, поддерживаемые Бьёндом.", "Выбор песни для загрузки") as null|sound
	if(isnull(new_sound))
		return

	var/new_name = input(user, "Выберите название для кассеты:", "Выбор названия", "Без названия") as null|text
	if(isnull(new_name))
		return
	new_name = sanitize(new_name)
	name = "tape \"[new_name]\""

	var/new_length = input(user, "Укажите, сколько секунд длится ваша песня. Ваша песня будет играть именно столько, сколько секунд вы указали:", "Указание длины песни", "0") as null|text
	if(isnull(new_length))
		return
	new_length = text2num(new_length) * 10

	var/new_song_beat = input(user, "Укажите бит вашей песни:", "Указание бита", "0") as null|text
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
		return