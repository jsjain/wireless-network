#ifndef MOTE_TO_MOTE_H
#define MOTE_TO_MOTE_H

typedef nx_struct MoteToMoteMsg {
	
	nx_int16_t NodeID;
	nxle_uint8_t Data;
	nx_int16_t ONodeID;  //original node where worker was tracked initially.
	nx_bool sos;
	nxle_uint32_t time;
	
} MoteToMoteMsg_t;

typedef nx_struct MinerToMoteMsg {
	
	nxle_uint8_t Data;
	nx_bool sos;
	nxle_uint32_t time;
	
} MinerToMoteMsg_t;

typedef nx_struct TimeMote {
	
	nx_int16_t NodeID;
	nxle_uint32_t tdata; // time data
	nxle_uint32_t mint; // local time to be synced 
	nx_bool check; // 0 for getting delay 1 for setting time
	
} TimeMote_t;

enum {
	AM_RADIO = 6
};

#endif /* MOTE_TO_MOTE_H */
