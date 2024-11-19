/obj/item/wirecutters
	name = "wirecutters"
	desc = "Инструмент для перерезания различных материалов."
	ru_names = list(
		NOMINATIVE = "кусачки",
		GENITIVE = "кусачек",
		DATIVE = "кусачкам",
		ACCUSATIVE = "кусачки",
		INSTRUMENTAL = "кусачками",
		PREPOSITIONAL = "кусачках"
	)
	icon = 'icons/obj/tools.dmi'
	icon_state = "cutters"
	belt_icon = "wirecutters"
	flags = CONDUCT
	slot_flags = ITEM_SLOT_BELT
	force = 6
	throw_speed = 3
	throw_range = 7
	w_class = WEIGHT_CLASS_SMALL
	materials = list(MAT_METAL=80)
	origin_tech = "materials=1;engineering=1"
	attack_verb = list("pinched", "nipped")
	hitsound = 'sound/items/wirecutter.ogg'
	usesound = 'sound/items/wirecutter.ogg'
	drop_sound = 'sound/items/handling/wirecutter_drop.ogg'
	pickup_sound =  'sound/items/handling/wirecutter_pickup.ogg'
	sharp = 1
	embed_chance = 5
	embedded_ignore_throwspeed_threshold = TRUE
	toolspeed = 1
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 50, "acid" = 30)
	tool_behaviour = TOOL_WIRECUTTER
	var/random_color = TRUE

/obj/item/wirecutters/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/falling_hazard, damage = force, hardhat_safety = TRUE, crushes = FALSE, impact_sound = hitsound)

/obj/item/wirecutters/New(loc, param_color = null)
	..()
	if(random_color)
		if(!param_color)
			param_color = pick("yellow", "red")
		icon_state = "cutters_[param_color]"


/obj/item/wirecutters/attack(mob/living/carbon/target, mob/living/user, params, def_zone, skip_attack_anim = FALSE)
	if(istype(target) && istype(target.handcuffed, /obj/item/restraints/handcuffs/cable))
		var/obj/item/cuffs = target.handcuffed
		user.visible_message(
			span_notice("[user] перерезает стяжки [target]'s с помощью [declent_ru(GENITIVE)]!"),
			span_notice("Ты перерезал стяжки [target]'s с помощью [declent_ru(GENITIVE)]!"),
		)
		play_tool_sound(target, 100)
		target.temporarily_remove_item_from_inventory(cuffs, force = TRUE)
		qdel(cuffs)
		return ATTACK_CHAIN_PROCEED_SUCCESS
	return ..()


/obj/item/wirecutters/suicide_act(mob/user)
	user.visible_message(span_suicide("[user] перереза[pluralize_ru(user.gender, "ет", "ют")] свои артерии с помощью [declent_ru(GENITIVE)]! Кажется, [genderize_ru(user.gender, "он", "она", "оно", "они")] пыта[pluralize_ru(user.gender, "ет", "ют")]ся совершить самоубийство!"))
	playsound(loc, usesound, 50, 1, -1)
	return BRUTELOSS

/obj/item/wirecutters/brass
	name = "brass wirecutters"
	desc = "Пара кусачек из латуни. Ручка на ощупь ледяная."
	ru_names = (
		NOMINATIVE = "латунные кучаски",
		GENITIVE = "латунных кусачек",
		DATIVE = "латунным кучаскам",
		ACCUSATIVE = "латунные кусачки",
		INSTRUMENTAL = "латунными кусачками",
		PREPOSITIONAL = "латунных кусачках"
	)
	icon_state = "cutters_brass"
	toolspeed = 0.5
	random_color = FALSE
	resistance_flags = FIRE_PROOF | ACID_PROOF

/obj/item/wirecutters/abductor
	name = "alien wirecutters"
	desc = "Очень острые кусачки, изготовленные из серебристо-зеленого металла."
	ru_names = (
		NOMINATIVE = "инопланетные кусачки",
		GENITIVE = "инопланетных кусачек",
		DATIVE = "инопланетным кусачкам",
		ACCUSATIVE = "инопланетные кусачки",
		INSTRUMENTAL = "инпланетными кусачками",
		PREPOSITIONAL = "инопланетных кусачках"
	)
	icon = 'icons/obj/abductor.dmi'
	icon_state = "cutters"
	item_state = "alien_cutters"
	belt_icon = "alien_wirecutters"
	toolspeed = 0.1
	origin_tech = "materials=5;engineering=4;abductor=3"
	random_color = FALSE

/obj/item/wirecutters/cyborg
	name = "wirecutters"
	desc = "Инструмент для перерезания различных материалов."
	ru_names = list(
		NOMINATIVE = "кусачки",
		GENITIVE = "кусачек",
		DATIVE = "кусачкам",
		ACCUSATIVE = "кусачки",
		INSTRUMENTAL = "кусачками",
		PREPOSITIONAL = "кусачках"
	)
	toolspeed = 0.5

/obj/item/wirecutters/power
	name = "jaws of life"
	desc = "Набор челюстей жизни, магия науки сумела втиснуть его в устройство, достаточно маленькое, чтобы поместиться на поясе для инструментов. Он оснащен режущей головкой."
	ru_names = list(
		NOMINATIVE = "челюсти жизни",
		GENITIVE = "челюстей жизни",
		DATIVE = "челюстям жизни",
		ACCUSATIVE = "челюсти жизни",
		INSTRUMENTAL = "челюстями жизни",
		PREPOSITIONAL = "челюстях жизни"
	)
	icon_state = "jaws_cutter"
	item_state = "jawsoflife"
	belt_icon = "jaws_of_life"
	origin_tech = "materials=2;engineering=2"
	materials = list(MAT_METAL=150,MAT_SILVER=50,MAT_TITANIUM=25)
	usesound = 'sound/items/jaws_cut.ogg'
	toolspeed = 0.25
	random_color = FALSE


/obj/item/wirecutters/power/suicide_act(mob/user)
	user.visible_message(span_suicide("[user] обёртывает [declent_ru(NOMINATIVE)] вокруг своей шеи. Кажется, [genderize_ru(user.gender, "он", "она", "оно", "они")] пыта[pluralize_ru(user.gender, "ет", "ют")]ся оторвать свою голову!"))
	playsound(loc, 'sound/items/jaws_cut.ogg', 50, 1, -1)
	if(ishuman(user))
		var/mob/living/carbon/human/H = user
		var/obj/item/organ/external/head/head = H.bodyparts_by_name[BODY_ZONE_HEAD]
		if(head)
			head.droplimb(0, DROPLIMB_BLUNT, FALSE, TRUE)
			playsound(loc,"desceration" ,50, 1, -1)
	return BRUTELOSS

/obj/item/wirecutters/power/attack_self(mob/user)
	playsound(get_turf(user), 'sound/items/change_jaws.ogg', 50, 1)
	var/obj/item/crowbar/power/pryjaws = new /obj/item/crowbar/power
	to_chat(user, span_notice("Ты присоеденяешь поддевающую головку к [declent_ru(DATIVE)]."))
	qdel(src)
	user.put_in_active_hand(pryjaws)
