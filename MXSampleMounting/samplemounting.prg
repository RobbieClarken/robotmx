#include "networkdefs.inc"
#include "mountingdefs.inc"

Function GTGonioReachable() As Boolean
	'' Check if robot can reach goniometer
	GTGonioReachable = True
Fend

Function GTSetGoniometerPoints(dx As Real, dy As Real, dz As Real, du As Real) As Boolean

	'' P21 is the real goniometer point which will be used for robot movement
	P21 = P20 +X(dx) +Y(dy) +Z(dz) +U(du)

	'' P24 is the point	to move to detach goniometer head along gonio orientation
	Real detachDX, detachDY
	detachDX = GONIO_MOUNT_STANDBY_DISTANCE * g_goniometer_cosValue
	detachDY = GONIO_MOUNT_STANDBY_DISTANCE * g_goniometer_sinValue
	P24 = P21 +X(detachDX) +Y(detachDY)

	'' P23 downstream shift from P21. P23 is the dismount standby point
	Real sideStepDX, sideStepDY
	sideStepDX = GONIO_DISMOUNT_SIDEMOVE_DISTANCE * g_goniometer_cosValue
	sideStepDY = GONIO_DISMOUNT_SIDEMOVE_DISTANCE * g_goniometer_sinValue
	P23 = P21 +X(sideStepDX) +Y(sideStepDY)
	
	'' X,Y coordinates of P22 is the corner of the rectangle P24-P21-P23
	'' P22 is the Mount/Dismount point on Gonio
	P23 = P21 +X(detachDX + sideStepDX) +Y(detachDY + sideStepDY) :Z(-1)
	
	If Not GTGonioReachable Then
		String msg$
		msg$ = "GTSetGoniometerPoints: GTGonioReachable returned false!"
		UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
		GTSetGoniometerPoints = False
		Exit Function
	EndIf
	
	'' Setup P28 and P38 so that we can move smoothly from P18 to P22 using ARC
	'' i.e. ARC P18-P28-P38, then move to P22
	Real ArcToGonioDX, ArcToGonioDY
	ArcToGonioDX = Abs(CX(P22) - CX(P18))
	ArcToGonioDY = Abs(CY(P22) - CY(P18))
	
	'' we will move along axes and will move the shorter distance first
	Real arcMidX, arcMidY, arcMidZ, arcMidU
	Real arcEndX, arcEndY, arcEndZ, arcEndU
	Real sin45
	sin45 = Sin(DegToRad(45))
	
	If (ArcToGonioDX > ArcToGonioDY) Then
		If (CX(P18) > CX(P22)) And (CY(P18) > CY(P22)) Then
			arcMidX = CX(P18) - (1.0 - sin45) * (CY(P18) - CY(P22))
			arcEndX = CX(P18) - (CY(P18) - CY(P22))
		ElseIf (CX(P18) > CX(P22)) And (CY(P18) < CY(P22)) Then
			arcMidX = CX(P18) + (1.0 - sin45) * (CY(P18) - CY(P22))
			arcEndX = CX(P18) + (CY(P18) - CY(P22)) ''check
		ElseIf (CX(P18) < CX(P22)) And (CY(P18) > CY(P22)) Then
			arcMidX = CX(P18) + (1.0 - sin45) * (CY(P18) - CY(P22))
			arcEndX = CX(P18) + (CY(P18) - CY(P22))
		ElseIf (CX(P18) < CX(P22)) And (CY(P18) < CY(P22)) Then
			arcMidX = CX(P18) - (1.0 - sin45) * (CY(P18) - CY(P22))
			arcEndX = CX(P18) - (CY(P18) - CY(P22))
		EndIf

		arcMidY = CY(P18) - sin45 * (CY(P18) - CY(P22))
		arcEndY = CY(P22)
 	Else
		If (CX(P18) > CX(P22)) And (CY(P18) > CY(P22)) Then
			arcMidY = CY(P18) - (1.0 - sin45) * (CX(P18) - CX(P22))
			arcEndY = CY(P18) - (CX(P18) - CX(P22))
		ElseIf (CX(P18) > CX(P22)) And (CY(P18) < CY(P22)) Then
			arcMidY = CY(P18) + (1.0 - sin45) * (CX(P18) - CX(P22))
			arcEndY = CY(P18) + (CX(P18) - CX(P22))
		ElseIf (CX(P18) < CX(P22)) And (CY(P18) > CY(P22)) Then
			arcMidY = CY(P18) + (1.0 - sin45) * (CX(P18) - CX(P22))
			arcEndY = CY(P18) + (CX(P18) - CX(P22))
		ElseIf (CX(P18) < CX(P22)) And (CY(P18) < CY(P22)) Then
			arcMidY = CY(P18) - (1.0 - sin45) * (CX(P18) - CX(P22))
			arcEndY = CY(P18) - (CX(P18) - CX(P22))
		EndIf

		arcMidX = CX(P18) - sin45 * (CX(P18) - CX(P22))
		arcEndX = CX(P22)
	EndIf
	
	arcMidZ = CZ(P18)
	arcMidU = (CU(P18) + CU(P22)) / 2.0
	arcEndZ = CZ(P18)
	arcEndU = CU(P22)

	'' Assign the values to P28 and P38
	P28 = XY(arcMidX, arcMidY, arcMidZ, arcMidU)
	P38 = XY(arcEndX, arcEndY, arcEndZ, arcEndU)

	GTSetGoniometerPoints = True
Fend

Function GTMoveToSPMountPortStandbyPoint(cassette_position As Integer, puckIndex As Integer, puckPortIndex As Integer)
	'' This move should be called only after picking magnet from cradle
	
	GTsetSPMountStandbyPoints(cassette_position, puckIndex, puckPortIndex, PORT_MOUNT_READY_DISTANCE)
		
	Integer SPStandbyPoint, SPStandbyToPortStandbyArcPoint, SPSecondaryArcPoint, puckPortStandbyPoint
	SPStandbyPoint = 50
	SPStandbyToPortStandbyArcPoint = 51
	SPSecondaryArcPoint = 55
	puckPortStandbyPoint = 52 '' destination point
	
	''Check the following whether toolsets need to be changed before moving
	Move P(SPStandbyPoint)
	
	'' GTsetSPMountStandbyPoints sets P(SPStandbyToPortStandbyArcPoint) and P(SPSecondaryArcPoint) to 0,0,0,0 if Arc is not required
	If CheckPoint(SPStandbyToPortStandbyArcPoint) And CheckPoint(SPSecondaryArcPoint) Then
		Arc P(SPStandbyToPortStandbyArcPoint), P(SPSecondaryArcPoint) CP
	EndIf

	Move P(puckPortStandbyPoint)
Fend

Function GTMoveToCassetteMountPortStandbyPoint(cassette_position As Integer, rowIndex As Integer, columnIndex As Integer)
	'' This move should be called only after picking magnet from cradle
	
	GTsetCassetteMountStandbyPoints(cassette_position, rowIndex, columnIndex, PORT_MOUNT_READY_DISTANCE)
	
	Integer cassetteStandbyPoint, casStandbyToPortStandbyArcPoint, portStandbyPoint
	cassetteStandbyPoint = 50
	casStandbyToPortStandbyArcPoint = 51
	portStandbyPoint = 52
	
	''Check the following whether toolsets need to be changed before moving
	Move P(cassetteStandbyPoint)
	
	'' Arc is not required is cassetteStandbyPoint to portStandbyPoint is less than 5degrees in angle
	If Abs(CU(P(portStandbyPoint)) - CU(P(cassetteStandbyPoint)) > 5.0) Then
		Arc P(casStandbyToPortStandbyArcPoint), P(portStandbyPoint)
	Else
		Move P(portStandbyPoint)
	EndIf
Fend


