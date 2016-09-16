#include <stdio.h>
#include <string.h>
#include <Timer.h>
#include <UserButton.h>
#include "MoteToMote.h"
#define NODE_ID 25

module TempTestC
{
	
	uses 
	{
		// general interfaces
		interface Boot;
		interface Timer<TMilli>;
		interface Leds;		
	}
		uses 	//Read 
		{
			interface Get <button_state_t>;
			interface Notify<button_state_t>;
		}
		uses //Radio
	{
		interface Packet;
		interface AMPacket;
		interface AMSend;
		interface SplitControl as ComControl;
		//interface Receive;	
	}
}

implementation
{
	bool busy = FALSE;
	bool sos = FALSE;
	message_t packet;
	uint8_t val = NODE_ID; // ID of worker to be hard coded for each one.
	event void Boot.booted(){
		call Leds.led0On();
		call ComControl.start();
		call Notify.enable();
		call Timer.startPeriodic(1000);
	}


	event void Timer.fired(){
			// for sending location signal message packet.
			if(busy == FALSE)
			{
				MinerToMoteMsg_t* msg = call Packet.getPayload( &packet, sizeof(MinerToMoteMsg_t));
				msg->Data = (uint8_t)val;
				msg->sos = sos;

				//send the packet
				
				if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(MinerToMoteMsg_t)) == SUCCESS) {
					busy = TRUE;
					call Leds.led1Toggle();
				}
			
			}
			// Implementation to call distress signal
			if(busy == FALSE && sos == TRUE)
			{
				if (buttonstate == BUTTON_PRESSED)
				{
					Minerhelp_t* msg1 = call Packet.getPayload( &packet, sizeof(Minerhelp_t));
					msg1->Data = (uint8_t)val;
					strcpy(msg1->msg, "DISTRESS SIGNAL");
				
					if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(Minerhelp_t)) != SUCCESS)
					{
						call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(Minerhelp_t));
					}
				}
			}
		
		}

	event void ComControl.startDone(error_t error){
		
		if (error == SUCCESS) {
			call Leds.led2Toggle();
		}
		else
		{
			call Leds.led1Off();
			call ComControl.start();
		}
	}



	event void ComControl.stopDone(error_t error){
		// TODO Auto-generated method stub
	}

	event void AMSend.sendDone(message_t *msg, error_t error){
		if(error == SUCCESS && msg == &packet){
			busy = FALSE;
			printf("Packet sent successfully");
		}
		if(error == FAIL && msg == &packet ){
			call Leds.led0Toggle();
			call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(MinerToMoteMsg_t));
			busy = FALSE;
			call Leds.led0Toggle();
		}
	}


	event void Notify.notify(button_state_t buttonstate){
		if (buttonstate == BUTTON_PRESSED)
		{
			sos = TRUE;
		}
	}
}
