#include "mxrobotdefs.inc"
#include "GTCassettedefs.inc"
#include "GTReporterdefs.inc"

Real m_SP_Alpha(NUM_PUCKS)
Real m_SP_Puck_Radius(NUM_PUCKS)
Real m_SP_Puck_Thickness(NUM_PUCKS)
Real m_SP_PuckCenter_Height(NUM_PUCKS)
Real m_SP_Puck_RotationAngle(NUM_PUCKS)
Real m_SP_Ports_1_5_Circle_Radius
Real m_SP_Ports_6_16_Circle_Radius

Real m_adaptorAngleError(NUM_CASSETTES)

Function initSuperPuckConstants()
	m_SP_Alpha(PUCK_A) = 45.0
	m_SP_Alpha(PUCK_B) = 45.0
	m_SP_Alpha(PUCK_C) = -45.0
	m_SP_Alpha(PUCK_D) = -45.0

	m_SP_Puck_Radius(PUCK_A) = 32.5
	m_SP_Puck_Radius(PUCK_B) = 32.5
	m_SP_Puck_Radius(PUCK_C) = 32.5
	m_SP_Puck_Radius(PUCK_D) = 32.5
	
	m_SP_Puck_Thickness(PUCK_A) = 29.0
	m_SP_Puck_Thickness(PUCK_B) = 29.0
	m_SP_Puck_Thickness(PUCK_C) = -29.0
	m_SP_Puck_Thickness(PUCK_D) = -29.0
	
	m_SP_PuckCenter_Height(PUCK_A) = 102.5
	m_SP_PuckCenter_Height(PUCK_B) = 34.5
	m_SP_PuckCenter_Height(PUCK_C) = 102.5
	m_SP_PuckCenter_Height(PUCK_D) = 34.5
	
	m_SP_Puck_RotationAngle(PUCK_A) = 0.0
	m_SP_Puck_RotationAngle(PUCK_B) = 0.0
	m_SP_Puck_RotationAngle(PUCK_C) = 180.0
	m_SP_Puck_RotationAngle(PUCK_D) = 180.0
	
	m_SP_Ports_1_5_Circle_Radius = 12.12
	m_SP_Ports_6_16_Circle_Radius = 26.31
Fend

'' If distance > 0 then travelDepth is greater than puck thickness
'' distance is the offset from puck's deepest point
Function GTperfectPuckOffset(cassette_position As Integer, portIndex As Integer, puckIndex As Integer, distance As Real, ByRef dx As Real, ByRef dy As Real, ByRef dz As Real, ByRef u As Real)
	'' Horizontal angle from Cassette Center to Puck Center
	Real angle_to_puck_center
	angle_to_puck_center = g_AngleOffset(cassette_position) + g_AngleOfFirstColumn(cassette_position) + m_SP_Alpha(puckIndex) + m_adaptorAngleError(cassette_position)
	
	If (puckIndex = PUCK_A Or puckIndex = PUCK_B) Then
		u = g_UForNormalStandby(cassette_position) + GTBoundAngle(-180, 180, ((angle_to_puck_center - 90) - g_UForNormalStandby(cassette_position)))
	Else	''(puckIndex = PUCK_C Or puckIndex = PUCK_D) Then
		u = g_UForNormalStandby(cassette_position) + GTBoundAngle(-180, 180, ((angle_to_puck_center + 90) - g_UForNormalStandby(cassette_position)))
	EndIf
	
	Real puck_center_x, puck_center_y, puck_center_z
	puck_center_x = m_SP_Puck_Radius(puckIndex) * Cos(DegToRad(angle_to_puck_center))
	puck_center_y = m_SP_Puck_Radius(puckIndex) * Sin(DegToRad(angle_to_puck_center))
	puck_center_z = m_SP_PuckCenter_Height(puckIndex)
	
	Real portCircleRadius, angleBetweenConsecutivePorts
	Real portIndexInCircle
	If portIndex < 5 Then
		portCircleRadius = m_SP_Ports_1_5_Circle_Radius
		angleBetweenConsecutivePorts = 360.0 / 5
		portIndexInCircle = portIndex
	Else
		portCircleRadius = m_SP_Ports_6_16_Circle_Radius
		angleBetweenConsecutivePorts = 360.0 / 11
		portIndexInCircle = portIndex - 5
	EndIf

	'' Vertical angle from Puck Center to Sample Port Center
	Real portAnglefromPuckCenter
	Real HorzDistancePuckCenterToPort, VerticalDistancePuckCenterToPort
	portAnglefromPuckCenter = angleBetweenConsecutivePorts * portIndexInCircle + m_SP_Puck_RotationAngle(puckIndex)
	HorzDistancePuckCenterToPort = portCircleRadius * Cos(DegToRad(portAnglefromPuckCenter))
	VerticalDistancePuckCenterToPort = portCircleRadius * Sin(DegToRad(portAnglefromPuckCenter))
	
	'' Project to World Coordinates
	Real puckCenterToPortCenter_X, puckCenterToPortCenter_Y, puckCenterToPortCenter_Z
	If (puckIndex = PUCK_A Or puckIndex = PUCK_B) Then
		puckCenterToPortCenter_X = HorzDistancePuckCenterToPort * Cos(DegToRad(angle_to_puck_center + 180))
		puckCenterToPortCenter_Y = HorzDistancePuckCenterToPort * Sin(DegToRad(angle_to_puck_center + 180))
	Else	''(puckIndex = PUCK_C Or puckIndex = PUCK_D) Then
		puckCenterToPortCenter_X = HorzDistancePuckCenterToPort * Cos(DegToRad(angle_to_puck_center))
		puckCenterToPortCenter_Y = HorzDistancePuckCenterToPort * Sin(DegToRad(angle_to_puck_center))
	EndIf
	puckCenterToPortCenter_Z = VerticalDistancePuckCenterToPort

	Real travelDepth, travelDepthX, travelDepthY
	If (puckIndex = PUCK_A Or puckIndex = PUCK_B) Then
		travelDepth = m_SP_Puck_Thickness(puckIndex) + distance
	Else	''(puckIndex = PUCK_C Or puckIndex = PUCK_D) Then
		travelDepth = m_SP_Puck_Thickness(puckIndex) - distance
	EndIf
	travelDepthX = travelDepth * Cos(DegToRad(angle_to_puck_center + 90))
	travelDepthY = travelDepth * Sin(DegToRad(angle_to_puck_center + 90))
	
	dx = puck_center_x + puckCenterToPortCenter_X + travelDepthX
	dy = puck_center_y + puckCenterToPortCenter_Y + travelDepthY
	dz = puck_center_z + puckCenterToPortCenter_Z
Fend

'' If distance > 0 then travelDepth is greater than puck thickness
'' distance is the offset from puck's deepest end
Function GTsetSPPortPoint(cassette_position As Integer, portIndex As Integer, puckIndex As Integer, distance As Real, pointNum As Integer)
	Real U
	Real PerfectXoffsetFromCassetteCenter, PerfectYoffsetFromCassetteCenter, PerfectZoffsetFromBottom
	Real AbsoluteXafterTiltAjdust, AbsoluteYafterTiltAjdust, AbsoluteZafterTiltAjdust
	
	GTperfectPuckOffset(cassette_position, portIndex, puckIndex, distance, ByRef PerfectXoffsetFromCassetteCenter, ByRef PerfectYoffsetFromCassetteCenter, ByRef PerfectZoffsetFromBottom, ByRef U)

	GTsetTiltOffsets(cassette_position, PerfectXoffsetFromCassetteCenter, PerfectYoffsetFromCassetteCenter, PerfectZoffsetFromBottom)
	'' Set Absolute X,Y,Z Coordinates after GTsetTiltOffsets
	AbsoluteXafterTiltAjdust = g_CenterX(cassette_position) + g_TiltOffsets(0)
	AbsoluteYafterTiltAjdust = g_CenterY(cassette_position) + g_TiltOffsets(1)
	AbsoluteZafterTiltAjdust = g_BottomZ(cassette_position) + g_TiltOffsets(2)

	P(pointNum) = XY(AbsoluteXafterTiltAjdust, AbsoluteYafterTiltAjdust, AbsoluteZafterTiltAjdust, U) /R
Fend

Function GTgetAdaptorAngleErrorProbePoint(cassette_position As Integer, standbyPointNum As Integer, ByRef perfectX As Real, ByRef perfectY As Real, ByRef perfectZ As Real, ByRef perfectU As Real)
	Real angle_to_puck_center
	angle_to_puck_center = g_AngleOffset(cassette_position) + g_AngleOfFirstColumn(cassette_position) + m_SP_Alpha(PUCK_A)
	
	perfectU = g_UForNormalStandby(cassette_position) + GTBoundAngle(-180, 180, ((angle_to_puck_center - 90) - g_UForNormalStandby(cassette_position)))
	
	Real puck_center_x, puck_center_y, puck_center_z
	puck_center_x = SUPERPUCK_WIDTH * Cos(DegToRad(angle_to_puck_center))
	puck_center_y = SUPERPUCK_WIDTH * Sin(DegToRad(angle_to_puck_center))
	puck_center_z = m_SP_PuckCenter_Height(PUCK_A)
	
	Real travelDepth, travelDepthX, travelDepthY
	travelDepth = m_SP_Puck_Thickness(PUCK_A)
	travelDepthX = travelDepth * Cos(DegToRad(angle_to_puck_center + 90))
	travelDepthY = travelDepth * Sin(DegToRad(angle_to_puck_center + 90))
	
	Real dx, dy, dz
	dx = (puck_center_x + travelDepthX) * CASSETTE_SHRINK_IN_LN2
	dy = (puck_center_y + travelDepthY) * CASSETTE_SHRINK_IN_LN2
	dz = puck_center_z * CASSETTE_SHRINK_IN_LN2
	
	GTsetTiltOffsets(cassette_position, dx, dy, dz)
	perfectX = g_CenterX(cassette_position) + g_TiltOffsets(0)
	perfectY = g_CenterY(cassette_position) + g_TiltOffsets(1)
	perfectZ = g_BottomZ(cassette_position) + g_TiltOffsets(2)
		
	'' Set standby point
	Real sinU, cosU, standbyXoffset, standbyYoffset
	sinU = Sin(DegToRad(perfectU)); cosU = Cos(DegToRad(perfectU))
	standbyXoffset = PROBE_STANDBY_DISTANCE * cosU
	standbyYoffset = PROBE_STANDBY_DISTANCE * sinU
	P(standbyPointNum) = XY(perfectX - standbyXoffset, perfectY - standbyYoffset, perfectZ, perfectU) /R
Fend


Function GTprobeAdaptorAngleCorrection(cassette_position As Integer) As Boolean
	GTUpdateClient(TASK_ENTERED_REPORT, MID_LEVEL_FUNCTION, "GTprobeAdaptorAngleCorrection(" + GTCassetteName$(cassette_position) + ")")

	Integer standbyPoint
	Real perfectX, perfectY, perfectZ, perfectU

	standbyPoint = 52
	GTgetAdaptorAngleErrorProbePoint(cassette_position, standbyPoint, ByRef perfectX, ByRef perfectY, ByRef perfectZ, ByRef perfectU)

	Tool 2
	LimZ g_Jump_LimZ_LN2
	
	Jump P(standbyPoint)
	
	Real scanDistance
	scanDistance = PROBE_STANDBY_DISTANCE + PROBE_ADAPTOR_DISTANCE
	
	If Not ForceTouch(DIRECTION_CAVITY_TAIL, scanDistance, True) Then
		GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTprobeAdaptorAngleCorrection failed: error in ForceTouch!")
		GTprobeAdaptorAngleCorrection = False
		Exit Function
	EndIf




	GTprobeAdaptorAngleCorrection = True
Fend

