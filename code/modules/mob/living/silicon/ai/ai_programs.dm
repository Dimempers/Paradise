/datum/program_picker
	var/mob/living/silicon/ai/assigned_ai
	var/list/possible_programs
	var/memory = 3
	var/total_memory = 3
	var/bandwidth = 1
	var/total_bandwidth = 1
	var/nanites = 50
	var/max_nanites = 100
	var/temp

/datum/program_picker/New(mob/living/silicon/ai/A)
	if(!istype(A))
		return
	assigned_ai = A
	possible_programs = list()
	for(var/type in subtypesof(/datum/ai_program))
		var/datum/ai_program/program = new type
		if(program.power_type || program.upgrade)
			possible_programs += program

/datum/program_picker/Destroy(force)
	assigned_ai = null
	QDEL_LIST(possible_programs)
	return ..()

/datum/program_picker/proc/modify_resource(key, amount)
	switch(key)
		if("memory")
			memory += amount
			total_memory += amount
			if(memory < 0)
				refund_purchases()
		if("bandwidth")
			bandwidth += amount
			total_bandwidth += amount
			if(bandwidth < 0)
				refund_upgrades()

/datum/program_picker/proc/get_installed_programs()
	var/list/installed_programs = list()
	for(var/datum/ai_program/program in possible_programs)
		if(program.installed)
			installed_programs += program
	return installed_programs

/datum/program_picker/proc/refund_purchases()
	var/list/potential_losses = get_installed_programs()
	while(memory < 0)
		if(!length(potential_losses))
			return
		var/datum/ai_program/program = pick_n_take(potential_losses)
		program.uninstall(assigned_ai)

/datum/program_picker/proc/refund_upgrades()
	var/list/potential_losses = get_installed_programs()
	while(bandwidth < 0)
		if(!length(potential_losses))
			return
		var/datum/ai_program/program = pick_n_take(potential_losses)
		if(!program.upgrade_level)
			continue
		while(program.upgrade_level > 0 && bandwidth < 0)
			program.downgrade(assigned_ai)

/datum/program_picker/proc/reset_programs()
	var/list/programs = get_installed_programs()
	for(var/datum/ai_program/program in programs)
		program.uninstall(assigned_ai)

/datum/program_picker/ui_host(mob/user)
	return assigned_ai ? assigned_ai : src

/datum/program_picker/proc/spend_nanites(amount)
	if(nanites - amount < 0)
		return FALSE
	nanites -= amount
	return TRUE

/datum/program_picker/proc/refund_nanites(amount)
	nanites = min(max_nanites, nanites + amount)

/datum/program_picker/ui_interact(mob/user, datum/tgui/ui = null)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AIProgramPicker", "AI Program Menu")
		ui.open()

/datum/program_picker/ui_data(mob/user)
	var/list/data = list()
	data["program_list"] = list()
	for(var/datum/ai_program/program in possible_programs)
		var/list/program_data = list(
			"name" = program.program_name,
			"UID" = program.UID(),
			"description" = program.description,
			"memory_cost" = program.cost,
			"installed" = program.installed,
			"upgrade_level" = program.upgrade_level,
			"is_passive" = program.upgrade
		)
		data["program_list"] += list(program_data)
	data["ai_info"] = list(
		"memory" = memory,
		"bandwidth" = bandwidth
	)
	return data

/datum/program_picker/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	. = FALSE

	if(!isAI(ui.user))
		return
	var/mob/living/silicon/ai/A = ui.user
	if(A.stat == DEAD)
		to_chat(A, span_warning("You are dead!"))
		return

	switch(action)
		if("select")
			var/datum/ai_program/program = locateUID(params["uid"])
			if(!istype(program) || !(program in possible_programs))
				return FALSE
			if(!program.installed)
				if(program.cost > memory)
					to_chat(A, span_warning("You cannot afford this program."))
					return FALSE
				memory -= program.cost
				program.installed = TRUE
				SSblackbox.record_feedback("tally", "ai_program_install", 1, "[program.type]")

			if(!program.upgrade)
				var/datum/action/cooldown/ai_program/selected_program = locate(program.power_type) in A.actions
				if(selected_program)
					if(selected_program.spell_level >= selected_program.level_max)
						to_chat(A, span_warning("This program cannot be upgraded further."))
						return FALSE
					if(bandwidth < 1)
						to_chat(A, span_warning("You cannot afford this upgrade!"))
						return FALSE
					selected_program.spell_level++
					if(selected_program.spell_level >= selected_program.level_max)
						to_chat(A, span_notice("This program cannot be upgraded any further."))
					selected_program.on_purchase_upgrade()
					program.upgrade(A)
					return TRUE

				var/datum/action/cooldown/ai_program/new_spell = new program.power_type(A)
				new_spell.program = program
				new_spell.desc_update()
				program.upgrade(A, first_install = TRUE)
				new_spell.Grant(A)
				to_chat(A, program.unlock_text)
				A.playsound_local(A, program.unlock_sound, 50, FALSE, use_reverb = FALSE)
				return TRUE

			if(program.upgrade_level > program.max_level)
				to_chat(A, span_notice("This program cannot be upgraded any further."))
				return FALSE
			if(!program.upgrade_level)
				program.upgrade(A, first_install = TRUE)
			else
				if(bandwidth < 1)
					to_chat(A, span_warning("You cannot afford this upgrade!"))
					return FALSE
				program.upgrade(A)
			to_chat(A, program.unlock_text)
			A.playsound_local(A, program.unlock_sound, 50, FALSE, use_reverb = FALSE)
			return TRUE

/datum/ai_program
	var/program_name
	var/description = ""
	var/program_id
	var/cost = 1
	var/nanite_cost = 0
	var/bandwidth_used = 0
	var/power_type = /datum/action/cooldown/ai_program
	var/upgrade = FALSE
	var/upgrade_level = 0
	var/max_level = 5
	var/unlock_text = span_notice_alt("Hello World!")
	var/unlock_sound
	var/cooldown = 30 SECONDS
	var/installed = FALSE
	var/external = FALSE

/datum/ai_program/New()
	. = ..()
	if(nanite_cost)
		description += " Costs [nanite_cost] Nanites to use."

/datum/ai_program/proc/upgrade(mob/living/silicon/ai/user, first_install = FALSE)
	if(!istype(user))
		return
	upgrade_level++
	if(!first_install)
		SSblackbox.record_feedback("tally", "ai_program_upgrade", 1, "[src.type]")
		bandwidth_used++
		user.program_picker.bandwidth--

/datum/ai_program/proc/downgrade(mob/living/silicon/ai/user)
	if(!istype(user))
		return
	upgrade_level--
	if(upgrade_level <= 0)
		uninstall(user)
		return
	to_chat(user, span_warning("Program update data lost: [src.program_name]!"))
	bandwidth_used--
	user.program_picker.bandwidth++
	if(!upgrade)
		var/datum/action/cooldown/ai_program/aspell = locate(power_type) in user.actions
		if(aspell)
			aspell.spell_level--
			aspell.on_purchase_upgrade()

/datum/ai_program/proc/uninstall(mob/living/silicon/ai/user)
	upgrade_level = 0
	installed = FALSE
	if(!istype(user))
		return
	user.program_picker.bandwidth += bandwidth_used
	bandwidth_used = 0
	user.program_picker.memory += cost
	to_chat(user, span_userdanger("Program core data lost: [src.program_name]!"))
	if(!upgrade)
		var/datum/action/cooldown/ai_program/aspell = locate(power_type) in user.actions
		qdel(aspell)

/datum/action/innate/ai/choose_program
	name = "Choose Programs"
	desc = "Spend your memory and bandwidth to gain a variety of different abilities."
	button_icon = 'icons/mob/ai.dmi'
	button_icon_state = "ai"
	auto_use_uses = FALSE

/datum/action/innate/ai/choose_program/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return
	if(isapc(owner_AI.loc))
		to_chat(owner_AI, span_warning("Error: APCs do not have enough processing power to handle programs!"))
		return
	if(istype(owner_AI.loc, /obj/item/aicard))
		to_chat(owner_AI, span_warning("Error: InteliCards do not have enough processing power to handle programs!"))
		return
	owner_AI.program_picker.ui_interact(owner_AI)

/datum/action/cooldown/ai_program
	name = "AI Program"
	desc = "You aren't entirely sure what this does, but it's very beepy and boopy."
	background_icon_state = "bg_tech_blue"
	check_flags = AB_CHECK_CONSCIOUS
	var/datum/ai_program/program
	var/spell_level = 0
	var/level_max = 4
	var/cooldown_min = 0
	var/selection_activated_message
	var/selection_deactivated_message

/datum/action/cooldown/ai_program/Destroy()
	program = null
	return ..()

/datum/action/cooldown/ai_program/Activate(atom/target)
	StartCooldown()
	cast(target, owner)
	return TRUE

/datum/action/cooldown/ai_program/proc/cast(atom/target, mob/living/silicon/ai/user)
	return

/datum/action/cooldown/ai_program/proc/revert_cast()
	ResetCooldown()

/datum/action/cooldown/ai_program/proc/on_purchase_upgrade()
	return

/datum/action/cooldown/ai_program/proc/set_recharge_duration(new_duration)
	cooldown_time = new_duration
	if(next_use_time > world.time)
		StartCooldown()

/datum/action/cooldown/ai_program/proc/find_nearest_camera(atom/target)
	var/area/A = get_area(target)
	if(!istype(A))
		return
	var/closest_camera = null
	for(var/obj/machinery/camera/C in A)
		if(isnull(closest_camera))
			closest_camera = C
			continue
		if(get_dist(closest_camera, target) > get_dist(C, target))
			closest_camera = C
			continue
	return closest_camera

/datum/action/cooldown/ai_program/proc/desc_update()
	desc = initial(desc)
	if(program)
		desc += " Costs [program.nanite_cost] Nanites to use."
	build_all_button_icons(UPDATE_BUTTON_NAME)

/datum/action/cooldown/ai_program/proc/camera_beam(target, icon_state, icon, time)
	var/obj/machinery/camera/C = find_nearest_camera(target)
	if(!istype(C))
		return
	C.Beam(target, icon_state = icon_state, icon = icon, time = time)

/datum/action/cooldown/ai_program/proc/check_camera_vision(mob/user, atom/target)
	var/turf/target_turf = get_turf(target)
	if(!GLOB.cameranet.checkTurfVis(target_turf))
		to_chat(user, span_warning("You don't have camera vision of this location!"))
		return FALSE
	return TRUE

/datum/action/cooldown/ai_program/ranged
	name = "Ranged AI Action"
	click_to_activate = TRUE
	ranged_mousepointer = 'icons/effects/mouse_pointers/mecha_mouse.dmi'
	selection_activated_message = span_notice_alt("Hello World!")
	selection_deactivated_message = span_danger_alt("Goodbye Cruel World!")

/datum/action/cooldown/ai_program/ranged/set_click_ability(mob/on_who)
	. = ..()
	to_chat(on_who, selection_activated_message)

/datum/action/cooldown/ai_program/ranged/unset_click_ability(mob/on_who, refund_cooldown = TRUE)
	. = ..()
	if(refund_cooldown)
		to_chat(on_who, selection_deactivated_message)

/datum/ai_program/rgb_lighting
	program_name = "RGB Lighting"
	program_id = "rgb_lighting"
	description = "Recolor a light to a desired color. At significantly high efficiency, it can change the color of an entire room's lighting by targeting the APC."
	nanite_cost = 5
	power_type = /datum/action/cooldown/ai_program/ranged/rgb_lighting
	unlock_text = "RGB Lighting installation complete!"

/datum/action/cooldown/ai_program/ranged/rgb_lighting
	name = "RGB Lighting"
	desc = "Changes the color of a selected light."
	button_icon = 'icons/effects/random_spawners.dmi'
	button_icon_state = "glowstick"
	cooldown_time = 30 SECONDS
	cooldown_min = 5 SECONDS
	level_max = 5
	selection_activated_message = span_notice_alt("You hook into the station's lighting controller...")
	selection_deactivated_message = span_notice_alt("You cancel the request from the lighting controller.")

/datum/action/cooldown/ai_program/ranged/rgb_lighting/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	if(!check_camera_vision(user, target))
		revert_cast()
		return
	if(!istype(target, /obj/machinery/light) && !isapc(target))
		to_chat(user, span_warning("You can only recolor lights!"))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	var/color_picked = tgui_input_color(user, "Please select a light color.", "RGB Lighting Color")
	if(!color_picked)
		user.program_picker.refund_nanites(program.nanite_cost)
		revert_cast()
		return
	var/list/picked_rgb = rgb2num(color_picked)
	var/list/hsl = rgb2hsl(picked_rgb[1], picked_rgb[2], picked_rgb[3])
	hsl[3] = max(hsl[3], 0.4)
	var/list/rgb = hsl2rgb(arglist(hsl))
	var/new_color = rgb(rgb[1], rgb[2], rgb[3])
	if(isapc(target))
		if(spell_level < 3)
			to_chat(user, span_warning("Your coloring subsystem is not strong enough to target an entire room!"))
			user.program_picker.refund_nanites(program.nanite_cost)
			revert_cast()
			return
		var/obj/machinery/power/apc/A = target
		for(var/obj/machinery/light/L in A.area)
			L.color = new_color
			L.brightness_color = new_color
			L.update(TRUE, TRUE)
	else
		var/obj/machinery/light/L = target
		L.color = new_color
		L.brightness_color = new_color
		L.update(TRUE, TRUE)
	user.play_sound_remote(target, 'sound/effects/spray.ogg', 50)
	camera_beam(target, "rped_upgrade", 'icons/effects/effects.dmi', 5)

/datum/action/cooldown/ai_program/ranged/rgb_lighting/on_purchase_upgrade()
	set_recharge_duration(max(initial(cooldown_time) - (spell_level * 5 SECONDS), cooldown_min))

/datum/ai_program/power_shunt
	program_name = "Power Shunt"
	program_id = "power_shunt"
	description = "Recharge an APC, Borg, or Mech with power directly from your SMES!"
	nanite_cost = 20
	power_type = /datum/action/cooldown/ai_program/ranged/power_shunt
	unlock_text = "Power Shunt installation complete!"

/datum/action/cooldown/ai_program/ranged/power_shunt
	name = "Power Shunt"
	desc = "Recharge an APC, Borg, or Mech with power directly from your SMES."
	button_icon = 'icons/obj/engines_and_power/power.dmi'
	button_icon_state = "smes-o"
	cooldown_time = 120 SECONDS
	cooldown_min = 30 SECONDS
	level_max = 7
	selection_activated_message = span_notice_alt("You tap into the station's powernet...")
	selection_deactivated_message = span_notice_alt("You release your hold on the powernet.")
	var/power_sent = 2500

/datum/action/cooldown/ai_program/ranged/power_shunt/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	if(!check_camera_vision(user, target))
		revert_cast()
		return
	if(!isrobot(target) && !isapc(target) && !ismecha(target) && !ismachineperson(target))
		to_chat(user, span_warning("You can only recharge borgs, mechs, and APCs!"))
		revert_cast()
		return
	if(ismachineperson(target) && !user.universal_adapter)
		to_chat(user, span_warning("This software lacks the required upgrade to recharge IPCs!"))
		revert_cast()
		return
	var/area/A = get_area(user)
	if(isnull(A))
		to_chat(user, span_warning("No SMES detected to power from!"))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	if(ismecha(target))
		var/obj/mecha/T = target
		T.cell?.give(power_sent)
	if(isrobot(target))
		var/mob/living/silicon/robot/T = target
		T.cell?.give(power_sent)
	if(isapc(target))
		var/obj/machinery/power/apc/T = target
		T.cell?.give(power_sent)
	if(ismachineperson(target))
		var/mob/living/carbon/human/T = target
		T.adjust_nutrition(clamp(user.adapter_efficiency * (power_sent / 10), 0, (NUTRITION_LEVEL_FULL - T.nutrition)))

	for(var/obj/machinery/power/smes/power_source in A)
		if(power_source.charge < power_sent)
			continue
		power_source.charge -= power_sent
		break
	user.play_sound_remote(target, 'sound/goonstation/misc/fuse.ogg', 50)
	camera_beam(target, "rped_upgrade", 'icons/effects/effects.dmi', 5)

/datum/action/cooldown/ai_program/ranged/power_shunt/on_purchase_upgrade()
	power_sent = min(10000, 2500 + (spell_level * 2500))
	set_recharge_duration(max(initial(cooldown_time) - (max(spell_level - 3, 0) * 30 SECONDS), cooldown_min))

/datum/ai_program/repair_nanites
	program_name = "Repair Nanites"
	program_id = "repair_nanites"
	description = "Repair an APC, Borg, or Mech with large numbers of robotic nanomachines!"
	cost = 2
	nanite_cost = 75
	power_type = /datum/action/cooldown/ai_program/ranged/repair_nanites
	unlock_text = "Repair nanomachine firmware installation complete!"

/datum/action/cooldown/ai_program/ranged/repair_nanites
	name = "Repair Nanites"
	desc = "Repair an APC, Borg, or Mech with large numbers of robotic nanomachines!"
	button_icon = 'icons/obj/surgery.dmi'
	button_icon_state = "tube"
	cooldown_time = 150 SECONDS
	cooldown_min = 30 SECONDS
	level_max = 7
	selection_activated_message = span_notice_alt("You prepare to order your nanomachines to repair...")
	selection_deactivated_message = span_notice_alt("You rescind the order.")

/datum/action/cooldown/ai_program/ranged/repair_nanites/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	if(!check_camera_vision(user, target))
		revert_cast()
		return
	if(!isrobot(target) && !isapc(target) && !ismecha(target) && !ismachineperson(target) && !isbot(target))
		to_chat(user, span_warning("You can only repair borgs, mechs, and APCs!"))
		revert_cast()
		return
	if(ismachineperson(target) && !user.universal_adapter)
		to_chat(user, span_warning("This software lacks the required upgrade to repair IPCs!"))
		revert_cast()
		return
	if(isbot(target) && spell_level < 2)
		to_chat(user, span_warning("This software is not upgraded enough to repair the robot!"))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	if(ismecha(target) || isapc(target))
		var/obj/T = target
		T.obj_integrity = min(T.max_integrity, T.obj_integrity + (T.max_integrity * (0.2 + min(0.3, (0.1 * spell_level)))))
	if(isrobot(target) || isbot(target))
		var/mob/living/T = target
		var/damage_healed = 20 + (min(30, (10 * spell_level)))
		T.heal_overall_damage(damage_healed, damage_healed)
	if(ismachineperson(target))
		var/mob/living/carbon/human/T = target
		var/damage_healed = user.adapter_efficiency * (20 + (min(30, (10 * spell_level))))
		T.heal_overall_damage(damage_healed, damage_healed, TRUE, FALSE, TRUE)
	user.play_sound_remote(target, 'sound/goonstation/misc/fuse.ogg', 50)
	camera_beam(target, "medbeam", 'icons/effects/beam.dmi', 10)

/datum/action/cooldown/ai_program/ranged/repair_nanites/on_purchase_upgrade()
	set_recharge_duration(max(initial(cooldown_time) - (max(spell_level - 3, 0) * 30 SECONDS), cooldown_min))

/datum/ai_program/universal_adapter
	program_name = "Universal Adapter"
	program_id = "universal_adapter"
	description = "Upgraded firmware allows IPCs to be valid targets for Power Shunt and Repair Nanites, at half efficiency."
	unlock_text = "Universal adapter installation complete!"
	upgrade = TRUE

/datum/ai_program/universal_adapter/upgrade(mob/living/silicon/ai/user, first_install = FALSE)
	..()
	if(!istype(user))
		return
	user.universal_adapter = TRUE
	user.adapter_efficiency = 0.5 + (0.1 * upgrade_level)
	installed = TRUE

/datum/ai_program/universal_adapter/downgrade(mob/living/silicon/ai/user)
	..()
	if(!istype(user))
		return
	user.adapter_efficiency = 0.5 + (0.1 * upgrade_level)

/datum/ai_program/universal_adapter/uninstall(mob/living/silicon/ai/user)
	..()
	if(!istype(user))
		return
	user.adapter_efficiency = 0.5
	user.universal_adapter = FALSE

/datum/ai_program/airlock_restoration
	program_name = "Airlock Restoration"
	program_id = "airlock_restoration"
	description = "Repair an airlock's wires, if the AI control wire is not cut."
	cost = 2
	nanite_cost = 25
	power_type = /datum/action/cooldown/ai_program/ranged/airlock_restoration
	unlock_text = "Door repair and override firmware installation complete!"

/datum/action/cooldown/ai_program/ranged/airlock_restoration
	name = "Airlock Restoration"
	desc = "Repair the wires in an airlock that still has an intact AI control wire."
	button_icon = 'icons/obj/doors/doorint.dmi'
	button_icon_state = "door_closed"
	cooldown_time = 60 SECONDS
	cooldown_min = 60 SECONDS
	level_max = 5
	selection_activated_message = span_notice_alt("You prepare to deploy repairing nanites to a door...")
	selection_deactivated_message = span_notice_alt("You cancel the request.")

/datum/action/cooldown/ai_program/ranged/airlock_restoration/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	if(!check_camera_vision(user, target))
		revert_cast()
		return
	var/obj/machinery/door/airlock/airlock = target
	if(!istype(airlock))
		to_chat(user, span_warning("You can only repair airlocks!"))
		revert_cast()
		return
	if(airlock.wires.is_cut(WIRE_AI_CONTROL))
		to_chat(user, span_warning("Error: Null Connection to Airlock!"))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	var/turf/T = get_turf(airlock)
	var/duration = (6 - spell_level) SECONDS
	user.playsound_local(user, 'sound/items/deconstruct.ogg', 50, FALSE, use_reverb = FALSE)
	camera_beam(airlock, "rped_upgrade", 'icons/effects/effects.dmi', 5)
	var/obj/effect/temp_visual/rcd_effect/spawning_effect = new(T)
	spawning_effect.duration = duration
	QDEL_IN(spawning_effect, duration)
	if(do_after(user, duration, airlock, DEFAULT_DOAFTER_IGNORE|DA_IGNORE_TARGET_LOC_CHANGE, interaction_key = airlock, max_interact_count = 1))
		airlock.wires.repair()
		playsound(T, 'sound/items/deconstruct.ogg', 100, TRUE)
		if(spell_level >= 5)
			airlock.emagged = FALSE

/datum/action/cooldown/ai_program/ranged/airlock_restoration/on_purchase_upgrade()
	if(spell_level == 5)
		desc += " Firmware version sufficient enough to repair damage caused by a cryptographic sequencer."
		build_all_button_icons(UPDATE_BUTTON_NAME)

/datum/ai_program/extinguishing_system
	program_name = "Automated Extinguishing System"
	program_id = "extinguishing_system"
	description = "Deploy a nanofrost globule to a target to rapidly extinguish plasmafires."
	nanite_cost = 50
	power_type = /datum/action/cooldown/ai_program/ranged/extinguishing_system
	unlock_text = "Nanofrost synthesizer online."

/datum/action/cooldown/ai_program/ranged/extinguishing_system
	name = "Automated Extinguishing System"
	desc = "Deploy a nanofrost globule to a target to rapidly extinguish plasmafires."
	button_icon = 'icons/effects/effects.dmi'
	button_icon_state = "frozen_smoke_capsule"
	cooldown_time = 60 SECONDS
	cooldown_min = 30 SECONDS
	level_max = 3
	selection_activated_message = span_notice_alt("You prepare to synthesize a nanofrost globule...")
	selection_deactivated_message = span_notice_alt("You let the nanofrost dissipate.")

/datum/action/cooldown/ai_program/ranged/extinguishing_system/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	var/turf/target_turf = get_turf(target)
	if(!check_camera_vision(user, target_turf))
		revert_cast()
		return
	if(!isturf(target_turf))
		to_chat(user, span_warning("Invalid location for nanofrost deployment!"))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	var/obj/effect/nanofrost_container/nanofrost = new /obj/effect/nanofrost_container(target_turf)
	log_game("[key_name(user)] used Nanofrost at [get_area(target_turf)] ([target_turf.x], [target_turf.y], [target_turf.z]).")
	user.play_sound_remote(target_turf, 'sound/items/syringeproj.ogg', 40)
	camera_beam(target_turf, "rped_upgrade", 'icons/effects/effects.dmi', 5)
	addtimer(CALLBACK(nanofrost, TYPE_PROC_REF(/obj/effect/nanofrost_container, Smoke)), 5 SECONDS)

/datum/action/cooldown/ai_program/ranged/extinguishing_system/on_purchase_upgrade()
	set_recharge_duration(max(initial(cooldown_time) - (spell_level * 15 SECONDS), cooldown_min))

/datum/ai_program/bluespace_miner
	program_name = "Bluespace Miner Subsystem"
	program_id = "bluespace_miner"
	description = "You link yourself to a miniature bluespace harvester, generating income for the science account at the cost of increasing your core's power needs."
	unlock_text = "Bluespace miner installation complete!"
	upgrade = TRUE

/datum/ai_program/bluespace_miner/upgrade(mob/living/silicon/ai/user, first_install = FALSE)
	..()
	if(!istype(user))
		return
	user.bluespace_miner_rate = 100 + (100 * upgrade_level)
	user.next_payout = 10 MINUTES + world.time
	user.bluespace_miner = TRUE
	installed = TRUE

/datum/ai_program/bluespace_miner/downgrade(mob/living/silicon/ai/user)
	..()
	if(!istype(user))
		return
	user.bluespace_miner_rate = 100 + (100 * upgrade_level)

/datum/ai_program/bluespace_miner/uninstall(mob/living/silicon/ai/user)
	..()
	if(!istype(user))
		return
	user.bluespace_miner_rate = 100
	user.bluespace_miner = FALSE

/datum/ai_program/multimarket_analyser
	program_name = "Multimarket Analysis Subsystem"
	program_id = "multimarket_analyser"
	description = "You connect to a digital marketplace to price-check all orders from the station, ensuring you get the best prices! This reduces the cost of crates in cargo!"
	unlock_text = "Online marketplace detected... connected!"
	max_level = 6
	upgrade = TRUE
	var/original_price_mod

/datum/ai_program/multimarket_analyser/New()
	..()
	original_price_mod = SSshuttle.pack_price_modifier

/datum/ai_program/multimarket_analyser/upgrade(mob/living/silicon/ai/user, first_install = FALSE)
	..()
	SSshuttle.pack_price_modifier = original_price_mod * (0.95 - (0.05 * upgrade_level))
	installed = TRUE

/datum/ai_program/multimarket_analyser/downgrade(mob/living/silicon/ai/user)
	..()
	if(!installed)
		return
	SSshuttle.pack_price_modifier = original_price_mod * (0.95 - (0.05 * upgrade_level))

/datum/ai_program/multimarket_analyser/uninstall(mob/living/silicon/ai/user)
	..()
	SSshuttle.pack_price_modifier = original_price_mod

/datum/ai_program/light_repair
	program_name = "Light Synthesizer"
	program_id = "light_repair"
	description = "Replace damaged or missing lightbulbs."
	nanite_cost = 5
	power_type = /datum/action/cooldown/ai_program/ranged/light_repair
	unlock_text = "Light replacer configuration installed."

/datum/action/cooldown/ai_program/ranged/light_repair
	name = "Light Synthesizer"
	desc = "Replace damaged or missing lightbulbs."
	button_icon = 'icons/obj/janitor.dmi'
	button_icon_state = "lightreplacer0"
	cooldown_time = 30 SECONDS
	cooldown_min = 5 SECONDS
	level_max = 5
	selection_activated_message = span_notice_alt("You prepare to synthesize a lightbulb...")
	selection_deactivated_message = span_notice_alt("You cancel the request.")

/datum/action/cooldown/ai_program/ranged/light_repair/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	var/turf/target_turf = get_turf(target)
	if(!check_camera_vision(user, target_turf))
		revert_cast()
		return
	var/repaired = FALSE
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	for(var/obj/machinery/light/light in target_turf.contents)
		if(light.status == LIGHT_OK)
			continue
		light.status = LIGHT_OK
		light.switchcount = 0
		light.emagged = FALSE
		light.on = light.has_power()
		light.update(TRUE, TRUE)
		user.play_sound_remote(light, 'sound/machines/ding.ogg', 50)
		camera_beam(light, "rped_upgrade", 'icons/effects/effects.dmi', 5)
		repaired = TRUE

	if(!repaired)
		to_chat(user, span_warning("You can only repair lights!"))
		user.program_picker.refund_nanites(program.nanite_cost)
		revert_cast()
		return

/datum/action/cooldown/ai_program/ranged/light_repair/on_purchase_upgrade()
	set_recharge_duration(max(initial(cooldown_time) - (spell_level * 5 SECONDS), cooldown_min))

/datum/ai_program/nanosurgeon_deployment
	program_name = "Nanosurgeon Deployment"
	program_id = "nanosurgeon_deployment"
	description = "Heal a crew member with large numbers of robotic nanomachines!"
	cost = 3
	nanite_cost = 75
	power_type = /datum/action/cooldown/ai_program/ranged/nanosurgeon_deployment
	unlock_text = "Surgical nanomachine firmware installation complete!"

/datum/action/cooldown/ai_program/ranged/nanosurgeon_deployment
	name = "Nanosurgeon Deployment"
	desc = "Heal a crew member with large numbers of robotic nanomachines!"
	button_icon = 'icons/obj/surgery.dmi'
	button_icon_state = "scalpel_laser1_on"
	cooldown_time = 150 SECONDS
	cooldown_min = 30 SECONDS
	level_max = 10
	selection_activated_message = span_notice_alt("You prepare to order your nanomachines to perform organic repairs...")
	selection_deactivated_message = span_notice_alt("You rescind the order.")

/datum/action/cooldown/ai_program/ranged/nanosurgeon_deployment/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	if(!check_camera_vision(user, target))
		revert_cast()
		return
	var/mob/living/carbon/human/patient = target
	if(!istype(patient) || ismachineperson(patient))
		to_chat(user, span_warning("You can only heal organic crew!"))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	user.play_sound_remote(patient, 'sound/magic/magic_block.ogg', 50)
	camera_beam(patient, "medbeam", 'icons/effects/beam.dmi', 5 SECONDS)
	var/allow_moving = FALSE
	if(spell_level == level_max)
		allow_moving = TRUE
		to_chat(patient, span_notice("You feel a flow of healing nanites stream to you from a nearby camera."))
	else
		to_chat(patient, span_notice("You feel a flow of healing nanites stream to you from a nearby camera. Hold still for them to work!"))
	var/doafter_flags = DEFAULT_DOAFTER_IGNORE
	if(allow_moving)
		doafter_flags |= DA_IGNORE_TARGET_LOC_CHANGE
	if(!do_after(user, 5 SECONDS, patient, doafter_flags))
		user.program_picker.refund_nanites(program.nanite_cost)
		revert_cast()
		return
	if(!check_camera_vision(user, patient))
		user.program_picker.refund_nanites(program.nanite_cost)
		revert_cast()
		return
	var/damage_healed = 20 + (min(30, (10 * spell_level)))
	patient.heal_overall_damage(damage_healed, damage_healed)
	if(spell_level >= 5)
		for(var/obj/item/organ/external/limb as anything in patient.bodyparts)
			if(prob(10 * spell_level))
				limb.mend_fracture()
				limb.stop_internal_bleeding()

/datum/action/cooldown/ai_program/ranged/nanosurgeon_deployment/on_purchase_upgrade()
	set_recharge_duration(max(initial(cooldown_time) - (max(spell_level - 3, 0) * 30 SECONDS), cooldown_min))

/datum/ai_program/enhanced_doors
	program_name = "Enhanced Door Controls"
	program_id = "enhanced_doors"
	description = "You enhance the subroutines that let you control doors, speeding up response times!"
	unlock_text = "Doors connected and optimized. You feel right at home."
	upgrade = TRUE
	var/original_door_delay = 3 SECONDS

/datum/ai_program/enhanced_doors/upgrade(mob/living/silicon/ai/user, first_install = FALSE)
	..()
	if(!istype(user))
		return
	user.door_bolt_delay = original_door_delay * (1 - (upgrade_level * 0.1))
	installed = TRUE

/datum/ai_program/enhanced_doors/downgrade(mob/living/silicon/ai/user)
	..()
	user.door_bolt_delay = original_door_delay * (1 - (upgrade_level * 0.1))

/datum/ai_program/enhanced_doors/uninstall(mob/living/silicon/ai/user)
	..()
	user.door_bolt_delay = original_door_delay

/datum/ai_program/research_subsystem
	program_name = "Experimental Research Subsystem"
	program_id = "research_subsystem"
	description = "Put your processors to work spinning centrifuges and studying results. You unlock a new point of research in a random field."
	cost = 5
	max_level = 10
	unlock_text = "Research and Discovery submodule installation complete. Automated information gathering enabled."
	upgrade = TRUE

/datum/ai_program/research_subsystem/upgrade(mob/living/silicon/ai/user, first_install = FALSE)
	..()
	if(!istype(user))
		return
	user.research_level = upgrade_level
	user.research_time = 10 MINUTES - (30 SECONDS * upgrade_level)
	if(first_install)
		user.last_research_time = 10 MINUTES - (30 SECONDS * upgrade_level)
	user.research_subsystem = TRUE
	installed = TRUE

/datum/ai_program/research_subsystem/downgrade(mob/living/silicon/ai/user)
	..()
	if(!istype(user))
		return
	user.research_level = upgrade_level
	user.research_time = 10 MINUTES - (30 SECONDS * upgrade_level)

/datum/ai_program/research_subsystem/uninstall(mob/living/silicon/ai/user)
	..()
	if(!istype(user))
		return
	user.research_time = 10 MINUTES
	user.research_subsystem = FALSE

/datum/ai_program/emergency_sealant
	program_name = "Emergency Sealant"
	program_id = "emergency_sealant"
	description = "Deploy an area of metal foam to rapidly repair and seal hull breaches."
	cost = 2
	nanite_cost = 50
	power_type = /datum/action/cooldown/ai_program/ranged/emergency_sealant
	unlock_text = "Metal foam synthesizer online."

/datum/action/cooldown/ai_program/ranged/emergency_sealant
	name = "Emergency Sealant"
	desc = "Deploy an area of metal foam to rapidly repair and seal hull breaches."
	button_icon = 'icons/obj/structures.dmi'
	button_icon_state = "reinforced"
	cooldown_time = 180 SECONDS
	cooldown_min = 30 SECONDS
	level_max = 5
	selection_activated_message = span_notice_alt("You fill a canister with metal foam...")
	selection_deactivated_message = span_notice_alt("You dissolve the unused canister.")

/datum/action/cooldown/ai_program/ranged/emergency_sealant/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	if(!check_camera_vision(user, target))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	user.play_sound_remote(target, 'sound/effects/bubbles2.ogg', 50)
	new /obj/effect/temp_visual/ai_sealant(get_turf(target))
	addtimer(CALLBACK(src, PROC_REF(do_metal_foam), get_turf(target)), 10 SECONDS)

/datum/action/cooldown/ai_program/ranged/emergency_sealant/proc/do_metal_foam(turf/target)
	camera_beam(target, "rped_upgrade", 'icons/effects/effects.dmi', 15)
	var/datum/effect_system/fluid_spread/foam/metal/foam = new()
	foam.set_up(range = 2, location = target)
	foam.start()

/datum/action/cooldown/ai_program/ranged/emergency_sealant/on_purchase_upgrade()
	set_recharge_duration(max(initial(cooldown_time) - (spell_level * 30 SECONDS), cooldown_min))

/datum/ai_program/holosign_displayer
	program_name = "Holosign Displayer"
	program_id = "holosign_displayer"
	description = "Deploy a holographic sign to alert crewmembers to potential hazards."
	nanite_cost = 10
	power_type = /datum/action/cooldown/ai_program/ranged/holosign_displayer
	unlock_text = "Metal foam synthesizer online."

/datum/action/cooldown/ai_program/ranged/holosign_displayer
	name = "Holosign Displayer"
	desc = "Deploy a holographic sign to alert crewmembers to potential hazards."
	button_icon = 'icons/obj/device.dmi'
	button_icon_state = "signmaker"
	cooldown_time = 30 SECONDS
	cooldown_min = 30 SECONDS
	level_max = 8
	selection_activated_message = span_notice_alt("You spool up your projector...")
	selection_deactivated_message = span_notice_alt("You stop spooling the projector.")
	var/static/list/sign_choices = list(
		"Engineering",
		"Security",
		"Wet Floor"
	)

/datum/action/cooldown/ai_program/ranged/holosign_displayer/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	if(!check_camera_vision(user, target))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	var/sign_id = tgui_input_list(user, "Select a holosign!", "AI", sign_choices)
	if(!sign_id)
		return
	var/sign_type
	switch(sign_id)
		if("Engineering")
			sign_type = /obj/structure/holosign/barrier/engineering
		if("Wet Floor")
			sign_type = /obj/structure/holosign/wetsign
		if("Security")
			sign_type = /obj/structure/holosign/barrier
		else
			revert_cast()
			return
	var/obj/structure/holosign/sign = new sign_type(get_turf(target), src)
	addtimer(CALLBACK(src, PROC_REF(sign_timer_complete), sign), (60 + 30 * spell_level) SECONDS, TIMER_UNIQUE)
	user.play_sound_remote(target, 'sound/machines/click.ogg', 20)
	camera_beam(target, "rped_upgrade", 'icons/effects/effects.dmi', 5)

/datum/action/cooldown/ai_program/ranged/holosign_displayer/proc/sign_timer_complete(obj/structure/holosign/sign)
	if(QDELETED(sign))
		return
	playsound(sign.loc, 'sound/machines/chime.ogg', 20, 1)
	qdel(sign)

/datum/ai_program/honk_subsystem
	program_name = "Honk Subsystem"
	program_id = "honk_subsystem"
	description = "Download a program from Clowns.NT to be able to play bike horn sounds on demand."
	nanite_cost = 5
	power_type = /datum/action/cooldown/ai_program/ranged/honk_subsystem
	unlock_text = "Honker.exe installed."

/datum/action/cooldown/ai_program/ranged/honk_subsystem
	name = "Honk Subsystem"
	desc = "Download a program from Clowns.NT to be able to play bike horn sounds on demand."
	button_icon = 'icons/obj/items.dmi'
	button_icon_state = "bike_horn"
	cooldown_time = 30 SECONDS
	cooldown_min = 15 SECONDS
	level_max = 10
	selection_activated_message = span_notice_alt("You prepare to honk...")
	selection_deactivated_message = span_notice_alt("You reduce the amount of humor in your subsystems.")

/datum/action/cooldown/ai_program/ranged/honk_subsystem/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	if(!check_camera_vision(user, target))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	if(spell_level >= 10)
		user.play_sound_remote(target, 'sound/items/airhorn.ogg', 50)
	else
		user.play_sound_remote(target, 'sound/items/bikehorn.ogg', 50)

/datum/action/cooldown/ai_program/ranged/honk_subsystem/on_purchase_upgrade()
	set_recharge_duration(max(initial(cooldown_time) - (spell_level * 15 SECONDS), cooldown_min))

/datum/ai_program/enhanced_tracker
	program_name = "Enhanced Tracking Subsystem"
	program_id = "enhanced_tracker"
	description = "New camera firmware allows automated alerts when an individual of interest enters camera view."
	cost = 5
	power_type = /datum/action/cooldown/ai_program/enhanced_tracker
	unlock_text = "Tag and track software online."
	max_level = 8

/datum/ai_program/enhanced_tracker/upgrade(mob/living/silicon/ai/user, first_install = FALSE)
	..()
	if(!istype(user))
		return
	user.enhanced_tracking = TRUE
	user.alarms_listend_for |= "Tracking"
	user.enhanced_tracking_delay = initial(user.enhanced_tracking_delay) - (upgrade_level * 1 SECONDS)

/datum/ai_program/enhanced_tracker/downgrade(mob/living/silicon/ai/user)
	..()
	user.enhanced_tracking_delay = initial(user.enhanced_tracking_delay) - (upgrade_level * 1 SECONDS)

/datum/ai_program/enhanced_tracker/uninstall(mob/living/silicon/ai/user)
	..()
	user.enhanced_tracking = FALSE
	user.alarms_listend_for -= "Tracking"
	user.enhanced_tracking_delay = initial(user.enhanced_tracking_delay)

/datum/action/cooldown/ai_program/enhanced_tracker
	name = "Enhanced Tracking Subsystem"
	desc = "Select a target of interest to be alerted to their presence on cameras."
	button_icon = 'icons/obj/items.dmi'
	button_icon_state = "videocam"
	cooldown_time = 10 SECONDS
	cooldown_min = 10 SECONDS
	level_max = 8

/datum/action/cooldown/ai_program/enhanced_tracker/cast(atom/target, mob/living/silicon/ai/user)
	if(!istype(user))
		return
	var/target_name = tgui_input_list(user, "Pick a trackable target...", "AI", user.trackable_mobs())
	if(!target_name)
		user.set_tracked_mob(null)
		return
	user.set_tracked_mob(isnull(user.track.humans[target_name]) ? user.track.others[target_name] : user.track.humans[target_name])

/mob/living/silicon/ai/proc/set_tracked_mob(mob/new_target)
	if(tracked_mob)
		UnregisterSignal(tracked_mob, COMSIG_QDELETING)
	tracked_mob = new_target
	if(tracked_mob)
		RegisterSignal(tracked_mob, COMSIG_QDELETING, PROC_REF(on_tracked_mob_deleted))

/mob/living/silicon/ai/proc/on_tracked_mob_deleted(datum/source)
	SIGNAL_HANDLER
	tracked_mob = null

/mob/living/silicon/ai/proc/raise_tracking_alert(area/A, mob/target)
	var/obj/machinery/camera/closest_camera
	for(var/obj/machinery/camera/C in A)
		if(isnull(closest_camera))
			closest_camera = C
			continue
		if(get_dist(closest_camera, target) > get_dist(C, target))
			closest_camera = C
			continue
	if(!closest_camera)
		return
	closest_camera.visible_message(span_warning("A purple light flashes on [closest_camera]!"))
	if(GLOB.alarm_manager.trigger_alarm("Tracking", A, A.cameras, closest_camera))
		addtimer(CALLBACK(GLOB.alarm_manager, TYPE_PROC_REF(/datum/alarm_manager, cancel_alarm), "Tracking", A, closest_camera), 1 MINUTES)

/mob/living/silicon/ai/proc/reset_tracker_cooldown()
	tracker_alert_cooldown = FALSE

/datum/ai_program/pointer
	program_name = "Holopointer"
	program_id = "holopointer"
	description = "Illuminate a hologram to notify or beckon crew."
	nanite_cost = 5
	power_type = /datum/action/cooldown/ai_program/ranged/pointer
	unlock_text = "Hologram emitters online."

/datum/action/cooldown/ai_program/ranged/pointer
	name = "Holopointer"
	desc = "Illuminate a hologram to notify or beckon crew."
	button_icon = 'icons/mob/telegraphing/telegraph_holographic.dmi'
	button_icon_state = "target_circle"
	cooldown_time = 15 SECONDS
	cooldown_min = 15 SECONDS
	level_max = 1
	selection_activated_message = span_notice_alt("You prepare to illuminate a hologram...")
	selection_deactivated_message = span_notice_alt("You spool down your projector.")

/datum/action/cooldown/ai_program/ranged/pointer/cast(atom/target, mob/living/silicon/ai/user)
	if(!target)
		to_chat(user, span_warning("No valid target!"))
		revert_cast()
		return
	if(!check_camera_vision(user, target))
		revert_cast()
		return
	if(!user.program_picker.spend_nanites(program.nanite_cost))
		to_chat(user, span_warning("Not enough nanites!"))
		revert_cast()
		return
	new /obj/effect/temp_visual/ai_pointer(get_turf(target))
