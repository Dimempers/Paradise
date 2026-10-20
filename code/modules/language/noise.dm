/datum/language/noise
	name = "Шум"
	desc = "Просто шум."
	flags = LANGUAGE_RESTRICTED | LANGUAGE_INNATE | LANGUAGE_NO_TALK_MSG | LANGUAGE_NO_STUTTER | LANGUAGE_NOBABEL
	icon_state = null

/datum/language/noise/get_talkinto_msg_range(message)
	return (copytext(message, length(message)) == "!") ? 4 : 2

/datum/language/angel
	name = "Ангельское пение"
	spans = list("colossus", "yell")
	flags = LANGUAGE_RESTRICTED | LANGUAGE_NO_STUTTER | LANGUAGE_NOBABEL | LANGUAGE_INNATE
	icon_state = null

/datum/language/angel/proc/get_spans(mob/speaker)
	. = jointext(spans, " ")
	if(iscultist(speaker))
		. += " narsiesmall"

/datum/language/angel/format_message(message, mob/speaker)
	return span_message("<span class='[get_spans(speaker)]'>[message]</span>")
