#include<stdio.h>
#include<string.h>
#include<Timer.h>
#include "printf.h"
#include"MoteToMote.h"
#define NODE_ID 107
// Id of each node to be hard-coded
module TestTemp2C
{
	
	uses 
	{
		// general interfaces
		interface Boot;
		interface Leds;
		//interface Alarm<TMilli, u_int32_t>;
		interface Init;
		interface Timer<TMilli> as Timer0;
		interface Timer<TMilli> as Timer1;
		
		interface LocalTime<TMilli>;
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
	u_int32_t sec;
	uint32_t tf;
	u_int32_t mint;
	bool synced;
	uint32_t offset;
	uint32_t oldtime;
	//bool formm;

	
	event void Boot.booted()
	{
		mint = 0;
		synced = FALSE;
		call Leds.led0On();
		call ComControl.start();
		call Timer0.startPeriodic(1000);
	//	formm = TRUE;
		//printf("time after boot is %ld",call Timer1.getNow());
		//printfflush();
		//printf("len of %d %d %d ",sizeogetNowf(MinerToMoteMsg_t),sizeof(MoteToMoteMsg_t), sizeof(TimeMote_t));
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
			MoteToMoteMsg_t* outgoingPacket = call Packet.getPayload( &packet, sizeof(MoteToMoteMsg_t));
			outgoingPacket -> NodeID = NODE_ID;
			outgoingPacket -> ONodeID = NODE_ID;
			outgoingPacket -> Data = ((MinerToMoteMsg_t*) payload)->Data;
			outgoingPacket -> sos = ((MinerToMoteMsg_t*) payload)->sos;
			outgoingPacket -> time = tf;
			
			if(outgoingPacket->sos == TRUE)
			{
				printf("DISTRESS SIGNAL at Node: %d\n", outgoingPacket->ONodeID);
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
			
			printf("comparing %d < %d : ", NODE_ID, ((MoteToMoteMsg_t*) payload)->NodeID);
			printf("Original Node ID : %d", ((MoteToMoteMsg_t*) payload)->ONodeID);
			// this will print the node ID of mote tracking the miner.
			printf(" Worker Node ID : %d\n", ((MoteToMoteMsg_t*) payload)->Data); // this will print worker's ID.
			if(NODE_ID < ((MoteToMoteMsg_t*) payload)->NodeID) 
			{
				
				MoteToMoteMsg_t* outgoingPacket = call Packet.getPayload( &packet, sizeof(MoteToMoteMsg_t));
				outgoingPacket->ONodeID = ((MoteToMoteMsg_t*) payload)->ONodeID;
				outgoingPacket->NodeID = NODE_ID;
				outgoingPacket->Data = ((MoteToMoteMsg_t*) payload)->Data;
				outgoingPacket->sos = ((MoteToMoteMsg_t*) payload)->sos;
				outgoingPacket -> time = (call LocalTime.get() + offset - oldtime);
				//printf("Sending\n");
				
				if(outgoingPacket->sos == TRUE)
				{
					printf("DISTRESS SIGNAL at Node: %d\n", outgoingPacket->ONodeID);
				}
				
				if(busy == FALSE) 
				{
					if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(MoteToMoteMsg_t)) == SUCCESS) 
					{
						busy = TRUE;
						//printf ("Data received from mote\n");
					}
				}
			}
		}
			
		else if (len == sizeof(TimeMote_t))
		{
			printf("nodeId : %d\n",((TimeMote_t*) payload)->NodeID);
			printf("tdata : %ld\n",((TimeMote_t*) payload)->tdata);
			printf("mint : %ld\n",((TimeMote_t*) payload)->mint);
			if(((TimeMote_t*) payload)->check) printf(" check : TRUE\n");
			else printf ("check : FAPLSE\n");

			if(((TimeMote_t*) payload)->check == FALSE && (NODE_ID == (((TimeMote_t*) payload)->NodeID)))
			{
				synced = FALSE;
			}
			if(synced == FALSE)
			{
				printf("in sync FALSE part\n");
				if(((TimeMote_t*) payload)->check == FALSE && (NODE_ID == (((TimeMote_t*) payload)->NodeID)))
				{
					if ( busy == FALSE )
					{
						TimeMote_t* timesyncpacket = call Packet.getPayload( &packet, sizeof(TimeMote_t));
						timesyncpacket->NodeID = NODE_ID-1;
						timesyncpacket->tdata = tf;
						timesyncpacket->mint = mint;
						timesyncpacket->check = TRUE;
					//	timesyncpacket->formm = TRUE;
				
						//length = sizeof(TimeMote_t);
						//printf ("tdata is %ld tf is %d",timesyncpacket->tdata, tf);
					
						if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(TimeMote_t)) == SUCCESS) 
						{
							busy = TRUE;
							printf("received and sending to get synced");
	
						}
					}
				}
				else if(((TimeMote_t*) payload)->check == TRUE && (NODE_ID == (((TimeMote_t*) payload)->NodeID)))
				{
					
					
					u_int32_t min;
					u_int32_t hour;
					mint = ((TimeMote_t*) payload)->mint;
					offset = ((TimeMote_t*) payload)->tdata;
					oldtime = call LocalTime.get();
					call Timer1.startPeriodic(offset);
					printf("tdata after check true is %ld\nand offset %ld\nand %ld\n",((TimeMote_t*) payload)->tdata,offset,oldtime);
					

					synced = TRUE;
					//printf("synced time is %ld\n\n", ((TimeMote_t*) payload)->tdata);
					
					 // now acting as main mote for others
					 
					sec = ((call LocalTime.get() - oldtime + offset)/1024);
					time_now = call LocalTime.get();
					min = sec /60;
					hour = min /60;
					printf("Current synched Time is :%ld:%ld:%ld\n", hour, min%60, sec%60);
					
					if(busy == FALSE)
					{
						TimeMote_t* timesyncpacket = call Packet.getPayload( &packet, sizeof(TimeMote_t));
						timesyncpacket->NodeID = NODE_ID+1;
						timesyncpacket->tdata = offset;
						timesyncpacket->mint = mint;
						timesyncpacket->check = FALSE;
					//	timesyncpacket->formm = FALSE;
						
						length = sizeof(TimeMote_t);
						printf("offset sent to next mote is %ld\n",offset);
						 
						if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(TimeMote_t)) == SUCCESS) 
						{
							busy = TRUE;
							printf("Successfully sent to 102\n");
						}
						
					}
				}
			}
			else if(synced == TRUE)
			{
				printf("checking in\n%d",((TimeMote_t*) payload)->NodeID);

				// added check for main mote is false
				if (((TimeMote_t*) payload)->check == TRUE && NODE_ID == (((TimeMote_t*) payload)->NodeID))
				{
					printf("Data received with check\nbusy is %b",busy);
					//tf = sec+(3*call LocalTime.get()-time_now)/2;
					tf = offset+(3*(call LocalTime.get()-time_now)/2);
					
					if(busy == FALSE) 
					{
						TimeMote_t* timesyncpacket = call Packet.getPayload( &packet, sizeof(TimeMote_t));
						timesyncpacket->NodeID = NODE_ID+1;
						timesyncpacket->tdata = tf;
						timesyncpacket->mint = mint;
						timesyncpacket->check = TRUE;
					//	timesyncpacket->formm = FALSE;
						
						printf("Sent final packet %ld \n",tf);
				
						length = sizeof(TimeMote_t);
					
						if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(TimeMote_t)) == SUCCESS) 
						{
							busy = TRUE;
							printf("packet sent");
		
						}
					}
				}
				//synced = FALSE;
			}
		}
			
		
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
		}
	}


	event void Timer0.fired()
	{
		
			u_int32_t sec = ((call LocalTime.get() - oldtime + offset)/1024 );
			u_int32_t min = sec /60;
			u_int32_t hour = min /60;
			int i;
			int j=printf("Current Time is  %ld:%ld:%ld\n", hour, min%60, sec%60);
			for(i=0;i<(100-j);i++)
			{
				printf("\0");
			}

	}

	event void Timer1.fired()
	{

	}
}