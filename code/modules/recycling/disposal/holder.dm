// virtual disposal object
// travels through pipes in lieu of actual items
// contents will be items flushed by the disposal
// this allows the gas flushed to be tracked

/obj/structure/disposalholder
	invisibility = INVISIBILITY_MAXIMUM
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	dir = NONE
	flags_1 = RAD_PROTECT_CONTENTS_1 | RAD_NO_CONTAMINATE_1
	var/datum/gas_mixture/gas // gas used to flush, will appear at exit point
	var/active = FALSE // true if the holder is moving, otherwise inactive
	var/count = 1000 // can travel 1000 steps before going inactive (in case of loops)
	var/destinationTag = NONE // changes if contains a delivery container
	var/tomail = FALSE // contains wrapped package
	var/hasmob = FALSE // contains a mob

/obj/structure/disposalholder/Destroy()
	QDEL_NULL(gas)
	active = FALSE
	return ..()

// initialize a holder from the contents of a disposal unit
/obj/structure/disposalholder/proc/init(obj/machinery/disposal/D)
	if(!istype(D))
		return
	gas = D.air_contents// transfer gas resv. into holder object

	//Check for any living mobs trigger hasmob.
	//hasmob effects whether the package goes to cargo or its tagged destination.
	for(var/mob/living/M in D)
		if(M.client)
			M.reset_perspective(src)
		hasmob = TRUE

	//Checks 1 contents level deep. This means that players can be sent through disposals mail...
	//...but it should require a second person to open the package. (i.e. person inside a wrapped locker)
	for(var/obj/O in D)
		if(locate(/mob/living) in O)
			hasmob = TRUE
			break

	// now everything inside the disposal gets put into the holder
	// note AM since can contain mobs or objs
	for(var/A in D)
		var/atom/movable/atom_in_transit = A
		if(atom_in_transit == src)
			continue
		SEND_SIGNAL(atom_in_transit, COMSIG_MOVABLE_DISPOSING, src, D, hasmob)
		atom_in_transit.forceMove(src)
		if(iscyborg(atom_in_transit))
			var/obj/item/dest_tagger/borg/tagger = locate() in atom_in_transit
			if(tagger)
				destinationTag = tagger.currTag


// start the movement process
// argument is the disposal unit the holder started in
/obj/structure/disposalholder/proc/start(obj/machinery/disposal/D)
	if(!D.trunk)
		D.expel(src) // no trunk connected, so expel immediately
		return
	forceMove(D.trunk)
	active = TRUE
	setDir(DOWN)
	move()

// movement process, persists while holder is moving through pipes
/obj/structure/disposalholder/proc/move()
	set waitfor = FALSE
	var/ticks = 1
	var/obj/structure/disposalpipe/last
	while(active)
		var/obj/structure/disposalpipe/curr = loc
		last = curr
		set_glide_size(DELAY_TO_GLIDE_SIZE(ticks * world.tick_lag))
		curr = curr.transfer(src)
		if(!curr && active)
			last.expel(src, get_turf(src), dir)

		ticks = stoplag()
		if(!(count--))
			active = FALSE

//failsafe in the case the holder is somehow forcemoved somewhere that's not a disposal pipe. Otherwise the above loop breaks.
/obj/structure/disposalholder/Moved(atom/oldLoc, dir)
	. = ..()
	var/static/list/pipes_typecache = typecacheof(/obj/structure/disposalpipe)
	//Moved to nullspace gang
	if(!loc)
		return
	if(!pipes_typecache[loc.type])
		var/turf/T = get_turf(loc)
		if(T)
			vent_gas(T)
		for(var/A in contents)
			var/atom/movable/AM = A
			AM.forceMove(drop_location())
		qdel(src)

// find the turf which should contain the next pipe
/obj/structure/disposalholder/proc/nextloc()
	return get_step(src, dir)

// find a matching pipe on a turf
/obj/structure/disposalholder/proc/findpipe(turf/T)
	if(!T)
		return null

	var/fdir = turn(dir, 180) // flip the movement direction
	for(var/obj/structure/disposalpipe/P in T)
		if(fdir & P.dpdir) // find pipe direction mask that matches flipped dir
			return P
	// if no matching pipe, return null
	return null

// merge two holder objects
// used when a holder meets a stuck holder
/obj/structure/disposalholder/proc/merge(obj/structure/disposalholder/other)
	for(var/A in other)
		var/atom/movable/AM = A
		AM.forceMove(src) // move everything in other holder to this one
		if(ismob(AM))
			var/mob/M = AM
			M.reset_perspective(src) // if a client mob, update eye to follow this holder
	qdel(other)


// called when player tries to move while in a pipe
/obj/structure/disposalholder/relaymove(mob/living/user, direction)
	if(user.incapacitated())
		return
	for(var/mob/M in range(5, get_turf(src)))
		M.show_message("<FONT size=[max(0, 5 - get_dist(src, M))]>БАМ, бам!</FONT>", MSG_AUDIBLE)
	playsound(src.loc, 'sound/effects/clang.ogg', 50, FALSE, FALSE)

// called to vent all gas in holder to a location
/obj/structure/disposalholder/proc/vent_gas(turf/T)
	T.assume_air(gas)
	T.air_update_turf(FALSE, FALSE)

/obj/structure/disposalholder/AllowDrop()
	return TRUE

/obj/structure/disposalholder/ex_act(severity, target)
	return FALSE
