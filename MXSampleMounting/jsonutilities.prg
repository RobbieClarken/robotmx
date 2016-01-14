#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"
#include "jsondefs.inc"

Function PortStatusString$(PortStatus As Integer) As String
	Select PortStatus
		Case PORT_OCCUPIED
			PortStatusString$ = "PRESE"
		Case PORT_VACANT
			PortStatusString$ = "VACAN"
		Case PORT_ERROR
			PortStatusString$ = "ERROR"
		Default
			PortStatusString$ = "UNKNO"
	Send
Fend

Function PuckStatusString$(PuckStatus As Integer) As String
	Select PuckStatus
		Case PUCK_PRESENT
			PuckStatusString$ = "PRESE"
		Case PUCK_ABSENT
			PuckStatusString$ = "VACAN"
		Case PUCK_JAM
			PuckStatusString$ = "ERROR"
		Default
			PuckStatusString$ = "UNKNO"
	Send
Fend

Function GTsendCassetteData(dataToSend As Integer, cassette_position As Integer)
	String JSONResponse$
	Integer portsPerJSONPacket, numJSONPackets, responseJSONPacketIndex
	Integer startPortIndex, endPortIndex, portIndex
	Integer columnIndex, rowIndex
	Integer puckIndex, puckPortIndex

	portsPerJSONPacket = 24
	numJSONPackets = (NUM_ROWS * NUM_COLUMNS) / portsPerJSONPacket
	
	For responseJSONPacketIndex = 0 To numJSONPackets - 1
		startPortIndex = responseJSONPacketIndex * portsPerJSONPacket
		endPortIndex = (responseJSONPacketIndex + 1) * portsPerJSONPacket - 1
		
		If dataToSend = SAMPLE_PORT_STATUS Then
			JSONResponse$ = "{'set':'sample_port_status'"
		ElseIf dataToSend = SAMPLE_DISTANCE_ERROR Then
			JSONResponse$ = "{'set':'sample_distance_error'"
		Else
			UpdateClient(TASK_MSG, "Invalid dataToSend Request!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		JSONResponse$ = JSONResponse$ + ",'type':" + Str$(g_CassetteType(cassette_position))
		JSONResponse$ = JSONResponse$ + ",'start':" + Str$(startPortIndex) + ",'end':" + Str$(endPortIndex) + ",'value':["
		For portIndex = startPortIndex To endPortIndex
			columnIndex = portIndex / NUM_ROWS
			rowIndex = portIndex - (columnIndex * NUM_ROWS)
			
			If dataToSend = SAMPLE_PORT_STATUS Then
				JSONResponse$ = JSONResponse$ + PortStatusString$(g_CAS_PortStatus(cassette_position, rowIndex, columnIndex)) + ","
			ElseIf dataToSend = SAMPLE_DISTANCE_ERROR Then
				JSONResponse$ = JSONResponse$ + FmtStr$(g_CASSampleDistanceError(cassette_position, rowIndex, columnIndex), "0.000") + ","
			EndIf
		Next
		JSONResponse$ = JSONResponse$ + "]}"

		UpdateClient(CLIENT_UPDATE, JSONResponse$, INFO_LEVEL)
	Next

Fend

Function GTsendSuperPuckData(dataToSend As Integer, cassette_position As Integer)
	String JSONResponse$
	Integer portsPerJSONPacket, numJSONPackets, responseJSONPacketIndex
	Integer startPortIndex, endPortIndex, portIndex
	Integer puckIndex, puckPortIndex
	
	portsPerJSONPacket = 16 '' One packet for each puck
	numJSONPackets = NUM_PUCKS
	
	For responseJSONPacketIndex = 0 To numJSONPackets - 1
		startPortIndex = responseJSONPacketIndex * portsPerJSONPacket
		endPortIndex = (responseJSONPacketIndex + 1) * portsPerJSONPacket - 1
		
		If dataToSend = SAMPLE_PORT_STATUS Then
			JSONResponse$ = "{'set':'sample_port_status'"
		ElseIf dataToSend = SAMPLE_DISTANCE_ERROR Then
			JSONResponse$ = "{'set':'sample_distance_error'"
		Else
			UpdateClient(TASK_MSG, "Invalid dataToSend Request!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		JSONResponse$ = JSONResponse$ + ",'type':" + Str$(g_CassetteType(cassette_position))
		JSONResponse$ = JSONResponse$ + ",'start':" + Str$(startPortIndex) + ",'end':" + Str$(endPortIndex) + ",'value':["
		puckIndex = responseJSONPacketIndex
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			If dataToSend = SAMPLE_PORT_STATUS Then
				JSONResponse$ = JSONResponse$ + PortStatusString$(g_SP_PortStatus(cassette_position, puckIndex, puckPortIndex)) + ","
			ElseIf dataToSend = SAMPLE_DISTANCE_ERROR Then
				JSONResponse$ = JSONResponse$ + FmtStr$(g_SPSampleDistanceError(cassette_position, puckIndex, puckPortIndex), "0.000") + ","
			EndIf
		Next
		JSONResponse$ = JSONResponse$ + "]}"

		UpdateClient(CLIENT_UPDATE, JSONResponse$, INFO_LEVEL)
	Next

Fend

Function GTsendPuckData(cassette_position As Integer)
	String JSONResponse$
	Integer puckIndex
	
	JSONResponse$ = "{'set':'puck_status'"
	JSONResponse$ = JSONResponse$ + ",'position':" + Str$(cassette_position)
	JSONResponse$ = JSONResponse$ + ",'value':["
	For puckIndex = 0 To NUM_PUCKS - 1
		JSONResponse$ = JSONResponse$ + PuckStatusString$(g_PuckStatus(cassette_position, puckIndex)) + ","
	Next
	JSONResponse$ = JSONResponse$ + "]}"

	UpdateClient(CLIENT_UPDATE, JSONResponse$, INFO_LEVEL)
Fend

Function GTsendJSONResponse(dataToSend As Integer, cassette_position As Integer)
	If (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Or (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
		GTsendCassetteData(dataToSend, cassette_position)
	ElseIf g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		If dataToSend = PUCK_STATUS Then
			GTsendPuckData(cassette_position)
		Else
			GTsendSuperPuckData(dataToSend, cassette_position)
		EndIf
	EndIf
Fend
