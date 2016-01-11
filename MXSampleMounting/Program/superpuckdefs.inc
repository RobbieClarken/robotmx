'' SuperPuck/PuckAdaptor Properties
#define SUPERPUCK_WIDTH 72.0
#define SUPERPUCK_HEIGHT 137.0
#define SP_EDGE_THICKNESS 6.0
#define SP_CENTER_TO_PUCK_CENTER_LENGTH 33.5 ''SUPERPUCK_WIDTH-(m_SP_Puck_Radius+SP_EDGE_THICKNESS)

#define PUCK_A 0
#define PUCK_B 1
#define PUCK_C 2
#define PUCK_D 3
#define NUM_PUCKS 4

#define NUM_PUCK_PORTS 16

'' Puck Status
#define PUCK_PRESENT -1
#define PUCK_UNKNOWN 0
#define PUCK_ABSENT 1
#define PUCK_JAM 2

#define PROBE_ADAPTOR_DISTANCE 3.0

#define UNDERPRESS_DISTANCE_FOR_PUCK -0.8
#define OVERPRESS_DISTANCE_FOR_PUCK 0.8

'' Distance from puck surface to sample surface if pin deep in puck
#define SAMPLE_DIST_PIN_DEEP_IN_PUCK 2.5
#define TOLERANCE_FROM_PIN_DEEP_IN_PUCK 0.6
'' PROBE_DISTANCE_FOR_PUCK_PORT = PIN_DEEP_IN_PUCK_DISTANCE + TOLERANCE_FROM_PIN_DEEP_IN_PUCK
#define PROBE_DISTANCE_FOR_PUCK_PORT 3.3

#define PROBE_DISTANCE_TOLERANCE 0.4