
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
; procedure( getUserInputCallback( event userInput )
;   eventType=cnGetEventType(event)
;   print("test: eventType=%d\n" eventType)
;   cond(
;     (eventType==cnTEXTINPUT_EVENT
;       str = cnGetStringText(event)
;       print("test -- got string %s\n" str)
;       ; if( (str==intToChar(27)) then ; ESCAPE
;       ;   printf("escape character detected\n")
;       ; )
;       userInput = set(userInput str)
;     )
;     (eventType==cnMOUSEPRESS_EVENT
;       xy = cnGetMouseXY(event)
;       userInput = set(userInput xy)
;       printf("Clicked coordinate: %L\n",userInput)
;     )
;   )
; )

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
      userInput mouse_coord
      cmd_ret_obj prm_obj_set comp_obj_set
      topLeft botRight
      cmd comp_obj
    )

    userInput=nil
    ; cnRequestUserInput(ImportHandle, `getUserInputCallback, `userInput, prompt, list(cnTEXTINPUT_EVENT cnMOUSEPRESS_EVENT))
    ; count=0
    ; while((userInput==nil)
    ;   cnmpsSleep(ImportHandle 1)
    ;   printf("test: %d\n" count)
    ;   count = count+1
    ;   ; TODO: debug me - sometimes I get stuck here
    ; )

    mouse_coord=nil
    cnRequestMousePress(ImportHandle, `getMouseButtonCallback, `mouse_coord, prompt)
    ; wait for the callback to finish
    while((mouse_coord==nil)
      cnmpsSleep(ImportHandle 1)
      ; TODO: debug me -- sometimes the callback doesn't get called after an event, and I get stuck here
    )
    unless(stringp(userInput) ; check for string response type (user pressed a key to cancel

      ; mouse_coord = userInput
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
        else
          if( (length(comp_obj_set) > 1)
          then
            printf("catch error case: more than one object found within bounding box\n")
          else
            printf("no objects found near cursor\n")
          )
          comp_obj = nil
      )
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

    unless( (copy_component==nil)

      cmd_ret_obj = cnSendCommand(ImportHandle "select properties all" ?runOptions verbose)
      prm_obj_set = cnGetGroupedObjectSet(cmd_ret_obj)
      list_prop_objs = cnGetProps(prm_obj_set) ; this list contains all of the properties on the drawing

      copy_props = getAttachedProperties(copy_component list_prop_objs) ; the properties attached to copy_component
      copy_comp_xy = cnGetCompOriginXY(copy_component)

      continue_paste_loop = t
      while( (continue_paste_loop==t)

        paste_component = getClickedComponent("click the component to paste\n")
        if( (paste_component == nil)
          then
            continue_paste_loop = nil
          else
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
                    setPropertyVisAndXY(paste_component p_prop c_relative_xy c_prop_visibility)
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
      )
    )
  )
  t
)
; TODO: remove print statements
; TODO: delete the group that has all the properties in it
; TODO: create an option to continue pasting until ESC key hit or click away from component
; TODO: check if component types are the same before pasting. E.g. only paste from R to R, C to C, etc. (use refdes?)

procedure( getPropertyRelativeXY(component property)
  ; return x:y relative position of the property relative to the origin of the component it's attached to
  let(
    (comp_xy prop_xy relative_x relative_y relative_xy) ; local variable declarations
    comp_xy = cnGetCompOriginXY(component)
    prop_xy = cnGetPropXY(property)
    relative_x = nth(0 prop_xy) - nth(0 comp_xy)
    relative_y = nth(1 prop_xy) - nth(1 comp_xy)
    relative_xy = (relative_x : relative_y)
    printf("comp at %L, property %s at %L, relative %L\n" comp_xy cnGetPropName(property) prop_xy relative_xy)
    relative_xy
  )
)

procedure( setPropertyVisAndXY(component property rel_xy visibility)
  ; set the position of the property to xy relative to the origin of the component it's attached to
  let(
    ( ; local variable declarations
      comp_xy prop_xy abs_x abs_y cmd_ret_obj cmd
    )

    unless( (cnGetPropName(property) == "$PN") ; don't want to move pin numbers on top of each other

      p_rel_xy = getPropertyRelativeXY(component property)
      unless( 
        ( ; check if property is already at correct location
          (nth(0 p_rel_xy)==nth(0 rel_xy)) && 
          (nth(1 p_rel_xy)==nth(1 rel_xy))
        )
        ; find the origin of the component
        comp_xy = cnGetCompOriginXY(component)

        ; use the component origin and the rel_xy to find new absolute coordinates for the property
        ; find the location of the property so I send a 'select' command to DEHDL to add it to a group
        prop_xy = cnCreatePointString(cnGetPropXY(property))

        abs_x = nth(0 comp_xy)+nth(0 rel_xy)
        abs_y = nth(1 comp_xy) + nth(1 rel_xy)

        ; DEHDL command to add property to group so I can move the group (can't just move the property?)
        cmd = strcat("select Z properties " prop_xy " " prop_xy)
        cnSendCommand(ImportHandle cmd ?runOptions verbose)
        ; move group command
        printf("moving %s to %L\n" cnGetPropName(property) (abs_x:abs_y) )
        cmd = strcat("move Z " cnCreatePointString((abs_x:abs_y)))
        cnSendCommand(ImportHandle cmd ?runOptions verbose)
      )
    )

    ; setting the property visibility to match that of the copied component
    p_vis = cnGetPropVisibility(property)
    unless( (p_vis==visibility); visibility already matches, don't need to do anything
      cond(
        (visibility==0 ; invisible
          printf("visibility is 0. Shouldn't have been able to get here\n")
        )
        (visibility==1 ; value only
          cnSendCommand(ImportHandle "display value Z" ?runOptions verbose)
        )
        (visibility==256 ; name only
          cnSendCommand(ImportHandle "display name Z" ?runOptions verbose)
        )
        (visibility==257 ; name and value
          cnSendCommand(ImportHandle "display both Z" ?runOptions verbose)
        )
        (t)
      )
    )
    t
  )
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