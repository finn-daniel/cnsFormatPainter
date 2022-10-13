

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
  printf("test\n")
  xy = cnGetMouseXY(event)
  coord = set(coord xy)
  printf("Clicked coordinate: %L\n",coord)
)

procedure( formatPainter()
  let(
    ; local variable declarations
    (
      cmd_ret_obj prm_obj_set prop_obj_set
    )
    ; send "select all" command to DEHDL
    ; cmd_ret_obj=cnSendCommand(ImportHandle "select properties all" ?runOptions verbose)
    mouse_coord=nil
    cnRequestMousePress(ImportHandle, `getMouseButtonCallback, `mouse_coord, "click on a component")
    ; wait for the callback to finish
    while((mouse_coord==nil)
      cnmpsSleep(ImportHandle 1)
      ; TODO: get user input in this loop so i don't get stuck
    )
    ; TODO: select components within bounding box?
    topLeft = nth(0 mouse_coord)-100 : nth(1 mouse_coord)+100
    botRight = nth(0 mouse_coord)+100 : nth(1 mouse_coord)-100
    cmd = strcat("select A bodies " cnCreatePointString(topLeft) " " cnCreatePointString(botRight))

    dwgId=cnGetDwgId(cnFindActiveDwg(cnGetDwgInfo(ImportHandle)))

    ; cmd_ret_obj=cnSendCommand(ImportHandle cmd ?runOptions verbose)
    cmd_ret_obj=cnSendCommand(ImportHandle cmd ?runOptions verbose)
    printf("command return object length: %d\n" length(cmd_ret_obj))
    printf("%L\n" cmd_ret_obj)

    ; extract primitive object set from response
    ; prm_obj_set=cnGetAddedObjectSet(cmd_ret_obj, dwgId)
    prm_obj_set=cnGetGroupedObjectSet(cmd_ret_obj)
    printf("primitive object set length %d\n", length(prm_obj_set))

    ; get a list of properties from the primitive object set
    comp_obj_set=cnGetComps(prm_obj_set)
    ; prop_obj_set=cnGetProps(prm_obj_set)
    ; printf("property object set length %d\n", length(prop_obj_set))
    printf("component object set length %d\n", length(comp_obj_set))

    foreach(comp comp_obj_set
      printf("name: %s\n" cnGetCompName(comp))
      printf("loc: %L\n" cnGetCompOriginXY(comp))
    )
    ; TODO: select all of the properties in the drawing and loop through each to check
    ; if their owner is the above component.
    ; if the property is visible, save its relative XY location.
    ; selecting a different component, look for the same property name and set its visibility and
    ; relative xy.

    ; loop through each propery
    ; foreach(property prop_obj_set
    ;   ; check if the property's owner is a component
    ;   if(cnGetPropOwnerType(property)==cnOWNER_COMP then
    ;     ; extract name, value, owner 
    ;     name=cnGetPropName(property)
    ;     value=cnGetPropValue(property)
    ;     owner_dbid=cnGetPropOwnerDbId(property)
    ;     cmd=strcat("group " cnCreateDbIdString(owner_dbid))
    ;     cmd_ret_obj=cnSendCommand(ImportHandle cmd ?runOptions verbose)
    ;     groupName=cnGetGroupName(cmd_ret_obj)
    ;     prm_obj_set=cnGetGroupedObjectSet(cmd_ret_obj)
    ;     comp_obj=nth(0 cnGetComps(prm_obj_set))
    ;     comp_name=cnGetCompName(comp_obj)
    ;     comp_location=cnGetCompOriginXY(comp_obj)
    ;     printf("%s %L %s %L\n" name value comp_name comp_location)
    ;     cnSendCommand(ImportHandle strcat("exclude " groupName " " groupName))
    ;   )
    ; )
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