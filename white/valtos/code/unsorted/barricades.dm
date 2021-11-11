// Snow, wood, sandbags, metal, plasteel

/obj/structure/deployable_barricade
	icon = 'white/valtos/icons/barricade.dmi'
	anchored = TRUE
	density = TRUE
	layer = BELOW_OBJ_LAYER
	flags_1 = ON_BORDER_1
	max_integrity = 100
	///The type of stack the barricade dropped when disassembled if any.
	var/stack_type
	///The amount of stack dropped when disassembled at full health
	var/stack_amount = 5
	///to specify a non-zero amount of stack to drop when destroyed
	var/destroyed_stack_amount = 0
	var/base_acid_damage = 2
	///Whether things can be thrown over
	var/allow_thrown_objs = TRUE
	var/barricade_type = "barricade" //"metal", "plasteel", etc.
	///Whether this barricade has damaged states
	var/can_change_dmg_state = TRUE
	///Whether we can open/close this barrricade and thus go over it
	var/closed = FALSE
	///Can this barricade type be wired
	var/can_wire = FALSE
	///is this barriade wired?
	var/is_wired = FALSE

/obj/structure/deployable_barricade/Initialize()
	. = ..()
	update_icon()
	var/static/list/connections = list(
		COMSIG_ATOM_EXIT = .proc/on_try_exit
	)
	AddElement(/datum/element/connect_loc, connections)
	AddElement(/datum/element/climbable)

/obj/structure/deployable_barricade/examine(mob/user)
	. = ..()
	if(is_wired)
		to_chat(user, span_info("There is a length of wire strewn across the top of this barricade."))
	switch((obj_integrity / max_integrity) * 100)
		if(75 to INFINITY)
			to_chat(user, span_info("It appears to be in good shape."))
		if(50 to 75)
			to_chat(user, span_warning("It's slightly damaged, but still very functional."))
		if(25 to 50)
			to_chat(user, span_warning("It's quite beat up, but it's holding together."))
		if(-INFINITY to 25)
			to_chat(user, span_warning("It's crumbling apart, just a few more blows will tear it apart."))


/obj/structure/deployable_barricade/proc/on_try_exit(datum/source, atom/movable/leaving, direction)
	SIGNAL_HANDLER

	if(leaving == src)
		return

	if(!(direction & dir))
		return

	if (!density)
		return

	if (leaving.throwing)
		return

	if (leaving.movement_type & (PHASING | FLYING | FLOATING))
		return

	if (leaving.move_force >= MOVE_FORCE_EXTREMELY_STRONG)
		return

	leaving.Bump(src)
	return COMPONENT_ATOM_BLOCK_EXIT

/obj/structure/deployable_barricade/CanPass(atom/movable/mover, border_dir)
	. = ..()

	if(istype(mover, /obj/projectile))
		if(!anchored)
			return TRUE
		var/obj/projectile/proj = mover
		if(proj.firer && Adjacent(proj.firer))
			return TRUE
		if(prob(25))
			return TRUE
		return FALSE

	if((border_dir & dir) && !closed)
		return . || mover.throwing || mover.movement_type & (FLYING | FLOATING)
	return TRUE

/obj/structure/deployable_barricade/attackby(obj/item/I, mob/living/user, params)
	if(istype(I, /obj/item/stack/cable_coil) && can_wire)
		var/obj/item/stack/S = I
		if(S.use(15))
			wire()
		else
			return
	else
		..()

/obj/structure/deployable_barricade/attack_animal(mob/user)
	return attack_alien(user)

/obj/structure/deployable_barricade/proc/wire()
	can_wire = FALSE
	is_wired = TRUE
	modify_max_integrity(max_integrity + 50)
	update_icon()

/obj/structure/deployable_barricade/wirecutter_act(mob/living/user, obj/item/I)
	if(!is_wired)
		return FALSE

	user.visible_message(span_notice("[user] begin removing the barbed wire on [src]."),
	span_notice("You begin removing the barbed wire on [src]."))

	if(!do_after(user, 2 SECONDS, src))
		return TRUE

	playsound(loc, 'sound/items/wirecutter.ogg', 25, TRUE)
	user.visible_message(span_notice("[user] removes the barbed wire on [src]."),
	span_notice("You remove the barbed wire on [src]."))
	modify_max_integrity(max_integrity - 50)
	can_wire = TRUE
	is_wired = FALSE
	update_icon()


/obj/structure/deployable_barricade/deconstruct(disassembled = TRUE)
	if(stack_type)
		var/stack_amt
		if(!disassembled && destroyed_stack_amount)
			stack_amt = destroyed_stack_amount
		else
			stack_amt = round(stack_amount * (obj_integrity/max_integrity)) //Get an amount of sheets back equivalent to remaining health. Obviously, fully destroyed means 0

		if(stack_amt)
			new stack_type (loc, stack_amt)
	return ..()

/obj/structure/deployable_barricade/ex_act(severity)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			visible_message(span_danger("[src] is blown apart!"))
			deconstruct(FALSE)
			return
		if(EXPLODE_HEAVY)
			take_damage(rand(33, 66))
		if(EXPLODE_LIGHT)
			take_damage(rand(10, 33))
	update_icon()

/obj/structure/deployable_barricade/setDir(newdir)
	. = ..()
	update_icon()

/obj/structure/deployable_barricade/update_icon()
	. = ..()
	var/damage_state
	var/percentage = (obj_integrity / max_integrity) * 100
	switch(percentage)
		if(-INFINITY to 25)
			damage_state = 3
		if(25 to 50)
			damage_state = 2
		if(50 to 75)
			damage_state = 1
		if(75 to INFINITY)
			damage_state = 0
	if(!closed)
		if(can_change_dmg_state)
			icon_state = "[barricade_type]_[damage_state]"
		else
			icon_state = "[barricade_type]"
		switch(dir)
			if(SOUTH)
				layer = ABOVE_MOB_LAYER
			if(NORTH)
				layer = initial(layer) - 0.01
			else
				layer = initial(layer)
		if(!anchored)
			layer = initial(layer)
	else
		if(can_change_dmg_state)
			icon_state = "[barricade_type]_closed_[damage_state]"
		else
			icon_state = "[barricade_type]_closed"
		layer = OBJ_LAYER

/obj/structure/deployable_barricade/update_overlays()
	. = ..()
	if(is_wired)
		if(!closed)
			. += image('white/valtos/icons/barricade.dmi', icon_state = "[barricade_type]_wire")
		else
			. += image('white/valtos/icons/barricade.dmi', icon_state = "[barricade_type]_closed_wire")

/obj/structure/deployable_barricade/verb/rotate()
	set name = "Rotate Barricade Counter-Clockwise"
	set category = "Object"
	set src in oview(1)

	if(anchored)
		to_chat(usr, span_warning("It is fastened to the floor, you can't rotate it!"))
		return FALSE

	setDir(turn(dir, 90))

/obj/structure/deployable_barricade/verb/revrotate()
	set name = "Rotate Barricade Clockwise"
	set category = "Object"
	set src in oview(1)

	if(anchored)
		to_chat(usr, span_warning("It is fastened to the floor, you can't rotate it!"))
		return FALSE

	setDir(turn(dir, 270))


/obj/structure/deployable_barricade/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(anchored)
		to_chat(user, span_warning("It is fastened to the floor, you can't rotate it!"))
		return FALSE

	setDir(turn(dir, 270))


/*----------------------*/
// SNOW
/*----------------------*/

/obj/structure/deployable_barricade/snow
	name = "snow barricade"
	desc = "A mound of snow shaped into a sloped wall. Statistically better than thin air as cover."
	icon_state = "snow_0"
	barricade_type = "snow"
	max_integrity = 75
	stack_type = /obj/item/stack/sheet/mineral/snow
	stack_amount = 3
	destroyed_stack_amount = 0
	can_wire = FALSE

/*----------------------*/
// GUARD RAIL
/*----------------------*/

/obj/structure/deployable_barricade/guardrail
	name = "guard rail"
	desc = "A short wall made of rails to prevent entry into dangerous areas."
	icon_state = "railing_0"
	max_integrity = 150
	armor = list("melee" = 0, "bullet" = 50, "laser" = 50, "energy" = 50, "bomb" = 15, "bio" = 100, "rad" = 100, "fire" = 100, "acid" = 10)
	stack_type = /obj/item/stack/rods
	destroyed_stack_amount = 3
	barricade_type = "railing"
	allow_thrown_objs = FALSE
	can_wire = FALSE

/obj/structure/deployable_barricade/guardrail/update_icon()
	. = ..()
	if(dir == NORTH)
		pixel_y = 12

/*----------------------*/
// WOOD
/*----------------------*/

/obj/structure/deployable_barricade/wooden
	name = "wooden barricade"
	desc = "A wall made out of wooden planks nailed together. Not very sturdy, but can provide some concealment."
	icon = 'white/valtos/icons/barricade.dmi'
	icon_state = "wooden"
	max_integrity = 100
	layer = OBJ_LAYER
	stack_type = /obj/item/stack/sheet/mineral/wood
	stack_amount = 5
	destroyed_stack_amount = 3
	can_change_dmg_state = FALSE
	barricade_type = "wooden"
	can_wire = FALSE

/obj/structure/deployable_barricade/wooden/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/stack/sheet/mineral/wood))
		var/obj/item/stack/sheet/mineral/wood/D = I
		if(obj_integrity >= max_integrity)
			return

		if(D.get_amount() < 1)
			to_chat(user, span_warning("You need one plank of wood to repair [src]."))
			return

		visible_message(span_notice("[user] begins to repair [src]."))

		if(!do_after(user,20, src) || obj_integrity >= max_integrity)
			return

		if(!D.use(1))
			return

		repair_damage(max_integrity)
		visible_message(span_notice("[user] repairs [src]."))


/*----------------------*/
// METAL
/*----------------------*/

#define BARRICADE_METAL_LOOSE 0
#define BARRICADE_METAL_ANCHORED 1
#define BARRICADE_METAL_FIRM 2

#define CADE_TYPE_BOMB "concussive armor"
#define CADE_TYPE_MELEE "ballistic armor"
#define CADE_TYPE_ACID "caustic armor"

#define CADE_UPGRADE_REQUIRED_SHEETS 2

/obj/structure/deployable_barricade/metal
	name = "metal barricade"
	desc = "A sturdy and easily assembled barricade made of metal plates, often used for quick fortifications. Use a blowtorch to repair."
	icon_state = "metal_0"
	max_integrity = 200
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 100, "rad" = 0, "fire" = 80, "acid" = 40)
	stack_type = /obj/item/stack/sheet/iron
	stack_amount = 4
	destroyed_stack_amount = 2
	barricade_type = "metal"
	can_wire = TRUE
	///Build state of the barricade
	var/build_state = BARRICADE_METAL_FIRM
	///The type of upgrade and corresponding overlay we have attached
	var/barricade_upgrade_type

/obj/structure/deployable_barricade/metal/update_overlays()
	. = ..()
	if(!barricade_upgrade_type)
		return
	var/damage_state
	var/percentage = (obj_integrity / max_integrity) * 100
	switch(percentage)
		if(-INFINITY to 25)
			damage_state = 3
		if(25 to 50)
			damage_state = 2
		if(50 to 75)
			damage_state = 1
		if(75 to INFINITY)
			damage_state = 0
	switch(barricade_upgrade_type)
		if(CADE_TYPE_BOMB)
			. += image('white/valtos/icons/barricade.dmi', icon_state = "+explosive_upgrade_[damage_state]")
		if(CADE_TYPE_MELEE)
			. += image('white/valtos/icons/barricade.dmi', icon_state = "+brute_upgrade_[damage_state]")
		if(CADE_TYPE_ACID)
			. += image('white/valtos/icons/barricade.dmi', icon_state = "+burn_upgrade_[damage_state]")

/obj/structure/deployable_barricade/metal/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/stack/sheet/iron))
		var/obj/item/stack/sheet/iron/metal_sheets = I
		if(obj_integrity > max_integrity * 0.3)
			return attempt_barricade_upgrade(I, user, params)

		if(metal_sheets.get_amount() < 2)
			to_chat(user, span_warning("You need two metal sheets to repair the base of [src]."))
			return FALSE

		visible_message(span_notice("[user] begins to repair the base of [src]."))

		if(!do_after(user, 2 SECONDS, src) || obj_integrity >= max_integrity)
			return FALSE

		if(!metal_sheets.use(2))
			return FALSE

		repair_damage(max_integrity * 0.3)
		visible_message(span_notice("[user] repairs the base of [src]."))



/obj/structure/deployable_barricade/metal/proc/attempt_barricade_upgrade(obj/item/stack/sheet/iron/metal_sheets, mob/user, params)
	if(barricade_upgrade_type)
		to_chat(user, span_warning("[src] is already upgraded."))
		return FALSE
	if(obj_integrity < max_integrity)
		to_chat(user, span_warning("You need [src] to be at full health before you can upgrade it."))
		return FALSE

	if(metal_sheets.get_amount() < CADE_UPGRADE_REQUIRED_SHEETS)
		to_chat(user, span_warning("You need at least [CADE_UPGRADE_REQUIRED_SHEETS] metal sheets to repair the base of [src]."))
		return FALSE

	var/static/list/cade_types = list(CADE_TYPE_BOMB = image(icon = 'white/valtos/icons/barricade.dmi', icon_state = "explosive_obj"), CADE_TYPE_MELEE = image(icon = 'white/valtos/icons/barricade.dmi', icon_state = "brute_obj"), CADE_TYPE_ACID = image(icon = 'white/valtos/icons/barricade.dmi', icon_state = "burn_obj"))
	var/choice = show_radial_menu(user, src, cade_types, require_near = TRUE, tooltips = TRUE)

	user.visible_message(span_notice("[user] begins attaching [choice] to [src]."),
		span_notice("You begin attaching [choice] to [src]."))
	if(!do_after(user, 2 SECONDS, src))
		return FALSE

	if(!metal_sheets.use(CADE_UPGRADE_REQUIRED_SHEETS))
		return FALSE

	switch(choice)
		if(CADE_TYPE_BOMB)
			armor = armor.modifyRating(bomb = 50)
		if(CADE_TYPE_MELEE)
			armor = armor.modifyRating(melee = 30, bullet = 30)
		if(CADE_TYPE_ACID)
			armor = armor.modifyRating(bio = 0, acid = 20)

	barricade_upgrade_type = choice

	user.visible_message(span_notice("[user] attaches [choice] to [src]."),
		span_notice("You attach [choice] to [src]."))

	playsound(loc, 'sound/items/screwdriver.ogg', 25, TRUE)
	update_icon()


/obj/structure/deployable_barricade/metal/examine(mob/user)
	. = ..()
	switch(build_state)
		if(BARRICADE_METAL_FIRM)
			to_chat(user, span_info("The protection panel is still tighly screwed in place."))
		if(BARRICADE_METAL_ANCHORED)
			to_chat(user, span_info("The protection panel has been removed, you can see the anchor bolts."))
		if(BARRICADE_METAL_LOOSE)
			to_chat(user, span_info("The protection panel has been removed and the anchor bolts loosened. It's ready to be taken apart."))

	to_chat(user, span_info("It is [barricade_upgrade_type ? "upgraded with [barricade_upgrade_type]" : "not upgraded"]."))

/obj/structure/deployable_barricade/metal/welder_act(mob/living/user, obj/item/I)

	var/obj/item/weldingtool/WT = I

	if(!WT.isOn())
		return FALSE

	if(obj_integrity <= max_integrity * 0.3)
		to_chat(user, span_warning("[src] has sustained too much structural damage and needs more metal plates to be repaired."))
		return TRUE

	if(obj_integrity == max_integrity)
		to_chat(user, span_warning("[src] doesn't need repairs."))
		return TRUE

	user.visible_message(span_notice("[user] begins repairing damage to [src]."),
	span_notice("You begin repairing the damage to [src]."))
	playsound(loc, 'sound/items/welder2.ogg', 25, TRUE)

	if(!do_after(user, 5 SECONDS, src))
		return TRUE

	if(obj_integrity <= max_integrity * 0.3 || obj_integrity == max_integrity)
		return TRUE

	if(!WT.use(2))
		to_chat(user, span_warning("Not enough fuel to finish the task."))
		return TRUE

	user.visible_message(span_notice("[user] repairs some damage on [src]."),
	span_notice("You repair [src]."))
	repair_damage(150)
	update_icon()
	playsound(loc, 'sound/items/welder2.ogg', 25, TRUE)
	return TRUE


/obj/structure/deployable_barricade/metal/screwdriver_act(mob/living/user, obj/item/I)
	switch(build_state)
		if(BARRICADE_METAL_ANCHORED) //Protection panel removed step. Screwdriver to put the panel back, wrench to unsecure the anchor bolts

			playsound(loc, 'sound/items/screwdriver.ogg', 25, TRUE)
			if(!do_after(user, 1 SECONDS, src))
				return TRUE

			user.visible_message(span_notice("[user] set [src]'s protection panel back."),
			span_notice("You set [src]'s protection panel back."))
			build_state = BARRICADE_METAL_FIRM
			return TRUE

		if(BARRICADE_METAL_FIRM) //Fully constructed step. Use screwdriver to remove the protection panels to reveal the bolts

			playsound(loc, 'sound/items/screwdriver.ogg', 25, TRUE)

			if(!do_after(user, 1 SECONDS, src))
				return TRUE

			user.visible_message(span_notice("[user] removes [src]'s protection panel."),
			span_notice("You remove [src]'s protection panels, exposing the anchor bolts."))
			build_state = BARRICADE_METAL_ANCHORED
			return TRUE


/obj/structure/deployable_barricade/metal/wrench_act(mob/living/user, obj/item/I)
	switch(build_state)
		if(BARRICADE_METAL_ANCHORED) //Protection panel removed step. Screwdriver to put the panel back, wrench to unsecure the anchor bolts

			playsound(loc, 'sound/items/ratchet.ogg', 25, TRUE)
			if(!do_after(user, 1 SECONDS, src))
				return TRUE

			user.visible_message(span_notice("[user] loosens [src]'s anchor bolts."),
			span_notice("You loosen [src]'s anchor bolts."))
			build_state = BARRICADE_METAL_LOOSE
			anchored = FALSE
			modify_max_integrity(initial(max_integrity) * 0.5)
			update_icon() //unanchored changes layer
			return TRUE

		if(BARRICADE_METAL_LOOSE) //Anchor bolts loosened step. Apply crowbar to unseat the panel and take apart the whole thing. Apply wrench to resecure anchor bolts

			var/turf/mystery_turf = get_turf(src)
			if(!isopenturf(mystery_turf))
				to_chat(user, span_warning("We can't anchor the barricade here!"))
				return TRUE

			for(var/obj/structure/deployable_barricade/B in loc)
				if(B != src && B.dir == dir)
					to_chat(user, span_warning("There's already a barricade here."))
					return TRUE

			playsound(loc, 'sound/items/ratchet.ogg', 25, TRUE)
			if(!do_after(user, 1 SECONDS, src))
				return TRUE

			user.visible_message(span_notice("[user] secures [src]'s anchor bolts."),
			span_notice("You secure [src]'s anchor bolts."))
			build_state = BARRICADE_METAL_ANCHORED
			anchored = TRUE
			modify_max_integrity(initial(max_integrity))
			update_icon() //unanchored changes layer
			return TRUE


/obj/structure/deployable_barricade/metal/crowbar_act(mob/living/user, obj/item/I)
	switch(build_state)
		if(BARRICADE_METAL_LOOSE) //Anchor bolts loosened step. Apply crowbar to unseat the panel and take apart the whole thing. Apply wrench to resecure anchor bolts

			user.visible_message(span_notice("[user] starts unseating [src]'s panels."),
			span_notice("You start unseating [src]'s panels."))

			playsound(loc, 'sound/items/crowbar.ogg', 25, 1)
			if(!do_after(user, 5 SECONDS, src))
				return TRUE

			user.visible_message(span_notice("[user] takes [src]'s panels apart."),
			span_notice("You take [src]'s panels apart."))
			playsound(loc, 'sound/items/deconstruct.ogg', 25, 1)
			var/deconstructed = TRUE
			deconstruct(deconstructed)
			return TRUE
		if(BARRICADE_METAL_FIRM)

			if(!barricade_upgrade_type) //Check to see if we actually have upgrades to remove.
				to_chat(user, span_warning("This barricade has no upgrades to remove!"))
				return TRUE

			user.visible_message(span_notice("[user] starts disassembling [src]'s armor plates."),
			span_notice("You start disassembling [src]'s armor plates."))

			playsound(loc, 'sound/items/crowbar.ogg', 25, 1)
			if(!do_after(user, 5 SECONDS, src))
				return TRUE

			user.visible_message(span_notice("[user] takes [src]'s armor plates apart."),
			span_notice("You take [src]'s armor plates apart."))
			playsound(loc, 'sound/items/deconstruct.ogg', 25, 1)

			switch(barricade_upgrade_type)
				if(CADE_TYPE_BOMB)
					armor = armor.modifyRating(bomb = -50)
				if(CADE_TYPE_MELEE)
					armor = armor.modifyRating(melee = -30, bullet = -30)
				if(CADE_TYPE_ACID)
					armor = armor.modifyRating(bio = 0, acid = -20)

			new /obj/item/stack/sheet/iron(loc, CADE_UPGRADE_REQUIRED_SHEETS)
			barricade_upgrade_type = null
			update_icon()
			return TRUE


/obj/structure/deployable_barricade/metal/ex_act(severity)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			take_damage(rand(400, 600))
		if(EXPLODE_HEAVY)
			take_damage(rand(150, 350))
		if(EXPLODE_LIGHT)
			take_damage(rand(50, 100))

	update_icon()


#undef BARRICADE_METAL_LOOSE
#undef BARRICADE_METAL_ANCHORED
#undef BARRICADE_METAL_FIRM

/*----------------------*/
// PLASTEEL
/*----------------------*/

#define BARRICADE_PLASTEEL_LOOSE 0
#define BARRICADE_PLASTEEL_ANCHORED 1
#define BARRICADE_PLASTEEL_FIRM 2

/obj/structure/deployable_barricade/plasteel
	name = "plasteel barricade"
	desc = "A very sturdy barricade made out of plasteel panels, the pinnacle of strongpoints. Use a blowtorch to repair. Can be flipped down to create a path."
	icon_state = "plasteel_closed_0"
	max_integrity = 500
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 100, "rad" = 0, "fire" = 80, "acid" = 40)
	stack_type = /obj/item/stack/sheet/plasteel
	stack_amount = 5
	destroyed_stack_amount = 2
	barricade_type = "plasteel"
	density = FALSE
	closed = TRUE
	can_wire = TRUE

	///What state is our barricade in for construction steps?
	var/build_state = BARRICADE_PLASTEEL_FIRM
	var/busy = FALSE //Standard busy check
	///ehther we react with other cades next to us ie when opening or so
	var/linked = FALSE
	COOLDOWN_DECLARE(tool_cooldown) //Delay to apply tools to prevent spamming

/obj/structure/deployable_barricade/plasteel/examine(mob/user)
	. = ..()

	switch(build_state)
		if(BARRICADE_PLASTEEL_FIRM)
			to_chat(user, span_info("The protection panel is still tighly screwed in place."))
		if(BARRICADE_PLASTEEL_ANCHORED)
			to_chat(user, span_info("The protection panel has been removed, you can see the anchor bolts."))
		if(BARRICADE_PLASTEEL_LOOSE)
			to_chat(user, span_info("The protection panel has been removed and the anchor bolts loosened. It's ready to be taken apart."))

/obj/structure/deployable_barricade/plasteel/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/stack/sheet/plasteel))
		var/obj/item/stack/sheet/plasteel/plasteel_sheets = I
		if(obj_integrity > max_integrity * 0.3)
			return

		if(plasteel_sheets.get_amount() < 2)
			to_chat(user, span_warning("You need two plasteel sheets to repair the base of [src]."))
			return

		visible_message(span_notice("[user] begins to repair the base of [src]."))

		if(!do_after(user, 2 SECONDS, src) || obj_integrity >= max_integrity)
			return

		if(!plasteel_sheets.use(2))
			return

		repair_damage(max_integrity * 0.3)
		visible_message(span_notice("[user] repairs the base of [src]."))
		return

	if(busy)
		return

	COOLDOWN_START(src, tool_cooldown, 1 SECONDS)

	if(istype(I, /obj/item/weldingtool))
		var/obj/item/weldingtool/WT = I

		if(obj_integrity <= max_integrity * 0.3)
			to_chat(user, span_warning("[src] has sustained too much structural damage and needs more plasteel plates to be repaired."))
			return

		if(obj_integrity == max_integrity)
			to_chat(user, span_warning("[src] doesn't need repairs."))
			return

		if(!WT.use(0))
			return FALSE


		user.visible_message(span_notice("[user] begins repairing damage to [src]."),
		span_notice("You begin repairing the damage to [src]."))
		playsound(loc, 'sound/items/welder2.ogg', 25, 1)
		busy = TRUE

		if(!do_after(user, 50, src))
			busy = FALSE
			return

		busy = FALSE
		user.visible_message(span_notice("[user] repairs some damage on [src]."),
		span_notice("You repair [src]."))
		repair_damage(150)
		update_icon()
		playsound(loc, 'sound/items/welder2.ogg', 25, 1)

	switch(build_state)
		if(BARRICADE_PLASTEEL_FIRM) //Fully constructed step. Use screwdriver to remove the protection panels to reveal the bolts
			if(I.tool_behaviour == TOOL_SCREWDRIVER)

				for(var/obj/structure/deployable_barricade/B in loc)
					if(B != src && B.dir == dir)
						to_chat(user, span_warning("There's already a barricade here."))
						return

				if(!do_after(user, 1, src))
					return

				user.visible_message(span_notice("[user] removes [src]'s protection panel."),

				span_notice("You remove [src]'s protection panels, exposing the anchor bolts."))
				playsound(loc, 'sound/items/screwdriver.ogg', 25, 1)
				build_state = BARRICADE_PLASTEEL_ANCHORED
			else if(I.tool_behaviour == TOOL_CROWBAR)
				user.visible_message(span_notice(" [user] [linked ? "un" : "" ]links [src]."), span_notice("You [linked ? "un" : "" ]link [src]."))
				linked = !linked
				for(var/direction in GLOB.cardinals)
					for(var/obj/structure/deployable_barricade/plasteel/cade in get_step(src, direction))
						cade.update_icon()
				update_icon()
		if(BARRICADE_PLASTEEL_ANCHORED) //Protection panel removed step. Screwdriver to put the panel back, wrench to unsecure the anchor bolts
			if(I.tool_behaviour == TOOL_SCREWDRIVER)
				user.visible_message(span_notice("[user] set [src]'s protection panel back."),
				span_notice("You set [src]'s protection panel back."))
				playsound(loc, 'sound/items/screwdriver.ogg', 25, 1)
				build_state = BARRICADE_PLASTEEL_FIRM

			else if(I.tool_behaviour == TOOL_WRENCH)
				user.visible_message(span_notice("[user] loosens [src]'s anchor bolts."),
				span_notice("You loosen [src]'s anchor bolts."))
				playsound(loc, 'sound/items/ratchet.ogg', 25, 1)
				anchored = FALSE
				modify_max_integrity(initial(max_integrity) * 0.5)
				build_state = BARRICADE_PLASTEEL_LOOSE
				update_icon() //unanchored changes layer
		if(BARRICADE_PLASTEEL_LOOSE) //Anchor bolts loosened step. Apply crowbar to unseat the panel and take apart the whole thing. Apply wrench to rescure anchor bolts
			if(I.tool_behaviour == TOOL_WRENCH)

				var/turf/mystery_turf = get_turf(src)
				if(!isopenturf(mystery_turf))
					to_chat(user, span_warning("We can't anchor the barricade here!"))
					return

				user.visible_message(span_notice("[user] secures [src]'s anchor bolts."),
				span_notice("You secure [src]'s anchor bolts."))
				playsound(loc, 'sound/items/ratchet.ogg', 25, 1)
				anchored = TRUE
				modify_max_integrity(initial(max_integrity))
				build_state = BARRICADE_PLASTEEL_ANCHORED
				update_icon() //unanchored changes layer

			else if(I.tool_behaviour == TOOL_CROWBAR)
				user.visible_message(span_notice("[user] starts unseating [src]'s panels."),
				span_notice("You start unseating [src]'s panels."))
				playsound(loc, 'sound/items/crowbar.ogg', 25, 1)
				busy = TRUE

				if(!do_after(user, 50, src))
					busy = FALSE
					return

				busy = FALSE
				user.visible_message(span_notice("[user] takes [src]'s panels apart."),
				span_notice("You take [src]'s panels apart."))
				playsound(loc, 'sound/items/deconstruct.ogg', 25, 1)
				var/deconstructed = TRUE
				deconstruct(deconstructed)


/obj/structure/deployable_barricade/plasteel/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return

	if(do_after(user, 50, src))
		toggle_open(null, user)

/obj/structure/deployable_barricade/plasteel/proc/toggle_open(state, mob/living/user)
	if(state == closed)
		return
	playsound(loc, 'sound/items/ratchet.ogg', 25, 1)
	closed = !closed
	density = !density

	user?.visible_message(span_notice("[user] flips [src] [closed ? "closed" :"open"]."),
		span_notice("You flip [src] [closed ? "closed" :"open"]."))

	if(!linked)
		update_icon()
		return
	for(var/direction in GLOB.cardinals)
		for(var/obj/structure/deployable_barricade/plasteel/cade in get_step(src, direction))
			if(((dir & (NORTH|SOUTH) && get_dir(src, cade) & (EAST|WEST)) || (dir & (EAST|WEST) && get_dir(src, cade) & (NORTH|SOUTH))) && dir == cade.dir && cade.linked)
				cade.toggle_open(closed)

	update_icon()

/obj/structure/deployable_barricade/plasteel/update_overlays()
	. = ..()
	if(!linked)
		return
	for(var/direction in GLOB.cardinals)
		for(var/obj/structure/deployable_barricade/plasteel/cade in get_step(src, direction))
			if(((dir & (NORTH|SOUTH) && get_dir(src, cade) & (EAST|WEST)) || (dir & (EAST|WEST) && get_dir(src, cade) & (NORTH|SOUTH))) && dir == cade.dir && cade.linked && cade.closed == closed)
				. += image('white/valtos/icons/barricade.dmi', icon_state = "[barricade_type]_[closed ? "closed" : "open"]_connection_[get_dir(src, cade)]")

/obj/structure/deployable_barricade/plasteel/ex_act(severity)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			take_damage(rand(450, 650))
		if(EXPLODE_HEAVY)
			take_damage(rand(200, 400))
		if(EXPLODE_LIGHT)
			take_damage(rand(50, 150))

	update_icon()

#undef BARRICADE_PLASTEEL_LOOSE
#undef BARRICADE_PLASTEEL_ANCHORED
#undef BARRICADE_PLASTEEL_FIRM

/*----------------------*/
// SANDBAGS
/*----------------------*/

/obj/structure/deployable_barricade/sandbags
	name = "sandbag barricade"
	desc = "A bunch of bags filled with sand, stacked into a small wall. Surprisingly sturdy, albeit labour intensive to set up. Trusted to do the job since 1914."
	icon_state = "sandbag_0"
	max_integrity = 300
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 100, "rad" = 0, "fire" = 80, "acid" = 40)
	stack_type = /obj/item/stack/sheet/mineral/sandbags
	barricade_type = "sandbag"
	can_wire = TRUE

/obj/structure/deployable_barricade/sandbags/update_icon()
	. = ..()
	if(dir == SOUTH)
		pixel_y = -7
	else if(dir == NORTH)
		pixel_y = 7
	else
		pixel_y = 0


/obj/structure/deployable_barricade/sandbags/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/shovel) && user.a_intent != INTENT_HARM)
		var/obj/item/shovel/ET = I
		user.visible_message(span_notice("[user] starts disassembling [src]."),
		span_notice("You start disassembling [src]."))
		if(do_after(user, ET.toolspeed, src))
			user.visible_message(span_notice("[user] disassembles [src]."),
			span_notice("You disassemble [src]."))
			var/deconstructed = TRUE
			deconstruct(deconstructed)
		return TRUE

	if(istype(I, /obj/item/stack/sheet/mineral/sandbags) )
		if(obj_integrity == max_integrity)
			to_chat(user, span_warning("[src] isn't in need of repairs!"))
			return
		var/obj/item/stack/sheet/mineral/sandbags/D = I
		if(D.get_amount() < 1)
			to_chat(user, span_warning("You need a sandbag to repair [src]."))
			return
		visible_message(span_notice("[user] begins to replace [src]'s damaged sandbags..."))

		if(!do_after(user, 30, src) || obj_integrity >= max_integrity)
			return

		if(!D.use(1))
			return

		repair_damage(max_integrity * 0.2) //Each sandbag restores 20% of max health as 5 sandbags = 1 sandbag barricade.
		user.visible_message(span_notice("[user] replaces a damaged sandbag, repairing [src]."),
		span_notice("You replace a damaged sandbag, repairing it [src]."))
		update_icon()

//An item thats meant to be a template for quickly deploying stuff like barricades
/obj/item/quikdeploy
	name = "QuikDeploy System"
	desc = "This is a QuikDeploy system, allows for extremely fast placement of various objects."
	icon = 'white/valtos/icons/barricade.dmi'
	w_class = WEIGHT_CLASS_SMALL //While this is small, normal 50 stacks of metal is NORMAL so this is a bit on the bad space to cade ratio
	var/delay = 0 //Delay on deploying the thing
	var/atom/movable/thing_to_deploy = null

/obj/item/quikdeploy/examine(mob/user)
	. = ..()
	to_chat(user, "This QuikDeploy system seems to deploy a [thing_to_deploy.name].")

/obj/item/quikdeploy/attack_self(mob/user)
	to_chat(user, "<span class='warning'>You start to deploy onto the tile in front of you...")
	if(!do_after(usr, delay, src))
		to_chat(user, "<span class='warning'>You decide against deploying something here.")
		return
	if(can_place(user)) //can_place() handles sending the error and success messages to the user
		var/obj/O = new thing_to_deploy(get_turf(user))
		O.setDir(user.dir)
		playsound(loc, 'sound/items/ratchet.ogg', 25, TRUE)
		qdel(src)

/obj/item/quikdeploy/proc/can_place(mob/user)
	if(isnull(thing_to_deploy)) //Spaghetti or wrong type spawned
		to_chat(user, "<span class='warning'>This thing doesn't actually really do anything! Complain to whoever gave you this")
		return FALSE
	return TRUE

/obj/item/quikdeploy/cade
	thing_to_deploy = /obj/structure/deployable_barricade/metal
	icon_state = "metal"
	delay = 3 SECONDS

/obj/item/quikdeploy/cade/can_place(mob/user)
	. = ..()
	if(!.)
		return FALSE

	var/turf/mystery_turf = user.loc
	if(!isopenturf(mystery_turf))
		to_chat(user, span_warning("We can't build here!"))
		return FALSE

	var/turf/open/placement_loc = mystery_turf
	if(placement_loc.density) //We shouldn't be building here.
		to_chat(user, span_warning("We can't build here!"))
		return FALSE

	for(var/obj/thing in user.loc)
		if(!thing.density) //not dense, move on
			continue
		if(!(thing.flags_1 & ON_BORDER_1)) //dense and non-directional, end
			to_chat(user, span_warning("No space here for a barricade."))
			return FALSE
		if(thing.dir != user.dir)
			continue
		to_chat(user, span_warning("No space here for a barricade."))
		return FALSE
	to_chat(user, "<span class='notice'>You plop down the barricade in front of you.")
	return TRUE

/obj/item/quikdeploy/cade/plasteel
	thing_to_deploy = /obj/structure/deployable_barricade/plasteel
	icon_state = "plasteel"
