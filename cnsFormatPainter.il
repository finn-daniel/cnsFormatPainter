
; use cnsHandle=cnmpsImport() to connect the skill engine to the DEHDL session that started the engine
; in DEHDL console, type 'system'
; a cmd window opens. type 'start cnskill -i -nongraph'
; the skill console opens. close the cmd window from the previous step to give control back to DEHDL.
; use load("cnsFormatPainter.il") to load this file
; use 'ImportHandle=cnmpsImport()', gets a handle to the running DEHDL instance.
; pass the handle to the procedures that use a DEHDL handle

ImportHandle=cnmpsImport()

;;----------------------------------------------------------------
;; Terminate when concept exit is detected
;;
procedure( ConceptExitHandler( Handle )
  printf( "Concept exit detected\n" )
  mpsClose( ExportHandle )
  exit( 0 )
)

silent=cnSetRunOptions(?result cnOUT_SILENT ?display cnOUT_SILENT)
verbose=cnSetRunOptions(?result cnOUT_VERBOSE ?display cnOUT_VERBOSE)


; figure out which component the user is closest to the cursor when the button was clicked,
; since there doesn't seem to be a simpler way to get info about the selected object.
procedure( getMouseButtonCallback( event coord ) 
  ; TODO: do I need to check which mouse button was pressed?
  xy = cnGetMouseXY(event)
  coord = set(coord xy)
  printf("Clicked coordinate: %L\n",coord)
)

procedure( getClickedComponent(prompt)
  let(
    ; local variable declarations
    (
      mouse_coord
      cmd_ret_obj prm_obj_set comp_obj_set
      topLeft botRight
      cmd comp_obj
    )

    mouse_coord=nil
    cnRequestMousePress(ImportHandle, `getMouseButtonCallback, `mouse_coord, prompt)
    ; wait for the callback to finish
    while((mouse_coord==nil)
      cnmpsSleep(ImportHandle 1)
      ; TODO: get user input in this loop so i don't get stuck
    )
    ; I can't seem to figure out how to get a handle to a component object, other than trying to select
    ; whatever component is close to the cursor when the mouse button was clicked.
    ; create a 200x200 bounding box to find components within. TODO: figure out how small I can make this
    topLeft = nth(0 mouse_coord)-100 : nth(1 mouse_coord)+100
    botRight = nth(0 mouse_coord)+100 : nth(1 mouse_coord)-100
    
    ; issue a "select" command in DEHDL. returns "bodies" within the bounding box.
    cmd = strcat("select A bodies " cnCreatePointString(topLeft) " " cnCreatePointString(botRight))
    cmd_ret_obj=cnSendCommand(ImportHandle cmd ?runOptions verbose)

    ; extract primitive object set from response
    prm_obj_set=cnGetGroupedObjectSet(cmd_ret_obj)

    ; get a list of properties from the primitive object set
    comp_obj_set=cnGetComps(prm_obj_set)

    ; hopefully there is only one component in the comp_obj_set, but maybe there will be more because
    ; of the size of the bounding box. I'll have to figure that out. TBD.
    if( (length(comp_obj_set) == 1)
      then
        comp_obj = nth(0 comp_obj_set)
      else if( (length(comp_obj_set) > 1) then
        printf("catch error case: more than one object found within bounding box\n")
        comp_obj = nil
      ) else
        comp_obj = nil
    )
  )
)

procedure( getAttachedProperties( component list_prop_objs )
  ; input the component object and a list of properties to check ownership against
  let(
    (
      list_attached_properties
      comp_dbid 
      relative_x relative_y relative_xy
      prop_visibility
    )

    comp_dbid = cnGetCompDbId(component)
    list_attached_properties = list()
    foreach(prop_obj list_prop_objs
      ; check if the property belongs to the component found earlier
      if( (cnGetPropOwnerDbId(prop_obj) == comp_dbid) then
        list_attached_properties = cons(prop_obj list_attached_properties)
      )
    )
    list_attached_properties
  )
)

procedure( formatPainter()
  let(
    ; local variable declarations
    (
      cmd_ret_obj prm_obj_set list_prop_objs
      copy_component copy_comp_xy
      prop_name prop_value prop_xy
    )

    copy_component = getClickedComponent("click the component to copy\n")

    ; TODO: make sure getClickedComponent returned something before continuing

    ; TODO:
    ; since i can't just get the properties attached to that component,
    ; select all of the properties in the drawing and loop through each to check
    ; if their owner is the above component.
    ; if the property is visible, save its relative XY location.
    ; selecting a different component, look for the same property name and set its visibility and
    ; relative xy.

    cmd_ret_obj = cnSendCommand(ImportHandle "select properties all" ?runOptions verbose)
    prm_obj_set = cnGetGroupedObjectSet(cmd_ret_obj)
    list_prop_objs = cnGetProps(prm_obj_set) ; this list contains all of the properties on the drawing, if I'm not mistaken

    copy_props = getAttachedProperties(copy_component list_prop_objs) ; the properties attached to copy_component
    copy_comp_xy = cnGetCompOriginXY(copy_component)


    paste_component = getClickedComponent("click the component to paste\n")
    paste_props = getAttachedProperties(paste_component list_prop_objs) ; the properties attached to paste_component
    ; we'll go through and match the property visibility

    foreach( c_prop copy_props
      c_prop_visibility=cnGetPropVisibility(c_prop)
      unless( (c_prop_visibility == 0) ; if the property is invisible, we don't do anything
        c_prop_name=cnGetPropName(c_prop)
        ; check if that property name shows up in paste_props
        foreach( p_prop paste_props
          p_prop_name=cnGetPropName(p_prop)
          if( (p_prop_name == c_prop_name) then
            ; found a matching property
            c_prop_value=cnGetPropValue(c_prop)
            c_relative_xy = getPropertyRelativeXY(copy_component c_prop)
            setPropertyRelativeXY(paste_component p_prop c_relative_xy)
            if( (prop_value != nil) 
              then
                printf("Found property %s=%s attached to component at %s (visibility=%d)\n" c_prop_name c_prop_value cnCreatePointString(c_relative_xy) c_prop_visibility)
              else
                printf("Found property %s attached to component at %s (visibility=%d)\n" c_prop_name cnCreatePointString(c_relative_xy) c_prop_visibility)
            )
          )
        )
      )
    )
  )
  t
)

procedure( getPropertyRelativeXY(component property)
  ; return x:y relative position of the property relative to the origin of the component it's attached to
  comp_xy = cnGetCompOriginXY(component)
  prop_xy = cnGetPropXY(property)
  relative_x = nth(0 prop_xy) - nth(0 comp_xy)
  relative_y = nth(1 prop_xy) - nth(1 comp_xy)
  relative_xy = (relative_x : relative_y)
)

procedure( setPropertyRelativeXY(component property xy)
  ; set the position of the property to xy relative to the origin of the component it's attached to
  t ; placeholder
)

procedure( formatPainterCallback()
  eventtype=cnGetEventType(event)
  cond(
    (eventtype==cnTEXTINPUT_EVENT
      printf("text input event\n")
      file_name=cnGetStringText(event)
      printf("filename: %s\n" file_name)
      brd_in(file_name ImportHandle)
    )
    (eventtype==cnSTART_EVENT
      printf("start event\n")
      cnSendCommand(ImportHandle "echo click on a component" ?runOptions verbose)
      file_name=nil
    )
    (eventtype==cnEND_EVENT
      printf("end event\n")
      cnSendCommand(ImportHandle "echo Have a nice day" ?runOptions verbose)
    )
    (t)
  )
)

procedure( cnCommands_formatPainterServer()
  list(
    list("formatPainter",
      list(
        list(cnSTART_EVENT, cnEND_EVENT, cnTEXTINPUT_EVENT)
        'formatPainterCallback
      )
    )
  )
)

AppServiceName	  = "cnsFormatPainterServer"
AppServiceVersion = "1.0"
AppToolName	  = AppServiceName


;; Export service into the same session which Concept Exports into.
;;   Alternatively, a different session can be specified here AND to
;; the Concept mpsdeclare command.
ExportHandle = mpsExport(
  AppToolName,
  AppServiceName,
  AppServiceVersion,
  '(cnCommands_formatPainterServer, formatPainterCallback),
  ?session cnmpsGetDefaultSessionName() 
)


;; Give Concept a moment to import the service we just exported,
;; before we attempt to import the Concept service.
mpsSleep( ExportHandle, 2 )
unless( cnmpsIsExported()		;; take a nap if concept is still busy
    mpsSleep( ExportHandle, 5 )
)
ImportHandle = cnmpsImport()
unless( ImportHandle
    printf( "Could not import Concept mps Service\n" )
    exit( 1 )
)

;; arrange to be notified when Concept exits
ImportHandle->exitHandler = 'ConceptExitHandler