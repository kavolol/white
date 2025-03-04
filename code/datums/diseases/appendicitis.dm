/datum/disease/appendicitis
	form = "Обстоятельства"
	name = "Аппендицит"
	max_stages = 3
	cure_text = "Хирургия"
	agent = "Дерьмовый аппендицит"
	viable_mobtypes = list(/mob/living/carbon/human)
	permeability_mod = 1
	desc = "Если не лечить, субъект станет очень слабым и его может часто рвать."
	severity = DISEASE_SEVERITY_MEDIUM
	disease_flags = CAN_CARRY|CAN_RESIST
	spread_flags = DISEASE_SPREAD_NON_CONTAGIOUS
	visibility_flags = HIDDEN_PANDEMIC
	required_organs = list(/obj/item/organ/appendix)
	bypasses_immunity = TRUE // Immunity is based on not having an appendix; this isn't a virus


/datum/disease/appendicitis/stage_act(delta_time, times_fired)
	. = ..()
	if(!.)
		return

	switch(stage)
		if(1)
			if(DT_PROB(2.5, delta_time))
				affected_mob.emote("cough")
		if(2)
			var/obj/item/organ/appendix/A = affected_mob.getorgan(/obj/item/organ/appendix)
			if(A)
				A.inflamed = 1
				A.update_icon()
			if(DT_PROB(1.5, delta_time))
				to_chat(affected_mob, span_warning("Чувствуете колющую боль в животе!"))
				affected_mob.adjustOrganLoss(ORGAN_SLOT_APPENDIX, 5)
				affected_mob.Stun(rand(40, 60))
				affected_mob.adjustToxLoss(1, FALSE)
		if(3)
			if(DT_PROB(0.5, delta_time))
				affected_mob.vomit(95)
				affected_mob.adjustOrganLoss(ORGAN_SLOT_APPENDIX, 15)
