///AI Upgrades

//Malf Picker
/obj/item/malf_upgrade
	name = "combat software upgrade"
	desc = "A highly illegal, highly dangerous upgrade for artificial intelligence units, granting them a variety of powers as well as the ability to hack APCs."
	icon = 'icons/obj/module.dmi'
	icon_state = "datadisk3"

/obj/item/malf_upgrade/afterattack(atom/target, mob/user, proximity_flag, list/modifiers, status)
	var/mob/living/silicon/ai/ai_target = target

	if(!istype(ai_target))
		return

	if(ai_target.malf_picker)
		ai_target.malf_picker.processing_time += 50
		to_chat(ai_target, span_userdanger("[user] has attempted to upgrade you with combat software that you already possess. You gain 50 points to spend on Malfunction Modules instead."))
	else
		to_chat(ai_target, span_userdanger("[user] has upgraded you with combat software!"))
		ai_target.add_malf_picker()
	to_chat(user, span_notice("You upgrade [ai_target]. [src] is consumed in the process."))
	qdel(src)

//Lipreading
/obj/item/surveillance_upgrade
	name = "surveillance software upgrade"
	desc = "A software package that will allow an artificial intelligence to 'hear' from its cameras via lip reading."
	icon = 'icons/obj/module.dmi'
	icon_state = "datadisk3"

/obj/item/surveillance_upgrade/afterattack(atom/target, mob/user, proximity_flag, list/modifiers, status)
	var/mob/living/silicon/ai/ai_target = target

	if(!istype(ai_target))
		return

	if(ai_target.eyeobj)
		ai_target.eyeobj.relay_speech = 1
		to_chat(ai_target, span_userdanger("[user] has upgraded you with surveillance software!"))
		to_chat(ai_target, "Via a combination of hidden microphones and lip reading software, you are able to use your cameras to listen in on conversations.")
	to_chat(user, span_notice("You upgrade [ai_target]. [src] is consumed in the process."))
	qdel(src)

/obj/item/ai_upgrade
	name = "parent ai upgrade"
	icon = 'icons/obj/module.dmi'
	icon_state = "datadisk3"
	item_state = "card-id"
	drop_sound = 'sound/items/handling/disk_drop.ogg'
	pickup_sound = 'sound/items/handling/disk_pickup.ogg'
	w_class = WEIGHT_CLASS_TINY

/obj/item/ai_upgrade/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(isAI(interacting_with))
		ai_upgrade_action(interacting_with, user)
		return ITEM_INTERACT_SUCCESS
	return NONE

/obj/item/ai_upgrade/proc/ai_upgrade_action(mob/living/silicon/ai/AI, mob/user)
	return

/obj/item/ai_upgrade/ai_program_reset
	name = "Program Reset Disk"
	desc = "Insert this disk into the AI core to completely reset their programs."

/obj/item/ai_upgrade/ai_program_reset/ai_upgrade_action(mob/living/silicon/ai/AI, mob/user)
	if(!istype(AI))
		return
	to_chat(user, span_notice("You reset [AI]'s program storage to factory settings."))
	AI.reset_programs()

/obj/item/ai_upgrade/expanded_storage
	name = "expanded storage upgrade"
	desc = "An experimental upgrade labelled EX.ST. Within is an algorithm to compress an AI's processes, granting them spare memory."

/obj/item/ai_upgrade/expanded_storage/ai_upgrade_action(mob/living/silicon/ai/AI, mob/user)
	if(!istype(AI))
		return
	to_chat(AI, span_notice("[user] has upgraded you an expanded storage module. Extra memory granted!"))
	AI.program_picker.total_memory += 2
	AI.program_picker.memory += 2
	to_chat(user, span_notice("You upgrade [AI]. [src] is consumed in the process."))
	qdel(src)

/obj/item/ai_upgrade/expanded_network
	name = "expanded network array upgrade"
	desc = "An experimental upgrade labelled EX.AR. Within is an algorithm to optimize an AI's network, granting them spare bandwidth."

/obj/item/ai_upgrade/expanded_network/ai_upgrade_action(mob/living/silicon/ai/AI, mob/user)
	if(!istype(AI))
		return
	to_chat(AI, span_notice("[user] has upgraded you an expanded network array module. Extra bandwidth granted!"))
	AI.program_picker.total_bandwidth += 1
	AI.program_picker.bandwidth += 1
	to_chat(user, span_notice("You upgrade [AI]. [src] is consumed in the process."))
	qdel(src)

/obj/item/ai_upgrade/expanded_tank
	name = "expanded nanite tank upgrade"
	desc = "An experimental upgrade labelled NA.TA. Within is a bluespace compacting program to make an AI's nanite reserves just a bit bigger."

/obj/item/ai_upgrade/expanded_tank/ai_upgrade_action(mob/living/silicon/ai/AI, mob/user)
	if(!istype(AI))
		return
	to_chat(AI, span_notice("[user] has upgraded you an expanded nanite tank module. Extra nanite storage capacity granted!"))
	AI.program_picker.max_nanites += 10
	to_chat(user, span_notice("You upgrade [AI]. [src] is consumed in the process."))
	qdel(src)

/obj/item/ai_upgrade/expanded_fabricator
	name = "expanded nanite fabricator upgrade"
	desc = "An experimental upgrade labelled NA.FA. Within is a program to compress the fabricators of an AI's nanites, allowing them to construct them quicker."

/obj/item/ai_upgrade/expanded_fabricator/ai_upgrade_action(mob/living/silicon/ai/AI, mob/user)
	if(!istype(AI))
		return
	to_chat(AI, span_notice("[user] has upgraded you an expanded nanite fabricator module. Extra nanite regeneration granted!"))
	AI.nanite_regen += 0.5
	to_chat(user, span_notice("You upgrade [AI]. [src] is consumed in the process."))
	qdel(src)
