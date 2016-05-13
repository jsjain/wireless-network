#include <stdio.h>
#include <string.h>
#include <Timer.h>
#include "printf.h"
#include "MoteToMote.h"
#define NODE_ID 100
// Id of each node to be hardcoded .
module TestTemp2C
{
	
	uses 
	{
		// general interfaces
		interface Boot;
		interface Alarm<TMilli, u_int32_t>;
		//interface Alarm<TMilli, u_int32_t> as Alarm0;
		interface Timer<TMilli> as Timer0;
		interface Timer<TMilli> as Timer1;
		interface Leds;
		interface Init;
		
		//Read
		
	}

		uses //Radio
	{
		interface Packet;
		interface AMPacket;
		interface AMSend;
		interface SplitControl as ComControl;
		interface Receive;	
	
	}
}

implementation
{
	message_t packet;
	uint8_t val;
	uint8_t length;
	bool busy = FALSE;
	uint32_t time_now;
	uint32_t tf;
	u_int32_t mint;
	u_int32_t h;
	u_int32_t m;
	u_int32_t s;
	
	
	event void Boot.booted()
	{
		mint = 0;
		call Leds.led0On();
		call Timer0.startPeriodic(1000);
		call Timer1.startOneShot(1000);

		call ComControl.start();
		call Alarm.start(61440);	
	}

	
	event void Timer0.fired()
	{
		u_int32_t sec = (call Alarm.getNow())/1024;
		u_int32_t min = sec /60;
		u_int32_t hour = min /60;
		printf("Current Time %ld:%ld:%ld\n", hour, min%60, sec%60);
	}	
	
	
	
	
	event void Timer1.fired()
	{
		time_now = call Alarm.getNow();
		//printf("in alarm0 fired");
		if(busy == FALSE)
		{

			TimeMote_t* timesyncpacket = call Packet.getPayload( &packet, sizeof(TimeMote_t));
			timesyncpacket->NodeID = NODE_ID+1;
			timesyncpacket->tdata = time_now;
			timesyncpacket->mint = mint;
			timesyncpacket->check = FALSE;
			
			printf("packet sent %ld tdata",timesyncpacket->tdata);
			
			length = sizeof(TimeMote_t);
			 
			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(TimeMote_t)) == SUCCESS) 
			{
				busy = TRUE;
			
			}
		}
		call Alarm.start(61440);
		// this alarm is to start again after syncing time with other motes after the specified time
		call Timer1.stop();
	}
	
	async event void Alarm.fired()
	{
		mint++;
		time_now = call Alarm.getNow();
		//printf("in alarm fired");
		if(busy == FALSE)
		{
			TimeMote_t* timesyncpacket = call Packet.getPayload( &packet, sizeof(TimeMote_t));
			timesyncpacket->NodeID = NODE_ID+1;
			timesyncpacket->tdata = time_now;
			timesyncpacket->mint = mint;
			timesyncpacket->check = FALSE;
			
			length = sizeof(TimeMote_t);
			 
			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(TimeMote_t)) == SUCCESS) 
			{
				busy = TRUE;
			}
		}
		call Alarm.start(61440);
	}

	event void ComControl.startDone(error_t error){
		
		if (error == SUCCESS) {
			call Leds.led1Toggle(); // Green LED
		}
		else
		{
			call Leds.led1Off();
			call ComControl.start();
		}
	}

	event void ComControl.stopDone(error_t error)
	{		
	}


	event message_t * Receive.receive(message_t *msg, void *payload, uint8_t len)
	{
		length = len;
		//printf("length = %d\nMiner = %d\n mote = %d\n",len, sizeof(MinerToMoteMsg_t), sizeof(MoteToMoteMsg_t));
		// This is to get packet from Miner, append its Node ID.
		
		if(len == sizeof(MinerToMoteMsg_t)) 
		{		
			s = (call Alarm.getNow())/1024;
			m = s /60;
			h = m /60;
			//outgoingPacket -> time = (call Timer1.getNow() + offset - oldtime);
			printf(" Worker Node ID : %d\n at Time : %ld:%ld:%ld\n Original ID : 100", ((MinerToMoteMsg_t*) payload)->Data, h, m, s%60); // this will print worker's ID.
			
			if(((MinerToMoteMsg_t*) payload)->sos == TRUE)
			{
				printf("DISTRESS SIGNAL at Node: %d\n", NODE_ID);
			}
			
			if(busy == FALSE) 
			{
				if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(MoteToMoteMsg_t)) == SUCCESS) 
				{
					busy = TRUE;
					//call Leds.led2Toggle();
					//printf("miner\n");
				}
			}
		}
		
		else if (len == sizeof(MoteToMoteMsg_t))
		{
			
			//printf("comparing %d < %d : ", NODE_ID, ((MoteToMoteMsg_t*) payload)->NodeID);
			printf("Original Node ID : %d", ((MoteToMoteMsg_t*) payload)->ONodeID);
			// this will print the node ID of mote tracking the miner.
			
			s = ((MoteToMoteMsg_t*) payload)->time / 1024;
			m = s /60;
			h = m /60;
			
			printf(" Worker Node ID : %d\n Time : %ld:%ld:%ld", ((MoteToMoteMsg_t*) payload)->Data, h, m%60, s%60); // this will print worker's ID.
			if(NODE_ID < ((MoteToMoteMsg_t*) payload)->NodeID) 
			{
				
				MoteToMoteMsg_t* outgoingPacket = call Packet.getPayload( &packet, sizeof(MoteToMoteMsg_t));
				outgoingPacket->ONodeID = ((MoteToMoteMsg_t*) payload)->ONodeID;
				outgoingPacket->NodeID = NODE_ID;
				outgoingPacket->Data = ((MoteToMoteMsg_t*) payload)->Data;
				outgoingPacket->sos = ((MoteToMoteMsg_t*) payload)->sos;
				printf("Sending\n");
				
				if(outgoingPacket->sos == TRUE)
				{
					printf("DISTRESS SIGNAL at Node: %d\n at Time : %ld", outgoingPacket->ONodeID,((MoteToMoteMsg_t*) payload)->time);
				}
				
				if(busy == FALSE) 
				{
					if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(MoteToMoteMsg_t)) == SUCCESS) 
					{
						busy = TRUE;
						//printf("Data received from mote\n");
					}
				}
			}
		}

		else if (len == sizeof(TimeMote_t) && ((TimeMote_t*) payload)->check == TRUE && NODE_ID == (((TimeMote_t*) payload)->NodeID))
		{
			printf("Data received with check\n");
			tf = (3*call Alarm.getNow()-time_now)/2;
			
			if(busy == FALSE) 
			{
				TimeMote_t* timesyncpacket = call Packet.getPayload( &packet, sizeof(TimeMote_t));
				timesyncpacket->NodeID = NODE_ID+1;
				timesyncpacket->tdata = tf;
				timesyncpacket->mint = mint;
				timesyncpacket->check = TRUE;
				
				printf("Sent final packet with offset %ld \n",tf);
		
				length = sizeof(TimeMote_t);
			
				if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(TimeMote_t)) == SUCCESS) 
				{
					busy = TRUE;

				}
			}
		}

		//else printf("Data received from worker.\n");
	
		
		return msg;
	}
	
	event void AMSend.sendDone(message_t *msg, error_t error)
	{
		if(error == SUCCESS && msg == &packet)
		{
			busy = FALSE;
			//printf("this is packet sent successfully");
		}
		if(error == FAIL && msg == &packet )
		{
			call Leds.led0Toggle();
			if(length != sizeof(TimeMote_t)) call AMSend.send(AM_BROADCAST_ADDR, &packet, length);
			busy = FALSE;
			call Leds.led0Toggle();
			//printf("this is packet sent");
		}
	}

}